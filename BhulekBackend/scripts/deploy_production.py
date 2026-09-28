import gzip
import base64
import json
import subprocess
import time
import sys

INSTANCE_ID = "i-069a0896c7273d3eb"
REGION = "ap-south-1"

FILES_TO_DEPLOY = [
    ("core/config.py", "/home/ec2-user/BhulekBackend/core/config.py"),
    ("scrapers/bhulekh_mappings.py", "/home/ec2-user/BhulekBackend/scrapers/bhulekh_mappings.py"),
    ("routers/location_search.py", "/home/ec2-user/BhulekBackend/routers/location_search.py"),
    ("routers/ror.py", "/home/ec2-user/BhulekBackend/routers/ror.py"),
    ("app.py", "/home/ec2-user/BhulekBackend/app.py"),
    ("services/location_search_service.py", "/home/ec2-user/BhulekBackend/services/location_search_service.py"),
    ("services/spatial_resolver_service.py", "/home/ec2-user/BhulekBackend/services/spatial_resolver_service.py"),
]

GIT_SHA = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()

def run_ssm_command(commands):
    cmd = [
        "aws", "ssm", "send-command",
        "--region", REGION,
        "--instance-ids", INSTANCE_ID,
        "--document-name", "AWS-RunShellScript",
        "--parameters", json.dumps({"commands": commands}),
        "--output", "json"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=True)
    cmd_data = json.loads(res.stdout)
    command_id = cmd_data["Command"]["CommandId"]

    # Poll for completion
    for _ in range(30):
        time.sleep(2)
        inv_cmd = [
            "aws", "ssm", "get-command-invocation",
            "--region", REGION,
            "--command-id", command_id,
            "--instance-id", INSTANCE_ID,
            "--output", "json"
        ]
        inv_res = subprocess.run(inv_cmd, capture_output=True, text=True, check=True)
        inv_data = json.loads(inv_res.stdout)
        status = inv_data.get("Status")
        if status in ["Success", "Failed", "TimedOut", "Cancelled"]:
            return inv_data
    raise TimeoutError(f"Command {command_id} timed out")

def main():
    print(f"Deploying commit {GIT_SHA} to EC2 {INSTANCE_ID} ({REGION})...")

    # 1. Deploy each file
    for local_rel, remote_abs in FILES_TO_DEPLOY:
        local_path = f"BhulekBackend/{local_rel}"
        with open(local_path, "rb") as f:
            content = f.read()
        gz = gzip.compress(content)
        b64 = base64.b64encode(gz).decode()
        print(f"Uploading {local_rel} ({len(content)} bytes -> {len(b64)} b64 bytes)...")
        
        # Write to temporary file then move and chown
        remote_cmd = (
            f"python3 -c \"import gzip, base64; "
            f"data = gzip.decompress(base64.b64decode('{b64}')); "
            f"open('{remote_abs}', 'wb').write(data)\" && "
            f"chown ec2-user:ec2-user {remote_abs}"
        )
        inv = run_ssm_command([remote_cmd])
        if inv.get("Status") != "Success":
            print(f"FAILED uploading {local_rel}: {inv}")
            sys.exit(1)
        print(f"Successfully deployed {local_rel}")

    # 2. Write .git_commit file
    print(f"Writing .git_commit with SHA {GIT_SHA}...")
    git_commit_cmd = (
        f"echo '{GIT_SHA}' > /home/ec2-user/BhulekBackend/.git_commit && "
        f"chown ec2-user:ec2-user /home/ec2-user/BhulekBackend/.git_commit"
    )
    inv = run_ssm_command([git_commit_cmd])
    if inv.get("Status") != "Success":
        print(f"FAILED writing .git_commit: {inv}")
        sys.exit(1)

    # 3. Test python import on EC2 before restarting systemd
    print("Testing application import on EC2...")
    test_cmd = (
        "cd /home/ec2-user/BhulekBackend && "
        "/home/ec2-user/BhulekBackend/venv/bin/python3 -c "
        "\"from app import create_app; a = create_app(); print('APP CREATION SUCCESS')\""
    )
    inv = run_ssm_command([test_cmd])
    print(f"Import test result: {inv.get('Status')}")
    print(f"Output: {inv.get('StandardOutputContent')}")
    if inv.get("Status") != "Success":
        print(f"STDERR: {inv.get('StandardErrorContent')}")
        sys.exit(1)

    # 4. Restart bhumitra-backend systemd service
    print("Restarting bhumitra-backend.service...")
    restart_cmd = "systemctl restart bhumitra-backend && systemctl is-active bhumitra-backend"
    inv = run_ssm_command([restart_cmd])
    print(f"Restart result: {inv.get('Status')}")
    print(f"Output: {inv.get('StandardOutputContent')}")
    if inv.get("Status") != "Success":
        print(f"STDERR: {inv.get('StandardErrorContent')}")
        sys.exit(1)

    print("DEPLOYMENT COMPLETE!")

if __name__ == "__main__":
    main()
