"""
Bhumitra - Odisha IGR Benchmark Valuation Service
Communicates with official Odisha Inspector General of Registration (igrodisha.gov.in),
resolves Sub-Registrar jurisdictions and Village-Thana identities via deterministic candidate scoring,
enforces strict thana consistency, performs exact decimal arithmetic, and maintains robust caching,
timeout, request deduplication, and circuit breaker resilience.
"""
import asyncio
import logging
import re
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
import hashlib
from typing import Optional, Dict, Tuple, List, Any

import httpx

from models.igr_benchmark import (
    IGRBenchmarkValuationResponse,
    IGRUnitRates,
    IGRBenchmarkCalculation,
    IGRValuationCandidate,
    IGRRegistrationEstimateResponse,
    IGR_OFFICIAL_DEEDS,
    IGR_UNIT_CONFIGS,
    IGRDeedInfo,
)

logger = logging.getLogger("bhumitra.igr_benchmark")

# ── 30 Official Odisha Districts Mapping ──────────────────────────────────────
# Maps English / Odia variants to IGR District ID (1..30) and official uppercase name.
IGR_DISTRICT_MAP: Dict[str, Tuple[int, str]] = {
    "ANGUL": (1, "ANUGOLA"), "ANUGOLA": (1, "ANUGOLA"), "ANUGUL": (1, "ANUGOLA"), "ଅନୁଗୋଳ": (1, "ANUGOLA"),
    "BALASORE": (2, "BALESHWAR"), "BALESHWAR": (2, "BALESHWAR"), "BALESWAR": (2, "BALESHWAR"), "ବାଲେଶ୍ୱର": (2, "BALESHWAR"),
    "BOLANGIR": (3, "BALANGIR"), "BALANGIR": (3, "BALANGIR"), "ବଲାଙ୍ଗୀର": (3, "BALANGIR"),
    "BARGARH": (4, "BARAGADA"), "BARAGADA": (4, "BARAGADA"), "BARAGARH": (4, "BARAGADA"), "ବରଗଡ଼": (4, "BARAGADA"),
    "BHADRAK": (5, "BHADRAK"), "ଭଦ୍ରକ": (5, "BHADRAK"),
    "BOUDH": (6, "BOUDH"), "BAUDH": (6, "BOUDH"), "ବୌଦ୍ଧ": (6, "BOUDH"),
    "CUTTACK": (7, "KATAKA"), "KATAKA": (7, "KATAKA"), "କଟକ": (7, "KATAKA"),
    "DEOGARH": (8, "DEBAGADA"), "DEBAGADA": (8, "DEBAGADA"), "DEBAGARH": (8, "DEBAGADA"), "ଦେବଗଡ଼": (8, "DEBAGADA"),
    "DHENKANAL": (9, "DHENKANAL"), "ଢେଙ୍କାନାଳ": (9, "DHENKANAL"),
    "GAJAPATI": (10, "GAJAPATI"), "ଗଜପତି": (10, "GAJAPATI"),
    "GANJAM": (11, "GANJAM"), "ଗଞ୍ଜାମ": (11, "GANJAM"),
    "JAGATSINGHPUR": (12, "JAGATSINGHPUR"), "JAGATSINGPUR": (12, "JAGATSINGHPUR"), "ଜଗତସିଂହପୁର": (12, "JAGATSINGHPUR"),
    "JAJPUR": (13, "JAJPUR"), "JAJAPUR": (13, "JAJPUR"), "ଯାଜପୁର": (13, "JAJPUR"),
    "JHARSUGUDA": (14, "JHARSUGUDA"), "ଝାରସୁଗୁଡ଼ା": (14, "JHARSUGUDA"),
    "KALAHANDI": (15, "KALAHANDI"), "କଳାହାଣ୍ଡି": (15, "KALAHANDI"),
    "KENDRAPARA": (16, "KENDRAPADA"), "KENDRAPADA": (16, "KENDRAPADA"), "କେନ୍ଦ୍ରାପଡ଼ା": (16, "KENDRAPADA"),
    "KEONJHAR": (17, "KENDUJHAR"), "KENDUJHAR": (17, "KENDUJHAR"), "କେନ୍ଦୁଝର": (17, "KENDUJHAR"),
    "KHORDHA": (18, "KHORDHA"), "KHURDA": (18, "KHORDHA"), "BHUBANESWAR": (18, "KHORDHA"), "ଖୋର୍ଦ୍ଧା": (18, "KHORDHA"),
    "KORAPUT": (19, "KORAPUT"), "କୋରାପୁଟ": (19, "KORAPUT"),
    "MALKANGIRI": (20, "MALKANGIRI"), "MALKANAGIRI": (20, "MALKANGIRI"), "ମାଲକାନଗିରି": (20, "MALKANGIRI"),
    "MAYURBHANJ": (21, "MAYURBHANJ"), "MAYURBHANJA": (21, "MAYURBHANJ"), "ମୟୂରଭଞ୍ଜ": (21, "MAYURBHANJ"),
    "NUAPADA": (22, "NUAPADA"), "ନୂଆପଡ଼ା": (22, "NUAPADA"),
    "NABARANGPUR": (23, "NABARANGPUR"), "NAWARANGPUR": (23, "NABARANGPUR"), "ନବରଙ୍ଗପୁର": (23, "NABARANGPUR"),
    "NAYAGARH": (24, "NAYAGADA"), "NAYAGADA": (24, "NAYAGADA"), "ନୟାଗଡ଼": (24, "NAYAGADA"),
    "KANDHAMAL": (25, "KANDHAMALA"), "KANDHAMALA": (25, "KANDHAMALA"), "PHULBANI": (25, "KANDHAMALA"), "କନ୍ଧମାଳ": (25, "KANDHAMALA"),
    "PURI": (26, "PURI"), "ପୁରୀ": (26, "PURI"),
    "RAYAGADA": (27, "RAYAGADA"), "ରାୟଗଡ଼ା": (27, "RAYAGADA"),
    "SAMBALPUR": (28, "SAMBALPUR"), "ସମ୍ବଲପୁର": (28, "SAMBALPUR"),
    "SUBARNAPUR": (29, "SUBARNAPUR"), "SONEPUR": (29, "SUBARNAPUR"), "ସୁବର୍ଣ୍ଣପୁର": (29, "SUBARNAPUR"),
    "SUNDARGARH": (30, "SUNDARAGADA"), "SUNDARAGADA": (30, "SUNDARAGADA"), "ସୁନ୍ଦରଗଡ଼": (30, "SUNDARAGADA"),
}

# Tahasil Name to Registration Office Alias & Spelling Mappings across all 30 districts
TAHASIL_ALIASES: Dict[str, List[str]] = {
    "KEONJHAR": ["KENDUJHAR", "KEONJHAR"],
    "KENDUJHAR": ["KENDUJHAR", "KEONJHAR"],
    "CUTTACK": ["KATAKA", "CUTTACK", "KATAKA ADM"],
    "KATAKA": ["KATAKA", "CUTTACK", "KATAKA ADM"],
    "BALASORE": ["BALESHWAR", "BALASORE", "BALESWAR", "BALESHWAR ADM"],
    "BALESWAR": ["BALESHWAR", "BALASORE", "BALESWAR", "BALESHWAR ADM"],
    "BALESHWAR": ["BALESHWAR", "BALASORE", "BALESWAR", "BALESHWAR ADM"],
    "BARGARH": ["BARAGADA", "BARGARH", "BARAGADA ADM"],
    "DEOGARH": ["DEBAGADA", "DEOGARH"],
    "KENDRAPARA": ["KENDRAPADA", "KENDRAPARA"],
    "KANDHAMAL": ["KANDHAMALA", "PHULBANI"],
    "NAYAGARH": ["NAYAGADA", "NAYAGARH"],
    "SUNDARGARH": ["SUNDARAGADA", "SUNDARGARH", "SUNDARAGADA ADM", "PANPOSH", "ROURKELA"],
    "SUBARNAPUR": ["SUBARNAPUR", "SONEPUR", "SONPUR"],
    "SONEPUR": ["SUBARNAPUR", "SONEPUR", "SONPUR"],
    "ANGUL": ["ANUGOLA", "ANGUL", "ANUGUL"],
    "ANUGUL": ["ANUGOLA", "ANGUL", "ANUGUL"],
    "BOLANGIR": ["BALANGIR", "BOLANGIR", "BALANGIR ADM"],
    "BALANGIR": ["BALANGIR", "BOLANGIR", "BALANGIR ADM"],
    "BALIANTA": ["BALIANATA", "BALIANTA", "BALIPATNA", "KHORDHA(BBSR)", "KHORDHA"],
    "BHUBANESWAR": ["KHORDHA(BBSR)", "KHANDAGIRI", "JATANI", "BALIANATA"],
    "BHADRAK": ["BHADRAK", "BHADRAK ADM"],
    "JHARSUGUDA": ["JHARSUGUDA", "JHARSUGUDA ADM"],
    "BERHAMPUR": ["BRAHMAPUR", "BERHAMPUR", "GANJAM"],
    "BRAHMAPUR": ["BRAHMAPUR", "BERHAMPUR", "GANJAM"],
    "KORAPUT": ["KORAPUT", "KORAPUT ADM", "JEYPORE"],
    "JEYPORE": ["JEYPORE", "KORAPUT ADM", "KORAPUT"],
    "MAYURBHANJ": ["MAYURBHANJ", "MAYURBHANJ ADM", "BARIPADA"],
    "BARIPADA": ["BARIPADA", "MAYURBHANJ ADM", "MAYURBHANJ"],
    "KALAHANDI": ["KALAHANDI", "KALAHANDI ADM", "BHABANIPATANA"],
    "BHAWANIPATNA": ["BHABANIPATANA", "KALAHANDI ADM", "KALAHANDI"],
    "SAMBALPUR": ["SAMBALPUR", "SAMBALPUR ADM"],
    "PURI": ["PURI", "PURI ADM"],
    "BOUDH": ["BOUDH", "BOUDH ADM"],
    "NUAPADA": ["NUAPADA", "NUAPADA ADM"],
    "MALKANGIRI": ["MALKANAGIRI", "MALKANGIRI"],
}


