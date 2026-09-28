#!/usr/bin/env python3
"""
Read-only feasibility probe for second-state cadastral map sources.

Run it FROM THE MUMBAI EC2 (Indian government portals often block foreign IPs):

    aws ssm send-command ... (see scripts/deploy_production.py for the pattern)
    python3 state_portal_probe.py            # all states
    python3 state_portal_probe.py UP CG      # subset

What it checks per state, politely (sequential, ~1 req/sec, a handful of villages):
  * portal reachable, CAPTCHA / challenge page in front of the public map
  * admin hierarchy is walkable without login
  * village extent is georeferenced (real-world CRS, not local sheet units)
  * WMS parcel layer renders in EPSG:3857 (what MapLibre needs)
  * plot lookup by map tap and by plot number
  * whether plot info exposes owner names (counted, never printed)

Rules: no login, no CAPTCHA solving, and no requests to endpoints that sit
behind a challenge page. Only standard library, so it runs on the bare server.
"""
import json
import math
import random
import re
import ssl
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zlib

UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148"
DELAY_S = 0.8
SAMPLE_DISTRICTS = 4
CAPTCHA_RE = re.compile(r"(?i)recaptcha|hcaptcha|captcha|cf-chl|turnstile|security verification")

# Some NIC hosts serve incomplete chains; CG needs this. UP validates strictly.
_LAX = ssl.create_default_context()
_LAX.check_hostname = False
_LAX.verify_mode = ssl.CERT_NONE


def http(url, form=None, json_body=None, strict_tls=True, max_bytes=3_000_000):
    time.sleep(DELAY_S)
    headers = {"User-Agent": UA, "Accept": "application/json, text/plain, */*"}
    body = None
    if form is not None:
        body = urllib.parse.urlencode(form).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    elif json_body is not None:
        body = json.dumps(json_body).encode()
        headers["Content-Type"] = "application/json"
    ctx = ssl.create_default_context() if strict_tls else _LAX
    started = time.time()
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=body, headers=headers),
                                    timeout=30, context=ctx) as r:
            return r.status, r.headers.get("Content-Type", ""), r.read(max_bytes), time.time() - started
    except urllib.error.HTTPError as e:
        return e.code, "", e.read(2000), time.time() - started
    except Exception as e:  # network errors are a result, not a crash
        return None, "", str(e).encode(), time.time() - started


def png_coverage(b: bytes) -> float:
    """Fraction of non-zero bytes in the decoded PNG (0.0 means a blank tile)."""
    if b[:4] != b"\x89PNG":
        return -1.0
    try:
        idat = b"".join(b[i + 8:i + 8 + struct.unpack(">I", b[i:i + 4])[0]]
                        for i in [m.start() - 4 for m in re.finditer(b"IDAT", b)])
        raw = zlib.decompress(idat)
        return sum(1 for x in raw if x) / max(1, len(raw))
    except Exception:
        return -1.0


def to_3857(lat, lon):
    return lon * 20037508.34 / 180, math.log(math.tan((90 + lat) * math.pi / 360)) * 6378137


def utm_to_ll(e, n, zone):
    a, f, k0 = 6378137.0, 1 / 298.257223563, 0.9996
    e2 = f * (2 - f); ep2 = e2 / (1 - e2)
    x = e - 500000.0; m = n / k0
    mu = m / (a * (1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256))
    e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2))
    p = (mu + (3 * e1 / 2 - 27 * e1 ** 3 / 32) * math.sin(2 * mu)
         + (21 * e1 ** 2 / 16 - 55 * e1 ** 4 / 32) * math.sin(4 * mu)
         + (151 * e1 ** 3 / 96) * math.sin(6 * mu))
    c = ep2 * math.cos(p) ** 2; t = math.tan(p) ** 2
    nn = a / math.sqrt(1 - e2 * math.sin(p) ** 2)
    r = a * (1 - e2) / (1 - e2 * math.sin(p) ** 2) ** 1.5
    d = x / (nn * k0)
    lat = p - (nn * math.tan(p) / r) * (d ** 2 / 2 - (5 + 3 * t + 10 * c - 4 * c ** 2 - 9 * ep2) * d ** 4 / 24
                                       + (61 + 90 * t + 298 * c + 45 * t ** 2 - 252 * ep2 - 3 * c ** 2) * d ** 6 / 720)
    lon = (d - (1 + 2 * t + c) * d ** 3 / 6
           + (5 - 2 * c + 28 * t - 3 * c ** 2 + 8 * ep2 + 24 * t ** 2) * d ** 5 / 120) / math.cos(p)
    return math.degrees(lat), (zone - 1) * 6 - 180 + 3 + math.degrees(lon)


