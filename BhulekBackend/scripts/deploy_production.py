#!/usr/bin/env python3
"""
Production deploy for the Bhumitra backend (EC2 + systemd, via AWS SSM).

Two modes:
  python3 BhulekBackend/scripts/deploy_production.py            # dry run (default)
  python3 BhulekBackend/scripts/deploy_production.py --apply    # real deploy

Dry run never touches the live app, the live DB or the service. It:
  1. Diffs local runtime source against what's on the server (sha256).
  2. Uploads only the changed files into a staging copy of the app.
  3. Import-tests the staged app against a throwaway DB.
  4. Rehearses pending Alembic migrations on a private copy of the live DB.

--apply additionally:
  5. Takes an EBS snapshot of the root volume.
  6. Backs up the files about to be replaced plus the SQLite DB.
  7. Copies staged files into place and runs `alembic upgrade head`.
  8. Restarts the service and health-checks it.
  9. On a failed health check, restores the old files and restarts again.
     (Migrations are additive, so the old code keeps working on the new schema;
      the DB is not rolled back so no writes are lost. The pre-deploy DB copy
      stays in the backup dir if a manual restore is ever needed.)

Run from the repository root.
"""
import argparse
import base64
import hashlib
import io
import json
import os
import subprocess
import sys
import tarfile
import time
from pathlib import Path

INSTANCE_ID = "i-069a0896c7273d3eb"
REGION = "ap-south-1"
APP_DIR = "/home/ec2-user/BhulekBackend"
STAGE_ROOT = "/home/ec2-user/deploy_staging"
BACKUP_ROOT = "/home/ec2-user/deploy_backups"
SERVICE = "bhumitra-backend"
LOCAL_ROOT = Path("BhulekBackend")

# Runtime code only. Tests, scratch pages, root-level test_*.py, scripts and
# data/ caches are intentionally excluded.
RUNTIME_FILES = ["app.py", "main.py", "requirements.txt", "alembic.ini", "alembic/env.py"]
RUNTIME_DIRS = ["core", "db", "models", "providers", "resolvers", "routers",
                "scrapers", "services", "utils", "alembic/versions"]

SMOKE_PATHS = [
    "/health",
    "/ready",
    "/api/v1/location/search?q=tampo&near=21.63,85.58",
]

MAX_B64_CHUNK = 40_000  # keep each SSM command well under the request size limit
IMPORT_TEST_MIN_MB = 900  # full app import peaks around 500 MB RSS


# ---------------------------------------------------------------- helpers

def log(msg: str) -> None:
    print(msg, flush=True)


def ssm(script: str, comment: str, timeout_s: int = 300) -> dict:
    """Runs a bash script on the instance via SSM and waits for it."""
    params = json.dumps({"commands": [script], "executionTimeout": [str(timeout_s)]})
    res = subprocess.run(
        ["aws", "ssm", "send-command", "--region", REGION, "--instance-ids", INSTANCE_ID,
         "--document-name", "AWS-RunShellScript", "--comment", comment[:100],
         "--parameters", params, "--output", "json"],
        capture_output=True, text=True, check=True,
    )
    cid = json.loads(res.stdout)["Command"]["CommandId"]
    deadline = time.time() + timeout_s + 30
    while time.time() < deadline:
        time.sleep(2)
        inv = subprocess.run(
            ["aws", "ssm", "get-command-invocation", "--region", REGION,
             "--command-id", cid, "--instance-id", INSTANCE_ID, "--output", "json"],
            capture_output=True, text=True,
        )
        if inv.returncode != 0:
            continue  # invocation not registered yet
        data = json.loads(inv.stdout)
        if data.get("Status") in ("Success", "Failed", "TimedOut", "Cancelled"):
            return data
    raise TimeoutError(f"SSM command {cid} did not finish")


def ssm_ok(script: str, comment: str, timeout_s: int = 300) -> str:
    inv = ssm(script, comment, timeout_s)
    out = inv.get("StandardOutputContent", "")
    if inv.get("Status") != "Success":
        log(out)
        log("STDERR: " + inv.get("StandardErrorContent", ""))
        raise RuntimeError(f"Remote step failed: {comment}")
    return out


