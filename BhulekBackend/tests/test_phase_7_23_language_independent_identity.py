"""
Phase 7.23: Language-Independent Parcel Identity & Verification Test Suite
"""
import pytest
from bs4 import BeautifulSoup
from models.ror_response import (
    RoRResponse,
    OwnerEntry,
    BhulekhLocationIdentity,
    RoRVerificationStatus,
)
from scrapers.bhulekh_scraper import verify_ror_result
from scrapers.structured_ror_parser import is_statutory_government_classification, parse_structured_ror


# ── Case 1: Language-Independent Tahasil (Banki ↔ ବାଙ୍କୀ) ─────────────────────
def test_case_1_language_independent_tahasil():
    soup = BeautifulSoup('''
    <div>
        <span id="lblDistrict">କଟକ</span>
        <span id="lblTahasil">ବାଙ୍କୀ</span>
        <span id="lblVillage">ବିଲତେନ୍ତୁଳିଆ</span>
        <span id="lblPlotNo">373</span>
    </div>
    ''', 'html.parser')
    
    loc_id = BhulekhLocationIdentity(
        district_id="3",
        tahasil_id="2",
        village_id="47",
        district_name="Cuttack",
        tahasil_name="Banki",
        village_name="Bilitentulia-44"
    )
    
    verif = verify_ror_result(
        soup=soup,
        requested_district="Cuttack",
        requested_tahasil="Banki",
        requested_village="Bilitentulia-44",
        requested_plot="373",
        location_identity=loc_id
    )
    
    assert verif.status == RoRVerificationStatus.VERIFIED
    assert verif.location_match is True
    assert verif.plot_match is True
    assert verif.identity_match_method == "CANONICAL_IDS_AND_PLOT"
    assert verif.canonical_identity == "3:2:47:373"


# ── Case 2: Whitespace-Variant Village (Chandakuda ↔ ଚାନ୍ଦ କୁଡା) ──────────────
def test_case_2_whitespace_variant_village():
    soup = BeautifulSoup('''
    <div>
        <span id="lblDistrict">ଭଦ୍ରକ</span>
        <span id="lblTahasil">ଚାନ୍ଦବାଲି</span>
        <span id="lblVillage">ଚାନ୍ଦ କୁଡା</span>
        <span id="lblPlotNo">241</span>
    </div>
    ''', 'html.parser')
    
    loc_id = BhulekhLocationIdentity(
        district_id="16",
        tahasil_id="3",
        village_id="22",
        district_name="Bhadrak",
        tahasil_name="Chandbali",
        village_name="Chandakuda"
    )
    
    verif = verify_ror_result(
        soup=soup,
        requested_district="Bhadrak",
        requested_tahasil="Chandbali",
        requested_village="Chandakuda",
        requested_plot="241",
        location_identity=loc_id
    )
    
    assert verif.status == RoRVerificationStatus.VERIFIED
    assert verif.location_match is True
    assert verif.plot_match is True
    assert verif.canonical_identity == "16:3:22:241"


# ── Case 3: Suffix-Variant Village (Bilitentulia-44 ↔ ବିଲତେନ୍ତୁଳିଆ) ────────────
def test_case_3_suffix_variant_village():
    soup = BeautifulSoup('''
    <div>
        <span id="lblDistrict">କଟକ</span>
        <span id="lblTahasil">ବାଙ୍କୀ</span>
        <span id="lblVillage">ବିଲତେନ୍ତୁଳିଆ</span>
        <span id="lblPlotNo">372</span>
    </div>
    ''', 'html.parser')
    
    loc_id = BhulekhLocationIdentity(
        district_id="3",
        tahasil_id="2",
        village_id="47",
        district_name="Cuttack",
        tahasil_name="Banki",
        village_name="Bilitentulia-44"
    )
    
    verif = verify_ror_result(
        soup=soup,
        requested_district="Cuttack",
        requested_tahasil="Banki",
        requested_village="Bilitentulia-44",
        requested_plot="372",
        location_identity=loc_id
    )
    
    assert verif.status == RoRVerificationStatus.VERIFIED
    assert verif.location_match is True
    assert verif.plot_match is True
    assert verif.canonical_identity == "3:2:47:372"


# ── Case 4: Level 3 Hard Conflict on District Mismatch ───────────────────────
def test_case_4_hard_conflict_district_mismatch():
    soup = BeautifulSoup('''
    <div>
        <span id="lblDistrict">କେନ୍ଦ୍ରାପଡା</span>
        <span id="lblTahasil">ରାଜକନିକା</span>
        <span id="lblVillage">ବଜରପୁର</span>
        <span id="lblPlotNo">775</span>
    </div>
    ''', 'html.parser')
    
    # Requested Bhadrak (16), but portal returned Kendrapara (19)
    loc_id = BhulekhLocationIdentity(
        district_id="16",
        tahasil_id="3",
        village_id="22",
        district_name="Bhadrak",
        tahasil_name="Chandbali",
        village_name="Chandakuda"
    )
    
    verif = verify_ror_result(
        soup=soup,
        requested_district="Bhadrak",
        requested_tahasil="Chandbali",
        requested_village="Chandakuda",
        requested_plot="775",
        location_identity=loc_id
    )
    
    assert verif.status == RoRVerificationStatus.MISMATCH
    assert verif.location_match is False
    assert verif.identity_match_method == "CONFLICT_DETECTED"
    assert "District ID Conflict" in verif.details