def owner_rows(text: str) -> int:
    """Counts owner-name rows without ever returning them."""
    return len(re.findall(r"नाम\s*:", text)) + len(re.findall(r"(?i)owner name\s*:", text))


def gate_check(name, url, strict_tls=True):
    s, _, b, dt = http(url, strict_tls=strict_tls)
    html = b.decode("utf-8", "replace")
    title = re.search(r"(?is)<title>(.*?)</title>", html)
    gated = bool(CAPTCHA_RE.search(title.group(1) if title else "")) or "security verification" in html.lower()
    print(f"  [{name}] {url} -> {s} in {dt:.1f}s, title={title.group(1).strip()[:50] if title else '-'!r}, "
          f"challenge_page={gated}")
    return s == 200, gated


# ----------------------------------------------------------------- UP

def probe_up():
    print("\n=== Uttar Pradesh (upbhunaksha.gov.in)")
    ok, gated = gate_check("map", "https://upbhunaksha.gov.in/")
    gate_check("RoR", "https://upbhulekh.gov.in/")
    if not ok or gated:
        return {"state": "UP", "verdict": "BLOCKED", "reason": "portal down or challenge page"}
    api = "https://upbhunaksha.gov.in/bhunakshaserver"

    def level(lv, codes):
        s, _, b, _ = http(api + "/masterdata/levelvalue", form={"level": str(lv), "codes": codes})
        try:
            return [i for i in json.loads(b) if (i.get("extraParams") or {}).get("hasData", True)]
        except Exception:
            return []

    districts = level(1, "")
    print(f"  districts with map data: {len(districts)}")
    villages_checked = georef = wms_ok = plot_ok = 0
    owners_exposed = False
    for d in random.sample(districts, min(SAMPLE_DISTRICTS, len(districts))):
        tehsils = level(2, d["code"])
        if not tehsils:
            continue
        t = random.choice(tehsils)
        vills = level(3, f"{d['code']},{t['code']}")
        if not vills:
            continue
        v = random.choice(vills)
        villages_checked += 1
        s, _, b, _ = http(api + "/MapInfo/getVVVVExtentGeoref", form={"gisLevels": f"{d['code']},{t['code']},{v['code']}"})
        try:
            ext = json.loads(b)
        except Exception:
            continue
        crs = str(ext.get("crs") or "")
        is_geo = crs.startswith("EPSG:326") and (ext.get("xmin") or 0) > 100000
        georef += is_geo
        line = f"  {d['code']}/{t['code']}/{v['code']} ({len(vills)} villages in tehsil): crs={crs or '-'}"
        if is_geo:
            zone = int(crs[-2:])
            la0, lo0 = utm_to_ll(ext["xmin"], ext["ymin"], zone)
            la1, lo1 = utm_to_ll(ext["xmax"], ext["ymax"], zone)
            x0, y0 = to_3857(la0, lo0); x1, y1 = to_3857(la1, lo1)
            q = {"SERVICE": "WMS", "VERSION": "1.1.1", "REQUEST": "GetMap", "LAYERS": "VILLAGE_MAP",
                 "STYLES": "VILLAGE_MAP", "FORMAT": "image/png", "TRANSPARENT": "true", "SRS": "EPSG:3857",
                 "BBOX": f"{x0},{y0},{x1},{y1}", "WIDTH": 256, "HEIGHT": 256, "state": "",
                 "gis_code": ext["gisCode"], "overlay_codes": ""}
            s, _, img, dt = http(api + "/WMS?" + urllib.parse.urlencode(q))
            cov = png_coverage(img)
            wms_ok += cov > 0.05
            cx, cy = (ext["xmin"] + ext["xmax"]) / 2, (ext["ymin"] + ext["ymax"]) / 2
            s, _, pb, _ = http(api + "/MapInfo/getPlotAtXY", form={"giscode": ext["gisCode"], "x": cx, "y": cy})
            try:
                plot = json.loads(pb)
            except Exception:
                plot = {}
            has_plot = bool(plot.get("kide"))
            plot_ok += has_plot
            info_owners = 0
            if has_plot:
                s, _, ib, _ = http(api + "/MapInfo/getPlotInfo",
                                   json_body={"gisCode": ext["gisCode"], "plotNo": plot["kide"]})
                info_owners = owner_rows(ib.decode("utf-8", "replace"))
                owners_exposed = owners_exposed or info_owners > 0
            line += (f" centre=({(la0 + la1) / 2:.4f},{(lo0 + lo1) / 2:.4f}) wms3857={cov:.2f} ({dt:.1f}s)"
                     f" plot_at_centre={'yes' if has_plot else 'no'} owner_rows_in_info={info_owners}")
        print(line)
    return {"state": "UP", "villages_checked": villages_checked, "georeferenced": georef,
            "wms_3857_renders": wms_ok, "tap_lookup": plot_ok, "owner_names_public": owners_exposed,
            "verdict": "FEASIBLE" if villages_checked and georef == villages_checked and wms_ok else "PARTIAL"}