def local_manifest() -> dict:
    files = {}
    for rel in RUNTIME_FILES:
        p = LOCAL_ROOT / rel
        if p.is_file():
            files[rel] = p
    for d in RUNTIME_DIRS:
        for p in sorted((LOCAL_ROOT / d).rglob("*.py")):
            if "__pycache__" in p.parts or p.name.startswith("._"):
                continue
            files[str(p.relative_to(LOCAL_ROOT))] = p
    return {rel: hashlib.sha256(p.read_bytes()).hexdigest() for rel, p in files.items()}


def remote_manifest(paths) -> dict:
    listing = "\n".join(paths)
    script = f"""set -e
cd {APP_DIR}
while IFS= read -r f; do
  if [ -f "$f" ]; then echo "$(sha256sum "$f" | cut -d' ' -f1) $f"; else echo "MISSING $f"; fi
done <<'EOF'
{listing}
EOF
"""
    out = ssm_ok(script, "deploy: read remote hashes")
    result = {}
    for line in out.splitlines():
        parts = line.split(" ", 1)
        if len(parts) == 2:
            result[parts[1]] = None if parts[0] == "MISSING" else parts[0]
    return result


def upload_bundle(rels, local_hashes: dict, stage_dir: str) -> None:
    """Ships all changed files as one gzip'd tar, chunked through SSM, then
    extracts into the staging dir and verifies every file's sha256."""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for rel in rels:
            info = tar.gettarinfo(str(LOCAL_ROOT / rel), arcname=rel)
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            with open(LOCAL_ROOT / rel, "rb") as fh:
                tar.addfile(info, fh)
    b64 = base64.b64encode(buf.getvalue()).decode()
    part = f"{stage_dir}/.bundle.b64"
    chunks = [b64[i:i + MAX_B64_CHUNK] for i in range(0, len(b64), MAX_B64_CHUNK)]
    log(f"  bundle: {len(rels)} files, {len(buf.getvalue()) // 1024} KB gz, {len(chunks)} chunk(s)")
    for i, chunk in enumerate(chunks):
        redirect = ">" if i == 0 else ">>"
        ssm_ok(f"printf '%s' '{chunk}' {redirect} '{part}'", f"deploy: upload bundle [{i + 1}/{len(chunks)}]")
    expected = "\n".join(f"{local_hashes[r]}  {r}" for r in rels)
    ssm_ok(f"""set -e
cd '{stage_dir}'
base64 -d '{part}' | tar -xzf - --no-same-owner
rm -f '{part}'
sha256sum -c --quiet - <<'EOF'
{expected}
EOF
chown -R ec2-user:ec2-user '{stage_dir}'
echo BUNDLE_OK
""", "deploy: extract + verify bundle")


