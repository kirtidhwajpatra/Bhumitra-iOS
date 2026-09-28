"""
Step 1: Automated Test Suite for Bhumitra Spatial Resolver Service
==================================================================
Tests authoritative resolution against real Odisha GIS geometry and 4K GEO cadastre:
  A. Patia (KIIT area): 20.35410, 85.81930 -> Khurda / Bhubaneswar / Patia / Plot 318 -> EXACT
  B. Raghunathpur Jali: 20.37219, 85.82703 -> Plot 62 -> EXACT
  C. Cuttack: 20.46811, 85.74845 -> Anantapur-64 / Plot 678 -> EXACT
  D. Keonjhar: 21.63525, 85.64172 -> G_Dimbo / Plot 220 -> EXACT
  E. Baleswar: 21.33749, 86.56554 -> Aghasula / Plot 188 -> EXACT
  F. Puri: 19.99680, 86.27777 -> Alangpur / Plot 770 -> EXACT
  G. Inside Odisha with no cadastral coverage: 20.38000, 85.73000 -> NO_CADASTRAL_COVERAGE
  H. Kolkata (Outside Odisha): 22.57260, 88.36390 -> OUTSIDE_ODISHA
  I. Raipur (Outside Odisha): 21.25140, 81.62960 -> OUTSIDE_ODISHA
  J. Non-existent plot in village: Patia + plot 999999 -> Clean False (no false parcel match)
  K. Duplicate village scenario: Raghunathpur does not produce an arbitrary village identity
  L. Upstream 500: mock 4K GEO failure -> PARCEL_SOURCE_TEMPORARILY_UNAVAILABLE
"""

import pytest
from unittest.mock import AsyncMock, patch
from services.spatial_resolver_service import (
    spatial_resolver_service,
    SpatialResolverService,
    LocationResolutionStatus,
)
from providers.odisha_4kgeo_provider import Odisha4KGEOProvider


@pytest.fixture
def resolver():
    return SpatialResolverService(provider=Odisha4KGEOProvider(timeout_seconds=10.0))


# ==============================================================================
# 1. Real Multi-District Exact Coordinate Tests
# ==============================================================================

@pytest.mark.anyio
async def test_a_patia_kiit_coordinate(resolver):
    """KIIT University point in Patia -> Khurda / Bhubaneswar / Patia / Plot 318 -> EXACT."""
    res = await resolver.resolve_coordinate(
        lat=20.35410, lng=85.81930, candidate_village_ids=["2002060"]
    )
    assert res.status == LocationResolutionStatus.EXACT
    assert res.district is not None
    assert res.district.name == "Khurda"
    assert res.village is not None
    assert res.village.id == "2002060"
    assert res.parcel is not None
    assert res.parcel.plot_number == "318"
    assert res.parcel.matched_by_geometry is True


@pytest.mark.anyio
async def test_b_raghunathpur_jali_coordinate(resolver):
    """Northern Bhubaneswar point in Raghunathpur Jali -> Plot 62 -> EXACT."""
    res = await resolver.resolve_coordinate(
        lat=20.37219, lng=85.82703, candidate_village_ids=["2002359"]
    )
    assert res.status == LocationResolutionStatus.EXACT
    assert res.district is not None
    assert res.district.name == "Khurda"
    assert res.village is not None
    assert res.village.id == "2002359"
    assert res.parcel is not None
    assert res.parcel.plot_number == "62"


@pytest.mark.anyio
async def test_c_cuttack_athagarh_coordinate(resolver):
    """Cuttack Athagarh point in Anantapur-64 -> Plot 678 -> EXACT."""
    res = await resolver.resolve_coordinate(
        lat=20.46811, lng=85.74845, candidate_village_ids=["0301088"]
    )
    assert res.status == LocationResolutionStatus.EXACT
    assert res.district is not None
    assert res.district.name == "Cuttack"
    assert res.village is not None
    assert res.village.id == "0301088"
    assert res.parcel is not None
    assert res.parcel.plot_number == "678"


@pytest.mark.anyio
async def test_d_keonjhar_sadar_coordinate(resolver):
    """Keonjhar Sadar point in G_Dimbo -> Plot 220 -> EXACT."""
    res = await resolver.resolve_coordinate(
        lat=21.63525, lng=85.64172, candidate_village_ids=["0704317"]
    )
    assert res.status == LocationResolutionStatus.EXACT
    assert res.district is not None
    assert res.district.name == "Keonjhar"
    assert res.village is not None
    assert res.village.id == "0704317"
    assert res.parcel is not None
    assert res.parcel.plot_number == "220"