# ----------------------------------------------------------------- CG

def probe_cg():
    print("\n=== Chhattisgarh (bhunaksha.cg.nic.in)")
    ok, gated = gate_check("map", "https://bhunaksha.cg.nic.in/", strict_tls=False)
    if not ok or gated:
        return {"state": "CG", "verdict": "BLOCKED", "reason": "portal down or challenge page"}
    base = "https://bhunaksha.cg.nic.in/"

    def lists(lv, codes):
        s, _, b, _ = http(base + "rest/Levels/ListsAfterLevel",
                          form={"state": "22", "level": lv, "codes": codes, "hasmap": "true"}, strict_tls=False)
        try:
            return json.loads(b)
        except Exception:
            return []

    top = lists(0, "")
    districts = top[0] if top else []
    print(f"  districts: {len(districts)}")
    checked = georef = 0
    for d in random.sample(districts, min(SAMPLE_DISTRICTS * 2, len(districts))):
        l1 = lists(1, d["code"] + ",")
        if not l1 or not l1[0]:
            continue
        t = random.choice(l1[0])
        l2 = lists(2, f"{d['code']},{t['code']},")
        if not l2 or not l2[0]:
            continue
        r = random.choice(l2[0])
        l3 = lists(3, f"{d['code']},{t['code']},{r['code']},")
        if not l3 or not l3[0]:
            continue
        v = random.choice(l3[0])
        s, _, b, _ = http(base + "rest/MapInfo/getVVVVExtentGeoref",
                          form={"state": "22", "gisLevels": f"{d['code']},{t['code']},{r['code']},{v['code']}", "srs": "4326"},
                          strict_tls=False)
        try:
            ext = json.loads(b)
        except Exception:
            continue
        checked += 1
        is_geo = ext.get("xmin") is not None
        georef += is_geo
        print(f"  {d['code']}/{t['code']}/{r['code']}/{v['code']}: georeferenced={is_geo}")
    share = georef / checked if checked else 0
    return {"state": "CG", "villages_checked": checked, "georeferenced": georef,
            "verdict": "FEASIBLE" if share >= 0.8 else ("PARTIAL" if share > 0 else "NOT_USABLE_ON_SATELLITE_MAP")}


# ----------------------------------------------------------------- RJ

def probe_rj():
    print("\n=== Rajasthan (bhunaksha.rajasthan.gov.in)")
    gate_check("home", "https://bhunaksha.rajasthan.gov.in/")
    ok, gated = gate_check("map viewer", "https://bhunaksha.rajasthan.gov.in/Viewmap/")
    gate_check("RoR", "https://apnakhata.rajasthan.gov.in/")
    if gated:
        print("  public map viewer sits behind an hCaptcha challenge; not probing the API behind it.")
        return {"state": "RJ", "verdict": "BLOCKED_BY_CHALLENGE"}
    if not ok:
        # Seen on 2026-09-28: sometimes a 500, sometimes an hCaptcha "Security Verification" page.
        return {"state": "RJ", "verdict": "UNAVAILABLE_OR_GATED", "reason": "viewer errored; earlier runs saw hCaptcha"}
    return {"state": "RJ", "verdict": "RECHECK", "reason": "challenge not detected; inspect manually"}


PROBES = {"UP": probe_up, "CG": probe_cg, "RJ": probe_rj}

if __name__ == "__main__":
    random.seed(int(time.time()) // 86400)  # stable within a day, varies across days
    wanted = [s.upper() for s in sys.argv[1:]] or list(PROBES)
    results = [PROBES[s]() for s in wanted if s in PROBES]
    print("\n=== SUMMARY")
    for r in results:
        print("  " + json.dumps(r, ensure_ascii=False))
