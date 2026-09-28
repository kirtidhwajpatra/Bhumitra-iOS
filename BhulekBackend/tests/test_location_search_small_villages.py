"""
Integration & Regression Tests for Bhumitra Location Search Coverage:
- Small village search (Keri, Maidankel)
- Exact, prefix, and phonetic variants
- Odia script search (ପଟିଆ, କେରି, ମଇଦାନକେଲା)
- Negative case filtering (Jaipur, Delhi, Mumbai, Bangalore, xyz)
- Provider outage fallback
- Spatial resolution to official cadastral parcels (0704330, 0704329)
"""

import pytest
from unittest.mock import patch
from services.location_search_service import location_search_service, LocationSearchResultType
from routers.location_search import _execute_resolution


@pytest.mark.anyio
async def test_keri_village_search():
    res = await location_search_service.search("Keri", limit=5)
    assert len(res.results) > 0
    top = res.results[0]
    assert "Keri" in top.title
    assert "Keonjhar" in top.subtitle
    assert top.type == LocationSearchResultType.REVENUE_VILLAGE
    assert top.latitude is not None
    assert top.longitude is not None
    assert abs(top.latitude - 21.68432) < 0.01
    assert abs(top.longitude - 85.71789) < 0.01


@pytest.mark.anyio
async def test_maidankel_village_search():
    res = await location_search_service.search("Maidankel", limit=5)
    assert len(res.results) > 0
    top = res.results[0]
    assert "Maidankela" in top.title or "Maidankel" in top.title
    assert "Keonjhar" in top.subtitle
    assert top.type == LocationSearchResultType.REVENUE_VILLAGE
    assert top.latitude is not None
    assert top.longitude is not None
    assert abs(top.latitude - 21.6643) < 0.01
    assert abs(top.longitude - 85.71056) < 0.01


@pytest.mark.anyio
async def test_patia_and_kiit_regression():
    # Patia
    res_patia = await location_search_service.search("Patia", limit=3)
    assert len(res_patia.results) > 0
    assert "Patia" in res_patia.results[0].title
    assert "Bhubaneswar" in res_patia.results[0].subtitle

    # KIIT
    res_kiit = await location_search_service.search("KIIT", limit=5)
    assert len(res_kiit.results) > 0
    assert any("KIIT" in r.title for r in res_kiit.results)

    # KIIT Campus 6
    res_kiit6 = await location_search_service.search("KIIT Campus 6", limit=3)
    assert len(res_kiit6.results) > 0
    assert "KIIT Campus 6" in res_kiit6.results[0].title


@pytest.mark.anyio
async def test_odia_script_searches():
    # Patia in Odia
    res_odia_patia = await location_search_service.search("ପଟିଆ", limit=3)
    assert len(res_odia_patia.results) > 0
    assert "Patia" in res_odia_patia.results[0].title or "ପଟିଆ" in res_odia_patia.results[0].title

    # Keri in Odia
    res_odia_keri = await location_search_service.search("କେରି", limit=3)
    assert len(res_odia_keri.results) > 0
    assert "Keri" in res_odia_keri.results[0].title or "କେରି" in res_odia_keri.results[0].title

    # Maidankela in Odia
    res_odia_maidan = await location_search_service.search("ମଇଦାନକେଲା", limit=3)
    assert len(res_odia_maidan.results) > 0
    assert "Maidankela" in res_odia_maidan.results[0].title or "ମଇଦାନକେଲା" in res_odia_maidan.results[0].title


@pytest.mark.anyio
async def test_negative_cases_return_zero_results():
    for negative_q in ["Jaipur", "Delhi", "Mumbai", "Bangalore", "xyz", "randomunrelated"]:
        res = await location_search_service.search(negative_q, limit=5)
        assert len(res.results) == 0, f"Query '{negative_q}' should return 0 results but got {len(res.results)}"


@pytest.mark.anyio
async def test_provider_outage_fallback():
    with patch.object(location_search_service.provider, "search", side_effect=ConnectionError("Provider Down")):
        # Small villages must still be discoverable via local catalog
        res_keri = await location_search_service.search("Keri", limit=3)
        assert len(res_keri.results) > 0
        assert "Keri" in res_keri.results[0].title

        res_maidan = await location_search_service.search("Maidankel", limit=3)
        assert len(res_maidan.results) > 0
        assert "Maidankela" in res_maidan.results[0].title