# ---------------------------------------------------------------- main flow

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="actually deploy (default is dry run)")
    ap.add_argument("--allow-dirty", action="store_true", help="deploy with uncommitted changes")
    args = ap.parse_args()

    sha = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output(
        ["git", "status", "--porcelain", "--", str(LOCAL_ROOT)], text=True).strip()
    if dirty and not args.allow_dirty:
        log("Refusing to deploy: uncommitted backend changes (commit first or pass --allow-dirty).")
        log(dirty)
        return 1

    mode = "APPLY" if args.apply else "DRY RUN"
    log(f"== {mode}: commit {sha[:12]} -> {INSTANCE_ID} ({REGION})")

    # 1. Diff
    local = local_manifest()
    remote = remote_manifest(sorted(local))
    changed = sorted(rel for rel, h in local.items() if remote.get(rel) != h)
    if not changed:
        log("Server already matches local runtime code. Nothing to deploy.")
        return 0
    log(f"{len(changed)} file(s) to deploy:")
    for rel in changed:
        log(f"  {'new    ' if remote.get(rel) is None else 'changed'} {rel}")

    # 2. Stage: code copy with venv and data symlinked (data/ is ~400 MB)
    stage = f"{STAGE_ROOT}/{sha[:12]}"
    ssm_ok(f"""set -e
rm -rf '{stage}'
mkdir -p '{stage}'
cd {APP_DIR}
tar --exclude=./venv --exclude=./data --exclude='*/__pycache__' --exclude=./scratch -cf - . | tar -xf - -C '{stage}'
ln -s {APP_DIR}/venv '{stage}/venv'
ln -s {APP_DIR}/data '{stage}/data'
chown -R ec2-user:ec2-user '{STAGE_ROOT}'
""", "deploy: create staging copy")
    upload_bundle(changed, local, stage)

    # 3. Compile check with the server's Python, then a full import test against a
    #    throwaway DB -- but only if there's headroom. A full app import needs
    #    ~500 MB, and the t3.small usually has less than that free while serving.
    out = ssm_ok(f"""set -e
cd '{stage}'
venv/bin/python -m compileall -q {" ".join(sorted({c.split("/")[0] for c in changed}))} >/dev/null && echo COMPILE_OK
AVAIL_MB=$(awk '/MemAvailable/ {{print int($2/1024)}}' /proc/meminfo)
echo "MemAvailable=${{AVAIL_MB}}MB"
if [ "$AVAIL_MB" -ge {IMPORT_TEST_MIN_MB} ]; then
  T=$(mktemp -d); chown ec2-user:ec2-user "$T"
  set -a; . /etc/bhumitra/bhumitra.env; set +a
  DATABASE_URL="sqlite:///$T/import_test.db" nice -n 19 sudo -E -u ec2-user venv/bin/python -c "from app import create_app; create_app(); print('IMPORT_OK')"
  rm -rf "$T"
else
  echo IMPORT_SKIPPED_LOW_MEMORY
fi
""", "deploy: staged compile/import test")
    if "COMPILE_OK" not in out:
        log(out)
        raise RuntimeError("Staged compile check failed")
    if "IMPORT_OK" in out:
        log("Staged compile + import test passed.")
    elif "IMPORT_SKIPPED_LOW_MEMORY" in out:
        log("Staged compile check passed. Full import test skipped (low memory); "
            "the post-restart health check + auto-rollback covers runtime errors.")
    else:
        log(out)
        raise RuntimeError("Staged import test failed")

    # 4. Migration rehearsal on a private copy of the live DB
    out = ssm_ok(f"""set -e
cd '{stage}'
T=$(mktemp -d); chmod 700 "$T"
python3 - "$T/rehearsal.db" <<'EOF'
import sqlite3, sys
src = sqlite3.connect("file:{APP_DIR}/data/bhumitra_local.db?mode=ro", uri=True)
dst = sqlite3.connect(sys.argv[1]); src.backup(dst); dst.close(); src.close()
EOF
echo "before: $(python3 -c "import sqlite3,sys;print(sqlite3.connect(sys.argv[1]).execute('select version_num from alembic_version').fetchone()[0])" "$T/rehearsal.db")"
DATABASE_URL="sqlite:///$T/rehearsal.db" venv/bin/alembic upgrade head 2>&1 | tail -5
echo "after: $(python3 -c "import sqlite3,sys;print(sqlite3.connect(sys.argv[1]).execute('select version_num from alembic_version').fetchone()[0])" "$T/rehearsal.db")"
rm -rf "$T"
echo REHEARSAL_OK
""", "deploy: migration rehearsal", timeout_s=600)
    log(out.strip())
    if "REHEARSAL_OK" not in out:
        raise RuntimeError("Migration rehearsal failed")

    if not args.apply:
        log("== DRY RUN complete. Live app, DB and service were not touched.")
        log(f"   Staging copy left at {stage} (safe to delete).")
        return 0

    # 5. EBS snapshot
    vol = subprocess.check_output(
        ["aws", "ec2", "describe-instances", "--region", REGION, "--instance-ids", INSTANCE_ID,
         "--query", "Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId",
         "--output", "text"], text=True).strip()
    snap = subprocess.check_output(
        ["aws", "ec2", "create-snapshot", "--region", REGION, "--volume-id", vol,
         "--description", f"pre-deploy {sha[:12]}",
         "--tag-specifications",
         f"ResourceType=snapshot,Tags=[{{Key=Name,Value=bhumitra-predeploy-{sha[:12]}}}]",
         "--query", "SnapshotId", "--output", "text"], text=True).strip()
    log(f"EBS snapshot started: {snap} (volume {vol})")

    # 6-8. Backup, swap, migrate, restart, health check (+ rollback)
    ts = time.strftime("%Y%m%d_%H%M%S")
    backup = f"{BACKUP_ROOT}/{ts}_{sha[:12]}"
    changed_list = "\n".join(changed)
    smoke = " ".join(f"'http://127.0.0.1:8000{p}'" for p in SMOKE_PATHS)
    out = ssm(f"""set -u
cd {APP_DIR}
mkdir -p '{backup}'; chmod 700 '{backup}'
CHANGED=$(cat <<'EOF'
{changed_list}
EOF
)
# Back up files that exist today (new files are recorded for removal on rollback)
: > '{backup}/new_files.txt'
echo "$CHANGED" | while IFS= read -r f; do
  if [ -f "$f" ]; then tar -rf '{backup}/old_files.tar' "$f"; else echo "$f" >> '{backup}/new_files.txt'; fi
done
cp -a .git_commit '{backup}/' 2>/dev/null || true
python3 - <<'EOF' || exit 10
import sqlite3
src = sqlite3.connect("file:{APP_DIR}/data/bhumitra_local.db?mode=ro", uri=True)
dst = sqlite3.connect("{backup}/bhumitra_local.db"); src.backup(dst); dst.close(); src.close()
EOF
echo "backup ok: {backup}"

# Swap in staged files
echo "$CHANGED" | while IFS= read -r f; do
  mkdir -p "$(dirname "$f")"; cp -p '{stage}'/"$f" "$f"; chown ec2-user:ec2-user "$f"
done
echo '{sha}' > .git_commit; chown ec2-user:ec2-user .git_commit

rollback() {{
  echo "ROLLING BACK: $1"
  [ -f '{backup}/old_files.tar' ] && tar -xf '{backup}/old_files.tar'
  while IFS= read -r f; do [ -n "$f" ] && rm -f "$f"; done < '{backup}/new_files.txt'
  cp -a '{backup}/.git_commit' . 2>/dev/null || true
  systemctl restart {SERVICE}
  sleep 15
  systemctl is-active {SERVICE}
  echo ROLLED_BACK
  exit 20
}}

# Migrate the live DB (additive; old code stays compatible)
set -a; . /etc/bhumitra/bhumitra.env; set +a
sudo -E -u ec2-user venv/bin/alembic upgrade head 2>&1 | tail -3
[ "${{PIPESTATUS[0]}}" = "0" ] || rollback "alembic upgrade failed"

systemctl restart {SERVICE}
ok=0
for i in $(seq 1 30); do
  sleep 3
  if curl -fsS -o /dev/null http://127.0.0.1:8000/health; then ok=1; break; fi
done
[ "$ok" = "1" ] || rollback "health endpoint never came up"
for u in {smoke}; do
  code=$(curl -s -o /dev/null -w '%{{http_code}}' --max-time 30 "$u")
  echo "smoke $code $u"
  case "$code" in 2*) ;; *) rollback "smoke test failed: $u -> $code";; esac
done
systemctl is-active {SERVICE}
free -m | sed -n 1,3p
rm -rf '{stage}'
echo DEPLOY_OK
""", "deploy: backup, swap, migrate, restart", timeout_s=900)
    log(out.get("StandardOutputContent", ""))
    if out.get("StandardErrorContent"):
        log("STDERR: " + out["StandardErrorContent"][-2000:])
    if "DEPLOY_OK" in out.get("StandardOutputContent", ""):
        log(f"== DEPLOY COMPLETE ({sha[:12]}). Snapshot {snap}, backup {backup}.")
        return 0
    log(f"== DEPLOY FAILED. Snapshot {snap}, backup {backup}. See output above.")
    return 1


if __name__ == "__main__":
    os.chdir(Path(__file__).resolve().parents[2])
    sys.exit(main())