# ── Case 5: Level 3 Hard Conflict on Plot Mismatch ───────────────────────────
def test_case_5_hard_conflict_plot_mismatch():
    soup = BeautifulSoup('''
    <div>
        <span id="lblDistrict">ଭଦ୍ରକ</span>
        <span id="lblTahasil">ଚାନ୍ଦବାଲି</span>
        <span id="lblVillage">ଚାନ୍ଦ କୁଡା</span>
        <span id="lblPlotNo">242</span>
    </div>
    ''', 'html.parser')
    
    loc_id = BhulekhLocationIdentity(
        district_id="16",
        tahasil_id="3",
        village_id="22",
        district_name="Bhadrak",
        tahasil_name="Chandbali",
        village_name="Chandakuda"
    )
    
    verif = verify_ror_result(
        soup=soup,
        requested_district="Bhadrak",
        requested_tahasil="Chandbali",
        requested_village="Chandakuda",
        requested_plot="241",
        location_identity=loc_id
    )
    
    assert verif.status == RoRVerificationStatus.MISMATCH
    assert verif.plot_match is False
    assert verif.identity_match_method == "PLOT_MISMATCH"
    assert "Plot mismatch: Requested plot '241', but portal returned plot '242'" in verif.details


# ── Case 6: Cross-Village Same-Plot Canonical Isolation ──────────────────────
def test_case_6_cross_village_isolation():
    loc_chandakuda = BhulekhLocationIdentity(
        district_id="16", tahasil_id="3", village_id="22",
        district_name="Bhadrak", tahasil_name="Chandbali", village_name="Chandakuda"
    )
    loc_utkuda = BhulekhLocationIdentity(
        district_id="16", tahasil_id="3", village_id="8",
        district_name="Bhadrak", tahasil_name="Chandbali", village_name="Utkuda"
    )
    
    key_c = f"{loc_chandakuda.district_id}:{loc_chandakuda.tahasil_id}:{loc_chandakuda.village_id}:241"
    key_u = f"{loc_utkuda.district_id}:{loc_utkuda.tahasil_id}:{loc_utkuda.village_id}:241"
    
    assert key_c == "16:3:22:241"
    assert key_u == "16:3:8:241"
    assert key_c != key_u


# ── Case 7: Private Holding with Missing Owners Fails-Closed (Never Govt) ────
def test_case_7_missing_owners_fails_closed_never_govt():
    # Private land with no owners in table -> must raise ValueError (fail closed), NEVER classify as Govt Land
    html = '''
    <html>
        <body>
            <span id="lblDistrict">ଭଦ୍ରକ</span>
            <span id="lblTahasil">ଚାନ୍ଦବାଲି</span>
            <span id="lblVillage">ଚାନ୍ଦ କୁଡା</span>
            <span id="lblPlotNo">241</span>
            <span id="lblKhataNo">54</span>
            <span id="lblStatua">ସ୍ଥିତିବାନ</span>
            <table id="gvfront"></table>
        </body>
    </html>
    '''
    loc_id = BhulekhLocationIdentity(
        district_id="16", tahasil_id="3", village_id="22",
        district_name="Bhadrak", tahasil_name="Chandbali", village_name="Chandakuda"
    )
    
    with pytest.raises(ValueError) as exc_info:
        parse_structured_ror(
            html=html,
            district="Bhadrak",
            tahasil="Chandbali",
            village="Chandakuda",
            plot="241",
            location_identity=loc_id
        )
    
    assert "No verified citizen tenant records found" in str(exc_info.value)


# ── Case 8: Statutory Government Land Verification ───────────────────────────
def test_case_8_statutory_government_land_classification():
    # Statutory Gochar / Rakhit land -> correctly recognized as Government
    assert is_statutory_government_classification("ଗୋଚର", "ରକ୍ଷିତ") is True
    assert is_statutory_government_classification("ସରକାରୀ ଅନାବାଦୀ", "ଅନାବାଦୀ") is True
    assert is_statutory_government_classification("ରାସ୍ତା", "ସର୍ବସାଧାରଣ") is True
    assert is_statutory_government_classification("ଶାରଦ ଦୁଇ", "ସ୍ଥିତିବାନ") is False
    assert is_statutory_government_classification("ଘରବାରି", "ସ୍ଥିତିବାନ") is False