class IGRCircuitBreaker:
    """Circuit breaker preventing upstream stampedes when official IGR service is degraded."""
    def __init__(self, failure_threshold: int = 3, recovery_timeout_sec: float = 30.0):
        self.failure_threshold = failure_threshold
        self.recovery_timeout_sec = recovery_timeout_sec
        self.failure_count = 0
        self.last_failure_time = 0.0
        self.state = "CLOSED"  # CLOSED, OPEN, HALF-OPEN

    def record_success(self):
        self.failure_count = 0
        self.state = "CLOSED"

    def record_failure(self):
        self.failure_count += 1
        self.last_failure_time = time.time()
        if self.failure_count >= self.failure_threshold:
            self.state = "OPEN"
            logger.warning(f"IGR Circuit Breaker tripped to OPEN after {self.failure_count} consecutive failures. Backing off for {self.recovery_timeout_sec}s.")

    def can_attempt(self) -> bool:
        if self.state == "CLOSED":
            return True
        if time.time() - self.last_failure_time > self.recovery_timeout_sec:
            self.state = "HALF-OPEN"
            logger.info("IGR Circuit Breaker transitioning to HALF-OPEN to probe upstream health.")
            return True
        return False


@dataclass
class CanonicalLandIdentity:
    district: str
    district_id: Optional[int]
    tahasil: str
    tahasil_id: Optional[str]
    village: str
    village_id: Optional[str]
    thana_number: Optional[str]
    plot: str


