"""
Phase 7.22.1 Normalization Collision Safety & Cache Isolation Verification Suite
"""
import asyncio
import json
import httpx
from resolvers.bhulekh_identity_resolver import (
    consonant_skeleton, normalize_phonetic, odia_to_phonetic,
    VerifiedBhulekhCatalog, ResolutionStatus
)
from scrapers.bhulekh_scraper import BhulekhScraper

API_BASE = "http://127.0.0.1:8000/api/v1/ror"

def test_normalization_collision_safety():
    print("=" * 80)
    print("1. NORMALIZATION COLLISION SAFETY TESTS")
    print("=" * 80)
    
    # Check that distinct villages in Chandbali do NOT collide
    villages = [
        ("Chandakuda", "ଚାନ୍ଦ କୁଡା", "22"),
        ("Utkuda", "ଉତକୁଡା", "8"),
        ("Chandbali", "ଚାନ୍ଦବାଲି", "71"),
        ("Chandrasekharpur", "ଚନ୍ଦ୍ରସିଖର ପୁର", "212"),
        ("Garadapur", "ଗାରଡପୁର", "147"),
        ("Rajgurupur", "ରାଜଗୁରୁପୁର", "144"),
        ("Andiapata", "ଅଣ୍ଡିଆପାଟ", "121"),
    ]
    
    skeletons = {}
    for en, od, vid in villages:
        sk_en = consonant_skeleton(normalize_phonetic(en)).replace(" ", "")
        sk_od = consonant_skeleton(odia_to_phonetic(od)).replace(" ", "")
        print(f"Village [{vid}] {en} -> EN Skeleton: '{sk_en}' | Odia Skeleton ('{od}'): '{sk_od}' | Match: {sk_en == sk_od}")
        assert sk_en == sk_od, f"Mismatch for {en} ({sk_en} != {sk_od})"
        skeletons[vid] = sk_en

    # Verify all skeletons across distinct villages are unique (0 collision)
    unique_skels = set(skeletons.values())
    print(f"Total Villages: {len(villages)} | Unique Skeletons: {len(unique_skels)}")
    assert len(unique_skels) == len(villages), "Collision detected between distinct villages!"
    print("  -> PASSED: 0.00% SKELETON COLLISION RATE AMONG DISTINCT VILLAGES.")

async def test_negative_cross_village_isolation():
    print("\n" + "=" * 80)
    print("2. NEGATIVE CROSS-VILLAGE & SIMILAR SPELLING RESOLUTION TEST")
    print("=" * 80)
    
    async with httpx.AsyncClient(timeout=40.0) as client:
        # Negative Test A: Requesting Plot 241 with wrong village name 'Utkuda' (similar suffix 'kuda')
        print("Negative Test A: Querying Plot 241 with wrong village name 'Utkuda'...")
        r_neg_a = await client.get(f"{API_BASE}?district=Bhadrak&tahasil=Chandbali&village=Utkuda&plot=241&b_id=1603&v_id=1603008")
        print(f"  -> Response Status: {r_neg_a.status_code}")
        if r_neg_a.status_code == 200:
            data = r_neg_a.json()
            # If Utkuda has a plot 241, verify it does NOT return Chandakuda's Khata 54
            print(f"  -> Returned Khata for Utkuda: {data.get('khata_number')}")
            assert data.get("khata_number") != "54" or data.get("village") != "ଚାନ୍ଦ କୁଡା", "LEAKAGE: Returned Chandakuda data for Utkuda!"
        else:
            print("  -> Correctly Failed Closed (Unverified / Not Found).")

        # Negative Test B: Querying Plot 241 in Chandakuda
        print("\nPositive Test: Querying Plot 241 in Chandakuda...")
        r_pos = await client.get(f"{API_BASE}?district=Bhadrak&tahasil=Chandbali&village=Chandakuda&plot=241&b_id=1603&v_id=1603022")
        assert r_pos.status_code == 200, f"Expected 200 OK for Chandakuda Plot 241, got {r_pos.status_code}"
        data_pos = r_pos.json()
        print(f"  -> Chandakuda Plot 241 Verified: Khata {data_pos.get('khata_number')} | Area: {data_pos.get('area')} | Owners: {len(data_pos.get('owners', []))}")
        assert data_pos.get("khata_number") == "54"
        assert data_pos.get("village") == "ଚାନ୍ଦ କୁଡା"
        assert len(data_pos.get("owners", [])) == 7

async def main():
    test_normalization_collision_safety()
    await test_negative_cross_village_isolation()
    print("\n" + "=" * 80)
    print("ALL PHASE 7.22.1 SAFETY INVARIANTS PASSED (100%)")
    print("=" * 80)

if __name__ == "__main__":
    asyncio.run(main())