@pytest.mark.anyio
async def test_e_baleswar_oupada_coordinate(resolver):
    """Baleswar Oupada point in Aghasula -> Plot 188 -> EXACT."""
    res = await resolver.resolve_coordinate(
        lat=21.33749, lng=86.56554, candidate_village_ids=["0110049"]
    )
    assert res.status == LocationResolutionStatus.EXACT
    assert res.district is not None
    assert res.district.name == "Baleswar"
    assert res.village is not None
    assert res.village.id == "0110049"
    assert res.parcel is not None
    assert res.parcel.plot_number == "188"


@pytest.mark.anyio
async def test_f_puri_astarang_coordinate(resolver):
    """Puri Astarang point in Alangpur -> Plot 770 -> EXACT."""
    res = await resolver.resolve_coordinate(
        lat=19.99680, lng=86.27777, candidate_village_ids=["1108050"]
    )
    assert res.status == LocationResolutionStatus.EXACT
    assert res.district is not None
    assert res.district.name == "Puri"
    assert res.village is not None
    assert res.village.id == "1108050"
    assert res.parcel is not None
    assert res.parcel.plot_number == "770"


# ==============================================================================
# 2. Outside Odisha & Coverage Boundary Edge Cases
# ==============================================================================

@pytest.mark.anyio
async def test_g_inside_odisha_no_cadastral_coverage(resolver):
    """Chandaka Forest point: inside Odisha district/tahasil, but outside digitized parcels."""
    res = await resolver.resolve_coordinate(
        lat=20.38000, lng=85.73000, candidate_village_ids=["2002076"]
    )
    assert res.status == LocationResolutionStatus.NO_CADASTRAL_COVERAGE
    assert res.district is not None
    assert res.district.name == "Khurda"
    assert res.parcel is None
    assert "cadastral parcel" in res.message.lower()


@pytest.mark.anyio
async def test_h_kolkata_outside_odisha(resolver):
    """Kolkata point is outside Odisha -> OUTSIDE_ODISHA immediately."""
    res = await resolver.resolve_coordinate(lat=22.57260, lng=88.36390)
    assert res.status == LocationResolutionStatus.OUTSIDE_ODISHA
    assert res.district is None
    assert res.village is None
    assert res.parcel is None


@pytest.mark.anyio
async def test_i_raipur_outside_odisha(resolver):
    """Raipur point is outside Odisha -> OUTSIDE_ODISHA immediately."""
    res = await resolver.resolve_coordinate(lat=21.25140, lng=81.62960)
    assert res.status == LocationResolutionStatus.OUTSIDE_ODISHA
    assert res.district is None
    assert res.village is None


# ==============================================================================
# 3. Intent, Duplicate Name, and Non-existent Plot Tests
# ==============================================================================

@pytest.mark.anyio
async def test_j_nonexistent_plot_no_false_match(resolver):
    """Querying plot 999999 in Patia returns None without picking a false plot."""
    provider = resolver.provider
    p = await provider.get_parcel_by_plot(
        village_id="2002060",
        exact_plot_number="999999",
        district_name="Khurda",
        block_name="Bhubaneswar",
    )
    assert p is None


@pytest.mark.anyio
async def test_k_duplicate_village_isolation(resolver):
    """
    Raghunathpur exists in Lingipur (2002212) and Raghunathpur (2002358/2002359).
    A coordinate at (20.37219, 85.82703) must resolve strictly to 2002359, not 2002212.
    """
    res = await resolver.resolve_coordinate(
        lat=20.37219, lng=85.82703, candidate_village_ids=["2002212", "2002359"]
    )
    assert res.status == LocationResolutionStatus.EXACT
    assert res.village.id == "2002359"
    assert res.village.id != "2002212"


# ==============================================================================
# 4. Upstream Failure / Resilience Tests
# ==============================================================================

@pytest.mark.anyio
async def test_l_upstream_500_resilience(resolver):
    """When 4K GEO returns HTTP 500, resolver safely returns PARCEL_SOURCE_TEMPORARILY_UNAVAILABLE."""
    with patch.object(resolver.provider, "get_village_parcels") as mock_parcels:
        mock_parcels.side_effect = ConnectionError("4K GEO viewCadistrialResult returned status 500")

        res = await resolver.resolve_coordinate(
            lat=20.35410, lng=85.81930, candidate_village_ids=["2002060"]
        )

        assert res.status == LocationResolutionStatus.PARCEL_SOURCE_TEMPORARILY_UNAVAILABLE
        assert res.district is not None
        assert res.district.name == "Khurda"
        assert res.parcel is None
        assert "unreachable" in res.message.lower()