@pytest.mark.anyio
async def test_spatial_resolution_for_keri_and_maidankela():
    # Keri
    res_keri = await _execute_resolution(
        latitude=21.6843178,
        longitude=85.7178946,
        candidate_village_ids=["0704330"]
    )
    assert res_keri.status.value == "EXACT"
    assert res_keri.revenue_village_id == "0704330"
    assert res_keri.plot_number is not None

    # Maidankela
    res_maidan = await _execute_resolution(
        latitude=21.6643013,
        longitude=85.710559,
        candidate_village_ids=["0704329"]
    )
    assert res_maidan.status.value == "EXACT"
    assert res_maidan.revenue_village_id == "0704329"
    assert res_maidan.plot_number is not None


@pytest.mark.anyio
async def test_gobindapur_and_ghatgaon_cadastral_loading():
    """Verify Gobindapur (Banapur) and Ghatgaon (Keonjhar) resolve to official parcels."""
    from providers.odisha_4kgeo_provider import Odisha4KGEOProvider
    provider = Odisha4KGEOProvider()

    # 1. Gobindapur
    res_g = await _execute_resolution(
        latitude=19.76857,
        longitude=85.17131,
        candidate_village_ids=["2001100"]
    )
    assert res_g.status.value == "EXACT"
    assert res_g.revenue_village_id == "2001100"
    assert res_g.district == "Khurda"
    assert res_g.tahasil == "Banapur"

    fc_g = await provider.get_village_parcels("2001100")
    assert fc_g is not None
    assert fc_g.total_parcels == 1407

    # 2. Ghatgaon (Ghatagan 0706017)
    res_gh = await _execute_resolution(
        latitude=21.39223,
        longitude=85.88849,
        candidate_village_ids=["0706017"]
    )
    assert res_gh.status.value == "EXACT"
    assert res_gh.revenue_village_id == "0706017"
    assert res_gh.district == "Keonjhar"

    fc_gh = await provider.get_village_parcels("0706017")
    assert fc_gh is not None
    assert fc_gh.total_parcels == 2051


@pytest.mark.anyio
async def test_typo_tolerant_village_search():
    """
    Problem 2 Tests:
    1. 'naran' -> discovers Naranapur / Naranpur
    2. 'naranpur' -> discovers Naranapur / Naranpur (does NOT return 'No matching Odisha locations')
    3. 'naranapur' -> discovers Naranapur
    4. 1-char omission: 'ghatgan' -> discovers Ghatagan / Ghatgaon
    5. 'maidankel' -> discovers Maidankela
    6. Negative cases (Jaipur, Delhi, Mumbai, Bangalore, xyz) -> 0 results
    """
    # 1. naran
    res_naran = await location_search_service.search("naran", limit=5)
    assert len(res_naran.results) > 0
    titles_naran = [r.title for r in res_naran.results]
    assert any("Naranapur" in t or "Naranpur" in t or "Narana" in t for t in titles_naran)

    # 2. naranpur
    res_naranpur = await location_search_service.search("naranpur", limit=5)
    assert len(res_naranpur.results) > 0
    titles_naranpur = [r.title for r in res_naranpur.results]
    assert any("Naranapur" in t or "Naranpur" in t for t in titles_naranpur)

    # 3. naranapur
    res_naranapur = await location_search_service.search("naranapur", limit=5)
    assert len(res_naranapur.results) > 0
    titles_naranapur = [r.title for r in res_naranapur.results]
    assert any("Naranapur" in t for t in titles_naranapur)

    # 4. 1-char omission: ghatgan -> Ghatagan / Ghatgaon
    res_ghatgan = await location_search_service.search("ghatgan", limit=5)
    assert len(res_ghatgan.results) > 0
    titles_ghatgan = [r.title for r in res_ghatgan.results]
    assert any("Ghatagan" in t or "Ghatgaon" in t for t in titles_ghatgan)

    # 5. maidankel -> Maidankela
    res_maidan = await location_search_service.search("maidankel", limit=5)
    assert len(res_maidan.results) > 0
    titles_maidan = [r.title for r in res_maidan.results]
    assert any("Maidankela" in t or "Maidankel" in t for t in titles_maidan)

    # 6. Negative cases
    for neg_q in ["Jaipur", "Delhi", "Mumbai", "Bangalore", "xyz"]:
        res_neg = await location_search_service.search(neg_q, limit=5)
        assert len(res_neg.results) == 0, f"Expected 0 results for '{neg_q}', got {len(res_neg.results)}"