class IGRBenchmarkService:
    """
    Production-hardened client for Odisha Inspector General of Registration Benchmark Valuation.
    """
    BASE_URL = "https://igrodisha.gov.in/ViewFeeValue.aspx"
    STAMP_DUTY_URL = "https://igrodisha.gov.in/StampDutyCalc.aspx"
    DEFAULT_TIMEOUT_SEC = 10.0
    CACHE_TTL_SEC = 86400  # 24 hours
    CATALOG_TTL_SEC = 604800  # 7 days

    def __init__(self):
        # In-memory caches
        self._regoffices_cache: Dict[int, Tuple[float, List[Dict[str, Any]]]] = {}
        self._villages_cache: Dict[int, Tuple[float, List[Dict[str, Any]]]] = {}
        self._location_resolver_cache: Dict[str, Tuple[float, Tuple[Optional[int], str, Optional[int], Optional[str]]]] = {}
        self._valuation_cache: Dict[str, Tuple[float, IGRBenchmarkValuationResponse]] = {}
        self._registration_cache: Dict[str, Tuple[float, IGRRegistrationEstimateResponse]] = {}
        
        # Concurrency & Resilience
        self._dedup_locks: Dict[str, asyncio.Lock] = {}
        self._global_lock = asyncio.Lock()
        self._circuit_breaker = IGRCircuitBreaker(failure_threshold=3, recovery_timeout_sec=30.0)

    def _clean_string(self, val: Optional[str]) -> str:
        if not val:
            return ""
        return re.sub(r"\s+", " ", str(val)).strip()

    def _normalize_name_token(self, name: str) -> str:
        """Strips noise prefixes, suffixes, and punctuation for robust matching."""
        if not name:
            return ""
        s = name.upper()
        # Remove common prefixes
        s = re.sub(r"^[Gg][_\s]+|^[Uu]N\d+[_\s]+|^[Gg]AON[_\s]+|^[Gg]RAM[_\s]+", "", s)
        # Remove trailing thana/survey numbers (e.g. " - 271", "_271", " 271")
        s = re.sub(r"[\s\-_]+\d+$", "", s)
        # Remove GIS suffixes
        s = re.sub(r"[\-_]?(?:MOSAIC|WGS84|UTM|BOUNDARY|LAYER)\b", "", s)
        # Remove non-alphanumeric except space
        s = re.sub(r"[^A-Z0-9\s]", " ", s)
        return re.sub(r"\s+", " ", s).strip()

    def _name_stem(self, name: str) -> str:
        """
        Extracts transliteration-invariant stem by stripping trailing vowels ('A', 'O', 'E', 'I', 'U').
        E.g. 'BAINDOLO' -> 'BAINDL', 'BAINDOLA' -> 'BAINDL'.
        """
        if not name:
            return ""
        s = self._normalize_name_token(name).replace(" ", "")
        # Strip trailing vowels to equate common Odia English transliteration variants
        s = re.sub(r"[AEOIU]+$", "", s)
        return s

    def _extract_thana_number(self, text: str) -> Optional[str]:
        """Extracts numeric thana sequence if present (e.g. 'KERI - 271' -> '271')."""
        if not text:
            return None
        matches = re.findall(r"\b(\d{1,4})\b", text)
        if matches:
            return matches[-1]
        return None

    async def _post_json(self, endpoint: str, payload: Dict[str, Any], base_url: Optional[str] = None) -> Any:
        """Executes a JSON POST call to the ASP.NET AJAX PageMethod with timeout and retry."""
        target_base = base_url or self.BASE_URL
        url = f"{target_base}/{endpoint}"
        headers = {
            "Content-Type": "application/json; charset=utf-8",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Bhumitra/1.0",
            "Accept": "application/json, text/javascript, */*; q=0.01",
            "X-Requested-With": "XMLHttpRequest",
        }
        
        for attempt in range(2):
            try:
                async with httpx.AsyncClient(timeout=self.DEFAULT_TIMEOUT_SEC, verify=False) as client:
                    resp = await client.post(url, json=payload, headers=headers)
                    if resp.status_code != 200:
                        logger.warning(f"IGR upstream HTTP {resp.status_code} for {endpoint}: {resp.text[:200]}")
                        if attempt == 0:
                            await asyncio.sleep(0.5)
                            continue
                        self._circuit_breaker.record_failure()
                        return None
                    
                    data = resp.json()
                    self._circuit_breaker.record_success()
                    return data.get("d")
            except (httpx.RequestError, httpx.TimeoutException) as e:
                logger.warning(f"IGR upstream connection error on attempt {attempt+1} for {endpoint}: {e}")
                if attempt == 0:
                    await asyncio.sleep(0.8)
                    continue
                self._circuit_breaker.record_failure()
                return None
            except Exception as e:
                logger.error(f"IGR unexpected parsing error for {endpoint}: {e}")
                self._circuit_breaker.record_failure()
                return None
        return None

    async def get_registration_offices(self, dist_id: int) -> List[Dict[str, Any]]:
        """Retrieves Sub-Registrar offices for a given IGR district ID."""
        now = time.time()
        if dist_id in self._regoffices_cache:
            ts, offices = self._regoffices_cache[dist_id]
            if now - ts < self.CATALOG_TTL_SEC:
                return offices

        res = await self._post_json("GetRegoffice", {"distId": str(dist_id)})
        if isinstance(res, list):
            self._regoffices_cache[dist_id] = (now, res)
            return res
        return []

    async def get_villages_for_office(self, regoff_id: int) -> List[Dict[str, Any]]:
        """Retrieves revenue villages under an IGR Sub-Registrar office."""
        now = time.time()
        if regoff_id in self._villages_cache:
            ts, villages = self._villages_cache[regoff_id]
            if now - ts < self.CATALOG_TTL_SEC:
                return villages

        res = await self._post_json("GetVillage", {"RegoffId": str(regoff_id)})
        if isinstance(res, list):
            self._villages_cache[regoff_id] = (now, res)
            return res
        return []

    async def prefetch_district_villages(self, offices: List[Dict[str, Any]]) -> None:
        """Pre-fetches and caches all villages for the district offices concurrently."""
        uncached_offices = [
            o for o in offices
            if o.get("REGOFF_ID") not in self._villages_cache
            or (time.time() - self._villages_cache[o.get("REGOFF_ID")][0]) >= self.CATALOG_TTL_SEC
        ]
        if not uncached_offices:
            return

        sem = asyncio.Semaphore(6)
        async def fetch_one(ro_id: int):
            async with sem:
                await self.get_villages_for_office(ro_id)

        tasks = [fetch_one(o.get("REGOFF_ID")) for o in uncached_offices]
        await asyncio.gather(*tasks, return_exceptions=True)

    def _office_affinity_score(self, regoff_name: str, tahasil_name: str, dist_name: str) -> int:
        """
        Computes office affinity score (lower is higher priority) based on Tahasil and District root tokens.
        Score 0: Exact match with primary Sub-Registrar
        Score 1: Matches canonical root / alias of primary Sub-Registrar
        Score 2: Substring token match
        Score 3: ADM district-wide umbrella office (lowest priority)
        Score 4: Fallback (unrelated office in district)
        """
        ro = regoff_name.upper().strip()
        th = tahasil_name.upper().strip()
        dt = dist_name.upper().strip()
        is_adm = " ADM" in ro or ro.endswith("ADM") or "ADM." in ro
        
        th_clean = re.sub(r"\bSADAR\b", "", th).strip()
        th_tokens = [t for t in re.split(r"[^A-Z0-9]+", th) if len(t) > 2 and t != "SADAR"]
        
        if (th == ro or (th_clean and th_clean == ro)) and not is_adm:
            return 0
        
        aliases = set()
        for t in th_tokens:
            aliases.update(TAHASIL_ALIASES.get(t, [t]))
        for t in [dt]:
            aliases.update(TAHASIL_ALIASES.get(t, [t]))
            
        for a in aliases:
            if (a in ro or ro in a) and not is_adm:
                return 1
                
        if is_adm:
            return 3

        if any(t in ro for t in th_tokens):
            return 2
            
        return 4

    def _normalize_village(self, name: str) -> Tuple[str, str, Optional[str]]:
        """
        Extracts (clean_collapsed, clean_no_spaces, thana_number).
        Strips noise prefixes like UNIT, WARD, SECTOR, TOWN, MOUZA, G_, GAON, GRAM, UN*.
        """
        if not name:
            return ("", "", None)
        s = name.upper().strip()
        thana_no = self._extract_thana_number(s)
        
        clean = re.sub(r"^(?:UNIT|WARD|SECTOR|TOWN|MOUZA|VILLAGE|GP|GRAM|GAON|G|UN\d+)[_\s\-\d]*", "", s)
        clean = re.sub(r"[\s\-_]+\d+$", "", clean)
        clean = re.sub(r"[^A-Z0-9\s]", " ", clean)
        collapsed = re.sub(r"\s+", " ", clean).strip()
        no_spaces = collapsed.replace(" ", "")
        return (collapsed, no_spaces, thana_no)

    def _score_candidate(
        self,
        query_village_raw: str,
        query_tahasil_raw: str,
        query_dist_raw: str,
        query_thana: Optional[str],
        cand_ro_id: int,
        cand_ro_name: str,
        cand_vill_id: int,
        cand_vill_name: str,
        can_dist: str,
    ) -> Tuple[int, List[str]]:
        """
        Deterministic Candidate Scoring System.
        Computes weighted evidence score:
        - Exact thana number match: +50
        - Exact normalized name (no spaces): +30
        - Exact token set match: +25
        - Stem match (transliteration invariant): +15
        - Substring match: +5
        - Office / Tahasil affinity: +25 (exact primary), +20 (alias primary), +10 (partial), +0 (ADM)
        - Conflicting thana: -1000 (immediate disqualification)
        """
        score = 0
        reasons: List[str] = []

        q_col, q_ns, q_th = self._normalize_village(query_village_raw)
        c_col, c_ns, c_th = self._normalize_village(cand_vill_name)
        effective_thana = query_thana or q_th

        # 1. Thana number constraint (Hard check)
        if effective_thana and c_th:
            try:
                if int(effective_thana) != int(c_th):
                    return -1000, ["CONFLICTING_THANA"]
                else:
                    score += 50
                    reasons.append(f"EXACT_THANA_MATCH({effective_thana})")
            except ValueError:
                if str(effective_thana).strip() != str(c_th).strip():
                    return -1000, ["CONFLICTING_THANA"]
                else:
                    score += 50
                    reasons.append(f"EXACT_THANA_MATCH({effective_thana})")

        # 2. Name Matching
        if q_ns and c_ns and q_ns == c_ns:
            score += 30
            reasons.append("EXACT_NAME_MATCH")
        elif q_col and c_col and set(q_col.split()) == set(c_col.split()):
            score += 25
            reasons.append("TOKEN_SET_EXACT_MATCH")
        else:
            q_stem = self._name_stem(q_col)
            c_stem = self._name_stem(c_col)
            if q_stem and c_stem and q_stem == c_stem and len(q_stem) >= 4:
                score += 15
                reasons.append(f"STEM_TRANSLITERATION_MATCH({q_stem})")
            elif len(q_ns) >= 4 and (q_ns in c_ns or c_ns in q_ns):
                score += 5
                reasons.append("SUBSTRING_MATCH")

        # 3. Office & Tahasil Affinity
        aff = self._office_affinity_score(cand_ro_name, query_tahasil_raw, can_dist)
        if aff == 0:
            score += 25
            reasons.append("EXACT_PRIMARY_SUB_REGISTRAR")
        elif aff == 1:
            score += 20
            reasons.append("ALIAS_PRIMARY_SUB_REGISTRAR")
        elif aff == 2:
            score += 10
            reasons.append("PARTIAL_SUB_REGISTRAR")
        elif aff == 4:
            score += 5
            reasons.append("DEDICATED_SUB_REGISTRAR")
        elif aff == 3:
            reasons.append("ADM_UMBRELLA_OFFICE")

        return score, reasons

    def _generate_candidate_token(self, dist_id: int, ro_id: int, vill_id: int) -> str:
        """Generates a verifiable server-signed token for a candidate jurisdiction."""
        raw = f"{dist_id}:{ro_id}:{vill_id}:bhumitra_igr_salt"
        sig = hashlib.sha256(raw.encode()).hexdigest()[:12]
        return f"{dist_id}_{ro_id}_{vill_id}_{sig}"

    def _verify_candidate_token(self, token: str) -> Optional[Tuple[int, int, int]]:
        """Verifies candidate token integrity and extracts (dist_id, ro_id, vill_id)."""
        parts = token.split("_")
        if len(parts) != 4:
            return None
        try:
            dist_id, ro_id, vill_id, sig = int(parts[0]), int(parts[1]), int(parts[2]), parts[3]
            raw = f"{dist_id}:{ro_id}:{vill_id}:bhumitra_igr_salt"
            expected = hashlib.sha256(raw.encode()).hexdigest()[:12]
            if sig == expected:
                return dist_id, ro_id, vill_id
        except Exception:
            pass
        return None

    def _to_candidate_model(self, c: Dict[str, Any], dist_id: int) -> IGRValuationCandidate:
        thana_num = self._extract_thana_number(c["vill_name"])
        reasons_clean = []
        for r in c.get("reasons", []):
            if "EXACT_THANA_MATCH" in r:
                reasons_clean.append(f"Same thana number ({thana_num})")
            elif "EXACT_NAME_MATCH" in r:
                reasons_clean.append("Exact revenue village name match")
            elif "TOKEN_SET_EXACT_MATCH" in r:
                reasons_clean.append("Matching village name tokens")
            elif "STEM_TRANSLITERATION_MATCH" in r:
                reasons_clean.append("Matching phonetic spelling")
            elif "EXACT_PRIMARY_SUB_REGISTRAR" in r:
                reasons_clean.append("Primary Sub-Registrar jurisdiction")
            elif "ALIAS_PRIMARY_SUB_REGISTRAR" in r:
                reasons_clean.append("Sub-Registrar jurisdiction match")
            elif "PARTIAL_SUB_REGISTRAR" in r:
                reasons_clean.append("Same administrative block")
            elif "ADM_UMBRELLA_OFFICE" in r:
                reasons_clean.append("District registry office")

        if not reasons_clean:
            reasons_clean = ["Same district registry"]

        score = float(c.get("score", 0.0))
        confidence = "high" if score >= 40 else ("medium" if score >= 25 else "low")
        token = self._generate_candidate_token(dist_id, c["ro_id"], c["vill_id"])

        return IGRValuationCandidate(
            candidate_token=token,
            registration_office_id=c["ro_id"],
            registration_office_name=c["ro_name"],
            village_id=c["vill_id"],
            village_name=c["vill_name"],
            thana_number=thana_num,
            confidence=confidence,
            score=round(score, 1),
            match_reasons=reasons_clean,
        )

    async def validate_and_resolve_user_selection(
        self,
        dist_id: int,
        query_district: str,
        query_village: str,
        selected_regoff_id: Optional[int],
        selected_village_id: Optional[int],
        candidate_token: Optional[str] = None,
    ) -> Tuple[bool, Optional[str], Optional[str], Optional[str]]:
        """
        Validates user candidate selection against official IGR records.
        Returns: (is_valid, regoff_name, vill_name, error_message)
        """
        if candidate_token:
            verified = self._verify_candidate_token(candidate_token)
            if not verified:
                return False, None, None, "Invalid or corrupted candidate verification token."
            t_dist_id, t_ro_id, t_vill_id = verified
            if t_dist_id != dist_id:
                return False, None, None, "Candidate token does not match selected district."
            selected_regoff_id = t_ro_id
            selected_village_id = t_vill_id

        if not selected_regoff_id or not selected_village_id:
            return False, None, None, "Missing Registration Office or Village selection."

        offices = await self.get_registration_offices(dist_id)
        matching_office = next((o for o in offices if o.get("REGOFF_ID") == selected_regoff_id), None)
        if not matching_office:
            return False, None, None, f"Registration Office ID {selected_regoff_id} does not exist in {query_district}."

        ro_name = matching_office.get("REGOFF_NAME", "")
        villages = await self.get_villages_for_office(selected_regoff_id)
        matching_village = next((v for v in villages if v.get("VILL_ID") == selected_village_id), None)
        if not matching_village:
            return False, None, None, f"Village ID {selected_village_id} does not belong to Registration Office {ro_name}."

        vill_name = matching_village.get("VILL_NAME", "")

        # Strict thana check: if Bhumitra query village has a thana number, ensure no conflict
        q_thana = self._extract_thana_number(query_village)
        c_thana = self._extract_thana_number(vill_name)
        if q_thana and c_thana and str(q_thana).strip() != str(c_thana).strip():
            return False, None, None, f"Selected village thana ({c_thana}) conflicts with parcel thana ({q_thana})."

        return True, ro_name, vill_name, None

    async def resolve_igr_location(
        self,
        district_name: str,
        tahasil_name: str,
        village_name: str,
        b_id: Optional[str] = None,
        v_id: Optional[str] = None,
    ) -> Optional[Tuple[Optional[int], str, Optional[int], Optional[str], List[IGRValuationCandidate]]]:
        """
        Deterministically resolves:
        - (regoff_id, regoff_name, vill_id, vill_name, []) on unambiguous high-confidence automatic match
        - (None, "MAPPING_REQUIRES_USER_SELECTION", None, None, candidates) when user selection is needed
        - (None, "MAPPING_UNRESOLVED", None, None, []) when no candidate meets threshold
        """
        clean_dist = district_name.strip().upper()
        dist_id, can_dist = IGR_DISTRICT_MAP.get(clean_dist, (None, None))
        if not dist_id:
            for k, val in IGR_DISTRICT_MAP.items():
                if k in clean_dist or clean_dist in k:
                    dist_id, can_dist = val
                    break
            if not dist_id:
                logger.warning(f"District '{district_name}' not recognized in official IGR map.")
                return (None, "MAPPING_UNRESOLVED", None, None, [])

        thana_no = self._extract_thana_number(village_name)
        norm_v_key = f"{dist_id}:{self._normalize_name_token(tahasil_name)}:{self._normalize_name_token(village_name)}"
        if thana_no:
            norm_v_key += f":{thana_no}"
        if v_id:
            norm_v_key += f":v{v_id}"

        now = time.time()
        if norm_v_key in self._location_resolver_cache:
            ts, val = self._location_resolver_cache[norm_v_key]
            if now - ts < self.CATALOG_TTL_SEC:
                return val

        offices = await self.get_registration_offices(dist_id)
        if not offices:
            return (None, "MAPPING_UNRESOLVED", None, None, [])

        # Pre-fetch all villages in parallel for high performance
        await self.prefetch_district_villages(offices)

        # Score candidates across all offices in the district
        auto_candidates: List[Dict[str, Any]] = []
        all_plausible: List[Dict[str, Any]] = []

        for office in offices:
            ro_id = office.get("REGOFF_ID")
            ro_name = office.get("REGOFF_NAME", "")
            villages = await self.get_villages_for_office(ro_id)

            for v in villages:
                v_id_num = v.get("VILL_ID")
                v_name = v.get("VILL_NAME", "")
                score, reasons = self._score_candidate(
                    query_village_raw=village_name,
                    query_tahasil_raw=tahasil_name,
                    query_dist_raw=district_name,
                    query_thana=thana_no,
                    cand_ro_id=ro_id,
                    cand_ro_name=ro_name,
                    cand_vill_id=v_id_num,
                    cand_vill_name=v_name,
                    can_dist=can_dist,
                )
                if score < -500:
                    # Conflicting thana number is disqualified
                    continue

                c_item = {
                    "ro_id": ro_id,
                    "ro_name": ro_name,
                    "vill_id": v_id_num,
                    "vill_name": v_name,
                    "score": score,
                    "reasons": reasons,
                }
                if score >= 45:
                    auto_candidates.append(c_item)
                if score >= 15:
                    all_plausible.append(c_item)

        # 1. Check if an automatic unambiguous winner exists
        if auto_candidates:
            vill_map: Dict[int, Dict[str, Any]] = {}
            for c in auto_candidates:
                vid = c["vill_id"]
                if vid not in vill_map or c["score"] > vill_map[vid]["score"]:
                    vill_map[vid] = c

            ranked_auto = sorted(vill_map.values(), key=lambda x: x["score"], reverse=True)
            top = ranked_auto[0]

            is_unambiguous = True
            if len(ranked_auto) > 1:
                runner_up = ranked_auto[1]
                margin = top["score"] - runner_up["score"]
                if margin < 15:
                    is_unambiguous = False
                    logger.warning(
                        f"Ambiguous automatic match for '{village_name}': top '{top['vill_name']}' (score {top['score']}) "
                        f"vs runner-up '{runner_up['vill_name']}' (score {runner_up['score']}), margin={margin} < 15"
                    )

            if is_unambiguous:
                winner = (top["ro_id"], top["ro_name"], top["vill_id"], top["vill_name"], [])
                self._location_resolver_cache[norm_v_key] = (now, winner)
                return winner

        # 2. Automatic resolution was ambiguous or below confidence threshold.
        # Harvest top candidate jurisdictions for safe user selection.
        plausible_map: Dict[int, Dict[str, Any]] = {}
        for c in (auto_candidates + all_plausible):
            vid = c["vill_id"]
            if (
                vid not in plausible_map
                or c["score"] > plausible_map[vid]["score"]
                or (
                    c["score"] == plausible_map[vid]["score"]
                    and "ADM" in plausible_map[vid]["ro_name"]
                    and "ADM" not in c["ro_name"]
                )
            ):
                plausible_map[vid] = c

        ranked_plausible = sorted(plausible_map.values(), key=lambda x: x["score"], reverse=True)
        top_candidates = ranked_plausible[:15]

        candidate_models = [self._to_candidate_model(c, dist_id) for c in top_candidates]
        if candidate_models:
            return (None, "MAPPING_REQUIRES_USER_SELECTION", None, None, candidate_models)

        return (None, "MAPPING_UNRESOLVED", None, None, [])

    async def debug_resolve_igr_location(
        self,
        district_name: str,
        tahasil_name: str,
        village_name: str,
        plot_number: str,
        actual_area: Optional[float] = None,
        actual_area_unit: Optional[str] = "Decimal",
        b_id: Optional[str] = None,
        v_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Diagnostic helper providing complete step-by-step resolution trace.
        """
        t0 = time.time()
        clean_dist = district_name.strip().upper()
        dist_id, can_dist = IGR_DISTRICT_MAP.get(clean_dist, (None, None))
        if not dist_id:
            for k, val in IGR_DISTRICT_MAP.items():
                if k in clean_dist or clean_dist in k:
                    dist_id, can_dist = val
                    break

        trace: Dict[str, Any] = {
            "inputs": {
                "district": district_name,
                "tahasil": tahasil_name,
                "village": village_name,
                "plot": plot_number,
                "actual_area": actual_area,
                "actual_area_unit": actual_area_unit,
                "b_id": b_id,
                "v_id": v_id,
            },
            "district_resolved": {"id": dist_id, "name": can_dist} if dist_id else None,
            "offices_affinity": [],
            "resolved_office": None,
            "resolved_village": None,
            "kisam": None,
            "mrval_raw": None,
            "status": "MAPPING_UNRESOLVED",
            "reason": "VILLAGE_MAPPING_UNRESOLVED",
            "message": "",
        }

        if not dist_id:
            trace["status"] = "MAPPING_UNRESOLVED"
            trace["reason"] = "REGISTRATION_OFFICE_UNRESOLVED"
            trace["message"] = f"District '{district_name}' not recognized in official IGR map."
            trace["elapsed_ms"] = round((time.time() - t0) * 1000, 2)
            return trace

        offices = await self.get_registration_offices(dist_id)
        scored_offices = []
        for o in offices:
            score = self._office_affinity_score(o.get("REGOFF_NAME", ""), tahasil_name, can_dist)
            scored_offices.append((score, o))
        scored_offices.sort(key=lambda x: x[0])
        trace["offices_affinity"] = [
            {"score": s, "id": o.get("REGOFF_ID"), "name": o.get("REGOFF_NAME")}
            for s, o in scored_offices
        ]

        resolved = await self.resolve_igr_location(district_name, tahasil_name, village_name, b_id=b_id, v_id=v_id)
        if not resolved or resolved[1] == "MAPPING_UNRESOLVED":
            trace["status"] = "MAPPING_UNRESOLVED"
            trace["reason"] = "VILLAGE_MAPPING_UNRESOLVED"
            trace["message"] = "Official Sub-Registrar jurisdiction or village-thana could not be mapped for this location."
            trace["elapsed_ms"] = round((time.time() - t0) * 1000, 2)
            return trace

        ro_id, ro_name, vill_id, vill_name, candidates = resolved

        if ro_name == "MAPPING_REQUIRES_USER_SELECTION":
            trace["status"] = "MAPPING_REQUIRES_USER_SELECTION"
            trace["reason"] = "REQUIRES_USER_SELECTION"
            trace["candidates"] = [c.model_dump() for c in candidates]
            trace["message"] = f"Automatic resolution requires user selection ({len(candidates)} candidates available)."
            trace["elapsed_ms"] = round((time.time() - t0) * 1000, 2)
            return trace

        trace["resolved_office"] = {"id": ro_id, "name": ro_name}
        trace["resolved_village"] = {"id": vill_id, "name": vill_name}

        # Kisam
        kisam = await self.get_kisam_by_plot(plot_number, vill_id)
        trace["kisam"] = kisam

        # MRVal
        mr_payload = {
            "Dist": str(dist_id),
            "RegoffId": str(ro_id),
            "village": str(vill_id),
            "Plot": str(plot_number).strip(),
            "Area": "1",
            "Unit": "100",
            "unitTest": "Decimal (100D=1Acre)",
        }
        mr_res = await self._post_json("GetMRVal", mr_payload)
        trace["mrval_raw"] = mr_res

        if not mr_res or not isinstance(mr_res, str) or not mr_res.strip():
            trace["status"] = "NOT_FOUND"
            trace["reason"] = "NO_BENCHMARK_RECORD"
            trace["message"] = "Government benchmark value is not defined for this plot in official records."
        else:
            trace["status"] = "AVAILABLE"
            trace["reason"] = None
            trace["message"] = "Benchmark rate successfully resolved."

        trace["elapsed_ms"] = round((time.time() - t0) * 1000, 2)
        return trace

    async def get_kisam_by_plot(self, plot_number: str, village_id: int) -> Optional[str]:
        """Queries official Kisam category from IGR."""
        res = await self._post_json("GetKismByPlot", {
            "plotId": str(plot_number),
            "VillageId": str(village_id)
        })
        if isinstance(res, list) and len(res) > 0:
            return res[0].get("PLOTCAT_TYPE")
        return None

    async def get_benchmark_valuation(
        self,
        district: str,
        tahasil: str,
        village: str,
        plot: str,
        actual_area: Optional[float] = None,
        actual_area_unit: Optional[str] = "Decimal",
        b_id: Optional[str] = None,
        v_id: Optional[str] = None,
        selected_regoff_id: Optional[int] = None,
        selected_village_id: Optional[int] = None,
        candidate_token: Optional[str] = None,
        force_refresh: bool = False,
        request_id: Optional[str] = None,
    ) -> IGRBenchmarkValuationResponse:
        """
        Retrieves official IGR Benchmark Valuation with caching, deduplication, circuit breaker,
        user-assisted jurisdiction resolution, and normalized calculations.
        """
        cid = request_id[:8] if request_id else "direct"
        retrieved_at = datetime.now(timezone.utc).isoformat()
        clean_plot = self._clean_string(plot).replace(" ", "")

        dist_id, can_dist = IGR_DISTRICT_MAP.get(district.strip().upper(), (17, district.upper()))

        # Separate cache keys for user-assisted vs automatic requests
        if selected_regoff_id and selected_village_id:
            cache_key = f"{dist_id}:{selected_regoff_id}:{selected_village_id}:{clean_plot}:user"
        elif candidate_token:
            cache_key = f"{dist_id}:{candidate_token}:{clean_plot}:user"
        else:
            cache_key = f"{district.strip().upper()}:{tahasil.strip().upper()}:{village.strip().upper()}:{clean_plot}"

        now = time.time()

        logger.info(f"[IGR-BENCHMARK][{cid}] Request: dist={district}, tah={tahasil}, vill={village}, plot={clean_plot}, area={actual_area} {actual_area_unit}, selected_ro={selected_regoff_id}, selected_vill={selected_village_id}, force_refresh={force_refresh}")

        # Circuit Breaker Check
        if not self._circuit_breaker.can_attempt():
            logger.warning(f"[IGR-BENCHMARK][{cid}] Circuit breaker OPEN: fast-failing request.")
            return IGRBenchmarkValuationResponse(
                status="UNAVAILABLE",
                reason="IGR_SERVICE_TIMEOUT",
                retrieved_at=retrieved_at,
                district=district,
                plot_number=clean_plot,
                actual_parcel_area=actual_area,
                actual_parcel_area_unit=actual_area_unit,
                message="Official government benchmark service is temporarily unreachable."
            )

        # Check in-memory valuation cache (bypassed if force_refresh=True)
        if not force_refresh and cache_key in self._valuation_cache:
            ts, cached_resp = self._valuation_cache[cache_key]
            if now - ts < self.CACHE_TTL_SEC:
                logger.info(f"[IGR-BENCHMARK][{cid}] Cache hit for key={cache_key}")
                resp_copy = cached_resp.model_copy()
                resp_copy.cached = True
                if actual_area is not None:
                    resp_copy.actual_parcel_area = actual_area
                    resp_copy.actual_parcel_area_unit = actual_area_unit
                    resp_copy.calculation = self._calculate_indicative_amount(
                        actual_area=actual_area,
                        actual_area_unit=actual_area_unit,
                        unit_rates=resp_copy.unit_rates
                    )
                return resp_copy

        # Concurrency deduplication per plot identity
        async with self._global_lock:
            if cache_key not in self._dedup_locks:
                self._dedup_locks[cache_key] = asyncio.Lock()
            plot_lock = self._dedup_locks[cache_key]

        async with plot_lock:
            # Re-check cache inside lock
            if not force_refresh and cache_key in self._valuation_cache:
                ts, cached_resp = self._valuation_cache[cache_key]
                if now - ts < self.CACHE_TTL_SEC:
                    logger.info(f"[IGR-BENCHMARK][{cid}] Lock cache hit for key={cache_key}")
                    resp_copy = cached_resp.model_copy()
                    resp_copy.cached = True
                    return resp_copy

            is_user_assisted = False
            candidates: List[IGRValuationCandidate] = []

            if selected_regoff_id or selected_village_id or candidate_token:
                is_valid, ro_name, v_name, err_msg = await self.validate_and_resolve_user_selection(
                    dist_id=dist_id,
                    query_district=district,
                    query_village=village,
                    selected_regoff_id=selected_regoff_id,
                    selected_village_id=selected_village_id,
                    candidate_token=candidate_token,
                )
                if not is_valid:
                    logger.warning(f"[IGR-BENCHMARK][{cid}] Invalid user candidate selection: {err_msg}")
                    _, _, _, _, candidates = await self.resolve_igr_location(district, tahasil, village, b_id=b_id, v_id=v_id)
                    return IGRBenchmarkValuationResponse(
                        status="MAPPING_REQUIRES_USER_SELECTION",
                        reason="INVALID_CANDIDATE_SELECTION",
                        retrieved_at=retrieved_at,
                        district=can_dist,
                        plot_number=clean_plot,
                        actual_parcel_area=actual_area,
                        actual_parcel_area_unit=actual_area_unit,
                        candidates=candidates,
                        user_assistance_used=True,
                        selection_mode="USER_ASSISTED",
                        message=err_msg or "Invalid jurisdiction selection. Please choose from the candidate list."
                    )
                
                if candidate_token:
                    verified = self._verify_candidate_token(candidate_token)
                    if verified:
                        _, selected_regoff_id, selected_village_id = verified

                regoff_id = selected_regoff_id
                regoff_name = ro_name
                vill_id = selected_village_id
                vill_name = v_name
                is_user_assisted = True
            else:
                # 1. Resolve Location automatically
                resolved = await self.resolve_igr_location(district, tahasil, village, b_id=b_id, v_id=v_id)
                if not resolved or resolved[1] == "MAPPING_UNRESOLVED":
                    logger.warning(f"[IGR-BENCHMARK][{cid}] Jurisdiction unresolved for district={district}, tahasil={tahasil}, village={village}")
                    return IGRBenchmarkValuationResponse(
                        status="MAPPING_UNRESOLVED",
                        reason="VILLAGE_MAPPING_UNRESOLVED",
                        retrieved_at=retrieved_at,
                        district=district,
                        plot_number=clean_plot,
                        actual_parcel_area=actual_area,
                        actual_parcel_area_unit=actual_area_unit,
                        message="Official Sub-Registrar jurisdiction or village-thana could not be mapped for this location."
                    )

                regoff_id, regoff_name, vill_id, vill_name, candidates = resolved

                if regoff_name == "MAPPING_REQUIRES_USER_SELECTION":
                    logger.info(f"[IGR-BENCHMARK][{cid}] Jurisdiction requires user selection for {village} in {district}. Found {len(candidates)} candidates.")
                    return IGRBenchmarkValuationResponse(
                        status="MAPPING_REQUIRES_USER_SELECTION",
                        reason="REQUIRES_USER_SELECTION",
                        retrieved_at=retrieved_at,
                        district=can_dist,
                        plot_number=clean_plot,
                        actual_parcel_area=actual_area,
                        actual_parcel_area_unit=actual_area_unit,
                        candidates=candidates,
                        user_assistance_used=False,
                        selection_mode="AUTOMATIC",
                        message="We couldn't automatically determine the official valuation jurisdiction for this land. Choose the matching government jurisdiction to continue."
                    )

                is_user_assisted = False

            logger.info(f"[IGR-BENCHMARK][{cid}] Final IGR identity: dist={can_dist}({dist_id}), regoff={regoff_name}({regoff_id}), vill={vill_name}({vill_id}) (user_assisted={is_user_assisted})")

            # 2. Call GetMRVal with standard Rate Query parameters (Area=1, Unit=100 for Decimal)
            mr_payload = {
                "Dist": str(dist_id),
                "RegoffId": str(regoff_id),
                "village": str(vill_id),
                "Plot": clean_plot,
                "Area": "1",
                "Unit": "100",
                "unitTest": "Decimal (100D=1Acre)",
            }
            logger.info(f"[IGR-BENCHMARK][{cid}] Calling GetMRVal for plot={clean_plot} at village={vill_id}")
            mr_res = await self._post_json("GetMRVal", mr_payload)

            # Query Kisam category from IGR
            kisam_name = await self.get_kisam_by_plot(clean_plot, vill_id)

            # Plot existence verification for user-assisted selections
            if is_user_assisted and not kisam_name and (not mr_res or not isinstance(mr_res, str) or not mr_res.strip()):
                logger.warning(f"[IGR-BENCHMARK][{cid}] Plot {clean_plot} not found under selected {regoff_name}/{vill_name}")
                _, _, _, _, candidates = await self.resolve_igr_location(district, tahasil, village, b_id=b_id, v_id=v_id)
                return IGRBenchmarkValuationResponse(
                    status="MAPPING_REQUIRES_USER_SELECTION",
                    reason="PLOT_NOT_FOUND_IN_JURISDICTION",
                    retrieved_at=retrieved_at,
                    district=can_dist,
                    registration_office=regoff_name,
                    village_thana=vill_name,
                    plot_number=clean_plot,
                    actual_parcel_area=actual_area,
                    actual_parcel_area_unit=actual_area_unit,
                    candidates=candidates,
                    user_assistance_used=True,
                    selection_mode="USER_ASSISTED",
                    message=f"This jurisdiction does not contain Plot {clean_plot}. Please choose another jurisdiction."
                )

            if not mr_res or not isinstance(mr_res, str) or not mr_res.strip():
                logger.info(f"[IGR-BENCHMARK][{cid}] Empty GetMRVal response -> NOT_FOUND for plot={clean_plot}")
                return IGRBenchmarkValuationResponse(
                    status="NOT_FOUND",
                    reason="NO_BENCHMARK_RECORD",
                    retrieved_at=retrieved_at,
                    district=can_dist,
                    registration_office=regoff_name,
                    village_thana=vill_name,
                    kisam=kisam_name,
                    plot_number=clean_plot,
                    actual_parcel_area=actual_area,
                    actual_parcel_area_unit=actual_area_unit,
                    user_assistance_used=is_user_assisted,
                    selection_mode="USER_ASSISTED" if is_user_assisted else "AUTOMATIC",
                    message="The official IGR service does not currently provide a benchmark valuation for this plot. Record of Rights remains unaffected."
                )

            # 3. Parse '@$' separated values
            parts = mr_res.split("@$")
            if len(parts) < 6:
                logger.warning(f"[IGR-BENCHMARK][{cid}] Malformed GetMRVal response: {mr_res}")
                return IGRBenchmarkValuationResponse(
                    status="UNAVAILABLE",
                    reason="MALFORMED_UPSTREAM_RESPONSE",
                    retrieved_at=retrieved_at,
                    district=can_dist,
                    registration_office=regoff_name,
                    village_thana=vill_name,
                    plot_number=clean_plot,
                    message="Malformed benchmark rate response received from government service."
                )

            try:
                area_wise_val = float(parts[1]) if parts[1] else None
                stamp_duty = float(parts[2]) if parts[2] and parts[2] != "NA" else None
                reg_fee = float(parts[3]) if parts[3] and parts[3] != "NA" else None
                per_acre_val = float(parts[5]) if parts[5] else 0.0

                unit_rates = IGRUnitRates(
                    per_acre=round(per_acre_val, 2),
                    per_hectare=round(per_acre_val / 0.4046685642, 2),
                    per_decimal_100=round(per_acre_val / 100.0, 2),
                    per_decimal_1000=round(per_acre_val / 1000.0, 2),
                    per_square_meter=round(per_acre_val / 4046.856422, 2),
                    per_square_foot=round(per_acre_val / 43560.0, 2),
                )

                # Highest transaction value & transaction date (indices 8 and 7)
                highest_tx_val: Optional[float] = None
                tx_date: Optional[str] = None

                if len(parts) > 8 and parts[8] and parts[8] != "NA":
                    try:
                        highest_tx_val = round(float(parts[8]), 2)
                    except ValueError:
                        pass

                if len(parts) > 7 and parts[7] and parts[7] != "NA" and parts[7].strip():
                    tx_date = parts[7].strip()

                # Safe decimal calculation
                calc = self._calculate_indicative_amount(
                    actual_area=actual_area,
                    actual_area_unit=actual_area_unit,
                    unit_rates=unit_rates
                )

                response = IGRBenchmarkValuationResponse(
                    status="AVAILABLE",
                    reason=None,
                    retrieved_at=retrieved_at,
                    district=can_dist,
                    registration_office=regoff_name,
                    village_thana=vill_name,
                    kisam=kisam_name,
                    plot_number=clean_plot,
                    query_area=1.0,
                    query_unit="Decimal (100D=1Acre)",
                    actual_parcel_area=actual_area,
                    actual_parcel_area_unit=actual_area_unit,
                    area_wise_benchmark_value=area_wise_val,
                    unit_rates=unit_rates,
                    highest_transaction_value=highest_tx_val,
                    transaction_date=tx_date,
                    stamp_duty_estimate=stamp_duty,
                    registration_fee_estimate=reg_fee,
                    calculation=calc,
                    cached=False,
                    message=None,
                    candidates=None,
                    user_assistance_used=is_user_assisted,
                    selection_mode="USER_ASSISTED" if is_user_assisted else "AUTOMATIC",
                )

                # Store in cache
                self._valuation_cache[cache_key] = (now, response)
                return response

            except Exception as e:
                logger.error(f"[IGR-BENCHMARK][{cid}] Error parsing IGR benchmark values: {e}", exc_info=True)
                return IGRBenchmarkValuationResponse(
                    status="UNAVAILABLE",
                    reason="IGR_SERVICE_ERROR",
                    retrieved_at=retrieved_at,
                    district=can_dist,
                    registration_office=regoff_name,
                    village_thana=vill_name,
                    plot_number=clean_plot,
                    message="Failed to parse benchmark valuation rates."
                )

    def _calculate_indicative_amount(
        self,
        actual_area: Optional[float],
        actual_area_unit: Optional[str],
        unit_rates: Optional[IGRUnitRates]
    ) -> IGRBenchmarkCalculation:
        """Performs exact decimal arithmetic for total benchmark valuation calculation."""
        if actual_area is None or actual_area <= 0 or not unit_rates:
            return IGRBenchmarkCalculation(
                indicative_benchmark_amount=None,
                calculation_available=False,
                rate_per_decimal=unit_rates.per_decimal_100 if unit_rates else None
            )

        try:
            area_dec = Decimal(str(actual_area))
            unit_lower = (actual_area_unit or "decimal").lower().strip()

            if "acre" in unit_lower or "ac" in unit_lower:
                rate_dec = Decimal(str(unit_rates.per_acre))
                total_dec = (area_dec * rate_dec).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                formula = f"{actual_area:g} Acre × ₹{unit_rates.per_acre:,.2f}/Acre = ₹{total_dec:,.2f}"
            else:
                rate_dec = Decimal(str(unit_rates.per_decimal_100))
                total_dec = (area_dec * rate_dec).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                formula = f"{actual_area:g} Decimal × ₹{unit_rates.per_decimal_100:,.2f}/Decimal = ₹{total_dec:,.2f}"

            return IGRBenchmarkCalculation(
                indicative_benchmark_amount=float(total_dec),
                calculation_available=True,
                formula=formula,
                rate_per_decimal=unit_rates.per_decimal_100
            )
        except Exception as e:
            logger.warning(f"Decimal arithmetic error for area={actual_area}: {e}")
            return IGRBenchmarkCalculation(
                indicative_benchmark_amount=None,
                calculation_available=False,
                rate_per_decimal=unit_rates.per_decimal_100
            )

    async def get_registration_estimate(
        self,
        district: str,
        plot: str,
        tahasil: Optional[str] = None,
        village: Optional[str] = None,
        kism: Optional[str] = None,
        area: float = 1.0,
        unit: str = "Decimal",
        deed_type: str = "SALE IMMOVABLE",
        deed_id: Optional[int] = None,
        buyer_category: str = "STANDARD",
        selected_regoff_id: Optional[int] = None,
        selected_village_id: Optional[int] = None,
        candidate_token: Optional[str] = None,
        b_id: Optional[str] = None,
        v_id: Optional[str] = None,
        force_refresh: bool = False,
        request_id: Optional[str] = None,
    ) -> IGRRegistrationEstimateResponse:
        """
        Calculates official statutory Registration Fee & Stamp Duty estimate using Odisha IGR
        official PageMethod (StampDutyCalc.aspx/GetDoMRVal) with exact Decimal arithmetic.
        """
        t0 = time.time()
        cid = request_id[:8] if request_id else "direct"
        retrieved_at = datetime.now(timezone.utc).isoformat()

        # 1. Input sanitization
        clean_plot = self._clean_string(plot)
        clean_dist = self._clean_string(district).upper()
        clean_tah = self._clean_string(tahasil) if tahasil else ""
        clean_vill = self._clean_string(village) if village else ""
        clean_kism = self._clean_string(kism) if kism else None
        clean_area = max(0.0001, float(area)) if area else 1.0
        clean_buyer = "WOMEN_BUYER" if buyer_category and buyer_category.upper() in ("WOMEN_BUYER", "WOMEN", "FEMALE") else "STANDARD"

        # 2. Resolve Deed Type from verified catalog
        deed_info: Optional[IGRDeedInfo] = None
        if deed_id is not None:
            deed_info = next((d for d in IGR_OFFICIAL_DEEDS if d.id == deed_id), None)
        if not deed_info and deed_type:
            target_norm = self._clean_string(deed_type).upper()
            deed_info = next((d for d in IGR_OFFICIAL_DEEDS if d.name.strip().upper() == target_norm), None)
        if not deed_info:
            deed_info = IGR_OFFICIAL_DEEDS[0]  # Default: SALE IMMOVABLE (id=1)

        # 3. Resolve Unit Configuration
        unit_config = IGR_UNIT_CONFIGS.get(unit, IGR_UNIT_CONFIGS["Decimal"])
        unit_code = unit_config["unit_code"]
        unit_text = unit_config["unit_text"]

        # 4. Resolve District Identity
        dist_id, can_dist = IGR_DISTRICT_MAP.get(clean_dist, (None, None))
        if not dist_id:
            for k, val in IGR_DISTRICT_MAP.items():
                if k in clean_dist or clean_dist in k:
                    dist_id, can_dist = val
                    break
            if not dist_id:
                logger.warning(f"[IGR-REGISTRATION][{cid}] District '{district}' not recognized.")
                return IGRRegistrationEstimateResponse(
                    status="MAPPING_UNRESOLVED",
                    reason="REGISTRATION_OFFICE_UNRESOLVED",
                    calculated_at=retrieved_at,
                    district=district,
                    plot_number=clean_plot,
                    selected_area=clean_area,
                    selected_unit=unit,
                    deed_type=deed_info.name,
                    deed_id=deed_info.id,
                    buyer_category=clean_buyer,
                    message=f"District '{district}' not recognized in official IGR records."
                )

        # 5. Jurisdiction Resolution (Automatic or User-Assisted)
        is_user_assisted = False
        regoff_id: Optional[int] = None
        regoff_name: Optional[str] = None
        vill_id: Optional[int] = None
        vill_name: Optional[str] = None
        candidates: Optional[List[IGRValuationCandidate]] = None

        if candidate_token or (selected_regoff_id and selected_village_id):
            is_valid, ro_name, v_name, err_msg = await self.validate_user_candidate_selection(
                dist_id=dist_id,
                query_district=can_dist,
                query_village=clean_vill,
                selected_regoff_id=selected_regoff_id,
                selected_village_id=selected_village_id,
                candidate_token=candidate_token,
            )
            if not is_valid:
                logger.warning(f"[IGR-REGISTRATION][{cid}] User selection invalid: {err_msg}")
                _, _, _, _, candidates = await self.resolve_igr_location(district, clean_tah, clean_vill, b_id=b_id, v_id=v_id)
                return IGRRegistrationEstimateResponse(
                    status="MAPPING_REQUIRES_USER_SELECTION",
                    reason="INVALID_CANDIDATE_SELECTION",
                    calculated_at=retrieved_at,
                    district=can_dist,
                    plot_number=clean_plot,
                    selected_area=clean_area,
                    selected_unit=unit,
                    deed_type=deed_info.name,
                    deed_id=deed_info.id,
                    buyer_category=clean_buyer,
                    candidates=candidates,
                    user_assistance_used=True,
                    selection_mode="USER_ASSISTED",
                    message=err_msg or "Invalid jurisdiction selection. Please choose from candidate list."
                )

            if candidate_token:
                verified = self._verify_candidate_token(candidate_token)
                if verified:
                    _, selected_regoff_id, selected_village_id = verified

            regoff_id = selected_regoff_id
            regoff_name = ro_name
            vill_id = selected_village_id
            vill_name = v_name
            is_user_assisted = True
        else:
            resolved = await self.resolve_igr_location(district, clean_tah, clean_vill, b_id=b_id, v_id=v_id)
            if not resolved or resolved[1] == "MAPPING_UNRESOLVED":
                logger.warning(f"[IGR-REGISTRATION][{cid}] Jurisdiction unresolved for district={district}, tahasil={clean_tah}, village={clean_vill}")
                return IGRRegistrationEstimateResponse(
                    status="MAPPING_UNRESOLVED",
                    reason="VILLAGE_MAPPING_UNRESOLVED",
                    calculated_at=retrieved_at,
                    district=can_dist,
                    plot_number=clean_plot,
                    selected_area=clean_area,
                    selected_unit=unit,
                    deed_type=deed_info.name,
                    deed_id=deed_info.id,
                    buyer_category=clean_buyer,
                    message="Official Sub-Registrar jurisdiction or village-thana could not be resolved automatically."
                )

            regoff_id, regoff_name, vill_id, vill_name, candidates = resolved

            if regoff_name == "MAPPING_REQUIRES_USER_SELECTION":
                logger.info(f"[IGR-REGISTRATION][{cid}] Jurisdiction requires user selection for {clean_vill} in {can_dist}.")
                return IGRRegistrationEstimateResponse(
                    status="MAPPING_REQUIRES_USER_SELECTION",
                    reason="REQUIRES_USER_SELECTION",
                    calculated_at=retrieved_at,
                    district=can_dist,
                    plot_number=clean_plot,
                    selected_area=clean_area,
                    selected_unit=unit,
                    deed_type=deed_info.name,
                    deed_id=deed_info.id,
                    buyer_category=clean_buyer,
                    candidates=candidates,
                    user_assistance_used=False,
                    selection_mode="AUTOMATIC",
                    message="Official IGR jurisdiction could not be resolved automatically. Choose matching jurisdiction to calculate registration estimate."
                )

        # 6. Cache lookup
        cache_key = f"{can_dist}:{regoff_id}:{vill_id}:{clean_plot}:{clean_area:g}:{unit_code}:{deed_info.id}:{clean_buyer}"
        now = time.time()
        if not force_refresh and cache_key in self._registration_cache:
            ts, cached_resp = self._registration_cache[cache_key]
            if now - ts < self.CACHE_TTL_SEC:
                logger.info(f"[IGR-REGISTRATION][{cid}] Serving estimate from cache: {cache_key}")
                cached_copy = cached_resp.model_copy()
                cached_copy.cached = True
                return cached_copy

        # 7. Check circuit breaker
        if not self._circuit_breaker.can_attempt():
            logger.warning(f"[IGR-REGISTRATION][{cid}] Circuit breaker active. Fast-failing.")
            return IGRRegistrationEstimateResponse(
                status="UNAVAILABLE",
                reason="IGR_SERVICE_ERROR",
                calculated_at=retrieved_at,
                district=can_dist,
                registration_office=regoff_name,
                village_thana=vill_name,
                plot_number=clean_plot,
                selected_area=clean_area,
                selected_unit=unit,
                deed_type=deed_info.name,
                deed_id=deed_info.id,
                buyer_category=clean_buyer,
                message="Government valuation service temporarily unavailable. Please retry shortly."
            )

        # 8. Deduplication lock per unique plot & calculation parameters
        lock_key = f"reg:{cache_key}"
        async with self._global_lock:
            if lock_key not in self._dedup_locks:
                self._dedup_locks[lock_key] = asyncio.Lock()
            dedup_lock = self._dedup_locks[lock_key]

        async with dedup_lock:
            # Second check inside lock
            if not force_refresh and cache_key in self._registration_cache:
                ts, cached_resp = self._registration_cache[cache_key]
                if now - ts < self.CACHE_TTL_SEC:
                    cached_copy = cached_resp.model_copy()
                    cached_copy.cached = True
                    return cached_copy

            # 9. Call GetDoMRVal on StampDutyCalc.aspx
            payload = {
                "Dist": str(dist_id),
                "RegoffId": str(regoff_id),
                "village": str(vill_id),
                "Plot": clean_plot,
                "Area": f"{clean_area:g}",
                "Unit": unit_code,
                "unitTest": unit_text,
                "DeedID": str(deed_info.id),
            }
            logger.info(f"[IGR-REGISTRATION][{cid}] Calling GetDoMRVal for plot={clean_plot}, area={clean_area} {unit}, deed={deed_info.name}({deed_info.id})")
            mr_res = await self._post_json("GetDoMRVal", payload, base_url=self.STAMP_DUTY_URL)

            # Query Kisam category if not provided
            if not clean_kism:
                clean_kism = await self.get_kisam_by_plot(clean_plot, vill_id)

            if not mr_res or not isinstance(mr_res, str) or not mr_res.strip():
                logger.info(f"[IGR-REGISTRATION][{cid}] Empty GetDoMRVal response -> NOT_FOUND for plot={clean_plot}")
                return IGRRegistrationEstimateResponse(
                    status="NOT_FOUND",
                    reason="NO_BENCHMARK_RECORD",
                    calculated_at=retrieved_at,
                    district=can_dist,
                    registration_office=regoff_name,
                    village_thana=vill_name,
                    kisam=clean_kism,
                    plot_number=clean_plot,
                    selected_area=clean_area,
                    selected_unit=unit,
                    deed_type=deed_info.name,
                    deed_id=deed_info.id,
                    buyer_category=clean_buyer,
                    user_assistance_used=is_user_assisted,
                    selection_mode="USER_ASSISTED" if is_user_assisted else "AUTOMATIC",
                    message="The official IGR service does not currently provide a benchmark valuation or registration estimate for this plot. Record of Rights remains unaffected."
                )

            # 10. Parse '@$' separated response
            # Format: 'Area - Unit,@$MarketVal@$StampDuty@$RegFee@$RegFeeWomen'
            parts = mr_res.split("@$")
            if len(parts) < 4:
                logger.warning(f"[IGR-REGISTRATION][{cid}] Malformed GetDoMRVal response: {mr_res}")
                return IGRRegistrationEstimateResponse(
                    status="UNAVAILABLE",
                    reason="MALFORMED_UPSTREAM_RESPONSE",
                    calculated_at=retrieved_at,
                    district=can_dist,
                    registration_office=regoff_name,
                    village_thana=vill_name,
                    plot_number=clean_plot,
                    selected_area=clean_area,
                    selected_unit=unit,
                    deed_type=deed_info.name,
                    deed_id=deed_info.id,
                    buyer_category=clean_buyer,
                    message="Malformed calculation response received from government service."
                )

            try:
                # Exact Decimal Arithmetic
                benchmark_val_dec = Decimal(str(parts[1])).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                stamp_duty_dec = Decimal(str(parts[2])).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP) if parts[2] and parts[2] != "NA" else Decimal("0.00")
                reg_fee_dec = Decimal(str(parts[3])).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP) if parts[3] and parts[3] != "NA" else Decimal("0.00")
                
                stamp_women_dec: Optional[Decimal] = None
                if len(parts) > 4 and parts[4] and parts[4] != "NA" and parts[4].strip():
                    try:
                        stamp_women_dec = Decimal(str(parts[4])).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                    except Exception:
                        stamp_women_dec = None

                # Compute statutory Unit Rates based on query area and unit
                area_dec = Decimal(str(clean_area))
                factor_to_acre = Decimal(str(unit_config["factor_to_acre"]))
                acre_equivalent = area_dec * factor_to_acre

                rate_per_acre_dec = (benchmark_val_dec / acre_equivalent).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP) if acre_equivalent > 0 else Decimal("0.00")
                rate_per_dec_100 = (rate_per_acre_dec / Decimal("100")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                rate_per_hectare_dec = (rate_per_acre_dec / Decimal("0.4046685642")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                rate_per_sq_meter_dec = (rate_per_acre_dec / Decimal("4046.856422")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                rate_per_sq_foot_dec = (rate_per_acre_dec / Decimal("43560.0")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

                # Total standard charges
                total_standard_dec = (stamp_duty_dec + reg_fee_dec).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

                # Women Concession Calculation
                women_concession_applicable = False
                concession_amount_dec: Optional[Decimal] = None
                total_after_concession_dec: Optional[Decimal] = None

                if (
                    deed_info.women_concession_eligible
                    and stamp_women_dec is not None
                    and stamp_women_dec < stamp_duty_dec
                ):
                    women_concession_applicable = True
                    concession_amount_dec = (stamp_duty_dec - stamp_women_dec).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                    total_women_dec = (stamp_women_dec + reg_fee_dec).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
                    
                    if clean_buyer == "WOMEN_BUYER":
                        total_after_concession_dec = total_women_dec
                    else:
                        total_after_concession_dec = total_standard_dec
                else:
                    total_after_concession_dec = total_standard_dec

                formula = f"Benchmark ₹{benchmark_val_dec:,.2f} + Stamp Duty ₹{stamp_duty_dec:,.2f} + Registration Fee ₹{reg_fee_dec:,.2f} = ₹{total_standard_dec:,.2f}"

                response = IGRRegistrationEstimateResponse(
                    status="AVAILABLE",
                    reason=None,
                    calculated_at=retrieved_at,
                    district=can_dist,
                    registration_office=regoff_name,
                    village_thana=vill_name,
                    kisam=clean_kism,
                    plot_number=clean_plot,
                    selected_area=clean_area,
                    selected_unit=unit,
                    benchmark_rate_per_decimal=float(rate_per_dec_100),
                    benchmark_rate_per_acre=float(rate_per_acre_dec),
                    benchmark_rate_per_hectare=float(rate_per_hectare_dec),
                    benchmark_rate_per_sq_meter=float(rate_per_sq_meter_dec),
                    benchmark_rate_per_sq_foot=float(rate_per_sq_foot_dec),
                    benchmark_value_for_area=float(benchmark_val_dec),
                    deed_type=deed_info.name,
                    deed_id=deed_info.id,
                    buyer_category=clean_buyer,
                    stamp_duty=float(stamp_duty_dec),
                    registration_fee=float(reg_fee_dec),
                    total_government_charges=float(total_standard_dec),
                    women_buyer_concession_applicable=women_concession_applicable,
                    concession_amount=float(concession_amount_dec) if concession_amount_dec is not None else None,
                    total_after_concession=float(total_after_concession_dec) if total_after_concession_dec is not None else None,
                    formula=formula,
                    cached=False,
                    message=None,
                    candidates=None,
                    user_assistance_used=is_user_assisted,
                    selection_mode="USER_ASSISTED" if is_user_assisted else "AUTOMATIC",
                )

                # Store in cache
                self._registration_cache[cache_key] = (now, response)

                # Cache successful jurisdiction mapping for future auto-resolution
                if is_user_assisted:
                    thana_no = self._extract_thana_number(vill_name)
                    norm_v_key = f"{dist_id}:{self._normalize_name_token(clean_tah)}:{self._normalize_name_token(clean_vill)}"
                    if thana_no:
                        norm_v_key += f":{thana_no}"
                    winner = (regoff_id, regoff_name, vill_id, vill_name, [])
                    self._location_resolver_cache[norm_v_key] = (now, winner)
                    logger.info(f"[IGR-REGISTRATION][{cid}] Cached user-assisted mapping for {clean_vill} -> {regoff_name}/{vill_name}")

                elapsed_ms = round((time.time() - t0) * 1000, 2)
                logger.info(f"[IGR-REGISTRATION][{cid}] Calculated estimate in {elapsed_ms}ms: Total=₹{total_standard_dec}")
                return response

            except Exception as e:
                logger.error(f"[IGR-REGISTRATION][{cid}] Error parsing IGR calculation: {e}", exc_info=True)
                return IGRRegistrationEstimateResponse(
                    status="UNAVAILABLE",
                    reason="IGR_SERVICE_ERROR",
                    calculated_at=retrieved_at,
                    district=can_dist,
                    registration_office=regoff_name,
                    village_thana=vill_name,
                    plot_number=clean_plot,
                    selected_area=clean_area,
                    selected_unit=unit,
                    deed_type=deed_info.name,
                    deed_id=deed_info.id,
                    buyer_category=clean_buyer,
                    message="Failed to parse registration charges from government service."
                )


# Global singleton instance
igr_benchmark_service = IGRBenchmarkService()
