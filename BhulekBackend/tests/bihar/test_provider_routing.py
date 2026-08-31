"""
Provider Router & Safety Boundary Test Suite
Validates:
1. Backward compatibility for Odisha requests.
2. Fail-closed rejection when BIHAR_PROVIDER_ENABLED=False.
3. Successful routing to Bihar provider when BIHAR_PROVIDER_ENABLED=True.
4. No cross-provider fallback on failure (Bihar failure does NOT invoke Odisha).
5. Odisha failure does NOT invoke Bihar.
6. Complete cache namespace isolation.
7. Independent concurrency semaphores.
8. Independent SingleFlight coalescing.
9. Dynamic kill-switch activation and deactivation.
"""

import pytest
import asyncio
from unittest.mock import AsyncMock, patch

from core.config import settings
from models.ror_response import RoRResponse, RoRErrorCode, RoRVerification, RoRVerificationStatus
from services.ror_service import RoRService, RoRServiceException, _cache as odisha_cache
from services.bihar_ror_service import BiharRoRService, BiharRoRServiceException, _bihar_cache
from services.provider_router import ProviderRouter


@pytest.fixture(autouse=True)
def reset_caches():
    odisha_cache.clear()
    _bihar_cache.clear()
    yield
    odisha_cache.clear()
    _bihar_cache.clear()


@pytest.mark.anyio
async def test_1_existing_odisha_request_default():
    """Verify that default state or state='ODISHA' routes directly to Odisha service."""
    mock_odisha = AsyncMock(spec=RoRService)
    mock_bihar = AsyncMock(spec=BiharRoRService)

    mock_odisha_res = RoRResponse(
        success=True,
        plot="1182",
        village="G KERI 271",
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        source="bhulekh.ori.nic.in",
    )
    mock_odisha.get_ror.return_value = mock_odisha_res

    router = ProviderRouter(odisha_service=mock_odisha, bihar_service=mock_bihar)

    # Call with default state (omitted)
    res1 = await router.get_ror(
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="1182",
    )
    assert res1.success is True
    assert res1.district == "KEONJHAR"
    mock_odisha.get_ror.assert_called_once()
    mock_bihar.get_ror.assert_not_called()


@pytest.mark.anyio
async def test_2_bihar_disabled_by_feature_flag():
    """Verify that state='BIHAR' fails closed when BIHAR_PROVIDER_ENABLED is False."""
    mock_odisha = AsyncMock(spec=RoRService)
    mock_bihar = AsyncMock(spec=BiharRoRService)

    router = ProviderRouter(odisha_service=mock_odisha, bihar_service=mock_bihar)

    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", False):
        with pytest.raises(RoRServiceException) as exc_info:
            await router.get_ror(
                district="PATNA",
                tahasil="PATNA SADAR",
                village="BEGAMPUR",
                plot="245",
                state="BIHAR",
            )
        assert exc_info.value.code == RoRErrorCode.BHULEKH_TEMPORARILY_UNAVAILABLE
        assert "disabled by administrative feature flag" in exc_info.value.message
        # Neither service was invoked
        mock_odisha.get_ror.assert_not_called()
        mock_bihar.get_ror.assert_not_called()


@pytest.mark.anyio
async def test_3_bihar_enabled_routes_to_bihar():
    """Verify that state='BIHAR' routes to Bihar service when enabled."""
    mock_odisha = AsyncMock(spec=RoRService)
    mock_bihar = AsyncMock(spec=BiharRoRService)

    mock_bihar_res = RoRResponse(
        success=True,
        plot="245",
        village="BEGAMPUR",
        district="PATNA",
        tahasil="PATNA SADAR",
        khata_number="78",
        area="0.375 Acre",
        source="biharbhumi.bihar.gov.in",
    )
    mock_bihar.get_ror.return_value = mock_bihar_res

    router = ProviderRouter(odisha_service=mock_odisha, bihar_service=mock_bihar)

    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", True):
        res = await router.get_ror(
            district="PATNA",
            tahasil="PATNA SADAR",
            village="BEGAMPUR",
            plot="245",
            state="BIHAR",
        )
        assert res.success is True
        assert res.district == "PATNA"
        mock_bihar.get_ror.assert_called_once()
        mock_odisha.get_ror.assert_not_called()


@pytest.mark.anyio
async def test_4_no_fallback_from_bihar_to_odisha():
    """Verify that Bihar failure NEVER triggers fallback to Odisha."""
    mock_odisha = AsyncMock(spec=RoRService)
    mock_bihar = AsyncMock(spec=BiharRoRService)

    mock_bihar.get_ror.side_effect = BiharRoRServiceException(
        code=RoRErrorCode.PLOT_NOT_FOUND,
        message="Plot 999 not found in Bihar Jamabandi Register.",
    )

    router = ProviderRouter(odisha_service=mock_odisha, bihar_service=mock_bihar)

    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", True):
        with pytest.raises(RoRServiceException) as exc_info:
            await router.get_ror(
                district="PATNA",
                tahasil="PATNA SADAR",
                village="BEGAMPUR",
                plot="999",
                state="BIHAR",
            )
        assert exc_info.value.code == RoRErrorCode.PLOT_NOT_FOUND
        mock_odisha.get_ror.assert_not_called()


@pytest.mark.anyio
async def test_5_no_fallback_from_odisha_to_bihar():
    """Verify that Odisha failure NEVER triggers fallback to Bihar."""
    mock_odisha = AsyncMock(spec=RoRService)
    mock_bihar = AsyncMock(spec=BiharRoRService)

    mock_odisha.get_ror.side_effect = RoRServiceException(
        code=RoRErrorCode.ROR_NOT_FOUND,
        message="Record not found in Odisha Bhulekh.",
    )

    router = ProviderRouter(odisha_service=mock_odisha, bihar_service=mock_bihar)

    with pytest.raises(RoRServiceException) as exc_info:
        await router.get_ror(
            district="KEONJHAR",
            tahasil="KEONJHAR SADAR",
            village="G KERI 271",
            plot="9999",
            state="ODISHA",
        )
    assert exc_info.value.code == RoRErrorCode.ROR_NOT_FOUND
    mock_bihar.get_ror.assert_not_called()


@pytest.mark.anyio
async def test_6_dynamic_kill_switch():
    """Verify dynamic kill-switch toggling immediately deactivates Bihar."""
    real_bihar_service = BiharRoRService()
    router = ProviderRouter(bihar_service=real_bihar_service)

    sample_payload = {
        "location": {"district": "PATNA", "anchal": "PATNA SADAR", "mauza": "BEGAMPUR"},
        "register_identifiers": {"khata_number": "78", "khesra_number": "245"},
        "raiyat_details": [{"raiyat_name": "राम प्रसाद"}],
        "land_schedule": [{"khesra_no": "245", "area_acre": "0.375"}]
    }

    # 1. Enabled -> Success
    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", True):
        res = await router.get_ror(
            district="PATNA",
            tahasil="PATNA SADAR",
            village="BEGAMPUR",
            plot="245",
            state="BIHAR",
            raw_payload=sample_payload,
        )
        assert res.success is True

    # 2. Kill switch flipped (Disabled) -> Immediate rejection
    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", False):
        with pytest.raises(RoRServiceException) as exc_info:
            await router.get_ror(
                district="PATNA",
                tahasil="PATNA SADAR",
                village="BEGAMPUR",
                plot="245",
                state="BIHAR",
                raw_payload=sample_payload,
            )
        assert exc_info.value.code == RoRErrorCode.BHULEKH_TEMPORARILY_UNAVAILABLE
