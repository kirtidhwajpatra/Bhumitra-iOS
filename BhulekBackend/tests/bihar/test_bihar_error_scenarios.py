"""
Comprehensive Bihar Provider Error & Edge Scenario Test Suite
Tests fail-closed handling for:
1. Empty response
2. Invalid HTML
3. CAPTCHA challenge page
4. Portal timeout
5. HTTP 404 (upstream error)
6. HTTP 500 (upstream error)
7. Missing Khesra (preserves unverified state)
8. Missing Khata (preserves missing in source without fabricating)
9. Missing owner (preserves missing in source without fabricating)
10. Unexpected table structure
"""

import pytest
from unittest.mock import patch

from models.ror_response import RoRErrorCode, RoRVerificationStatus
from scrapers.bihar.bihar_jamabandi_parser import BiharJamabandiParser
from services.bihar_ror_service import BiharRoRService, BiharRoRServiceException
from core.config import settings


def test_1_empty_html_response():
    """Verify empty response fails closed with PARSE_FAILED."""
    res = BiharJamabandiParser.parse_html("", requested_plot="100")
    assert res.success is False
    assert res.error is not None
    assert res.error.code == RoRErrorCode.PARSE_FAILED


def test_2_malformed_html():
    """Verify malformed unclosed HTML does not crash parser and fails closed."""
    res = BiharJamabandiParser.parse_html("<div><table><tr><td>Unclosed content", requested_plot="100")
    assert res.verification.status == RoRVerificationStatus.INSUFFICIENT_DATA
    assert res.verification.location_match is False


def test_3_captcha_challenge_page():
    """Verify CAPTCHA challenge HTML triggers BHULEKH_TEMPORARILY_UNAVAILABLE error code."""
    captcha_html = """
    <html>
      <head><title>सुरक्षा कोड दर्ज करें</title></head>
      <body>
        <div id="divCaptcha">
          <label>कृपया नीचे दिए गए सुरक्षा कोड (Captcha) को दर्ज करें:</label>
          <input type="text" id="txtCaptcha" />
        </div>
      </body>
    </html>
    """
    res = BiharJamabandiParser.parse_html(captcha_html)
    assert res.success is False
    assert res.error is not None
    assert res.error.code == RoRErrorCode.BHULEKH_TEMPORARILY_UNAVAILABLE
    assert res.error.retryable is True


@pytest.mark.anyio
async def test_4_portal_timeout_handling():
    """Verify upstream portal timeout raises BHULEKH_TIMEOUT without data fabrication."""
    service = BiharRoRService()

    async def timeout_mock(*args, **kwargs):
        raise BiharRoRServiceException(
            code=RoRErrorCode.BHULEKH_TIMEOUT,
            message="Upstream Bihar portal connection timed out.",
            retryable=True,
        )

    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", True):
        with patch.object(service, "_execute_parse", side_effect=timeout_mock):
            with pytest.raises(BiharRoRServiceException) as exc_info:
                await service.get_ror(district="PATNA", anchal="PATNA SADAR", village="BEGAMPUR", plot="245")
            assert exc_info.value.code == RoRErrorCode.BHULEKH_TIMEOUT
            assert exc_info.value.retryable is True


@pytest.mark.anyio
async def test_5_http_404_handling():
    """Verify upstream HTTP 404 raises PLOT_NOT_FOUND without inventing records."""
    service = BiharRoRService()

    async def not_found_mock(*args, **kwargs):
        raise BiharRoRServiceException(
            code=RoRErrorCode.PLOT_NOT_FOUND,
            message="HTTP 404: Upstream record not found.",
            retryable=False,
        )

    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", True):
        with patch.object(service, "_execute_parse", side_effect=not_found_mock):
            with pytest.raises(BiharRoRServiceException) as exc_info:
                await service.get_ror(district="PATNA", anchal="PATNA SADAR", village="BEGAMPUR", plot="245")
            assert exc_info.value.code == RoRErrorCode.PLOT_NOT_FOUND


@pytest.mark.anyio
async def test_6_http_500_server_error():
    """Verify upstream HTTP 500 raises SERVER_ERROR cleanly."""
    service = BiharRoRService()

    async def server_error_mock(*args, **kwargs):
        raise BiharRoRServiceException(
            code=RoRErrorCode.SERVER_ERROR,
            message="HTTP 500: Internal server error on Bihar portal.",
            retryable=True,
        )

    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", True):
        with patch.object(service, "_execute_parse", side_effect=server_error_mock):
            with pytest.raises(BiharRoRServiceException) as exc_info:
                await service.get_ror(district="PATNA", anchal="PATNA SADAR", village="BEGAMPUR", plot="245")
            assert exc_info.value.code == RoRErrorCode.SERVER_ERROR


def test_7_missing_khesra_plot():
    """Verify record with missing Khesra preserves unverified plot status."""
    payload = {
        "location": {"district": "PATNA", "anchal": "PATNA SADAR", "mauza": "BEGAMPUR"},
        "register_identifiers": {"khata_number": "78", "khesra_number": None},
        "raiyat_details": [],
        "land_schedule": []
    }
    res = BiharJamabandiParser.parse_dict(payload, requested_plot="999")
    assert res.verification.plot_match is False


def test_8_missing_khata_preservation():
    """Verify missing Khata does not fabricate 'Khata 0' but preserves None/empty."""
    payload = {
        "location": {"district": "PATNA", "anchal": "PATNA SADAR", "mauza": "BEGAMPUR"},
        "register_identifiers": {"khata_number": None, "khesra_number": "245"},
        "raiyat_details": [{"raiyat_name": "राम प्रसाद"}],
        "land_schedule": [{"khesra_no": "245", "area_acre": "0.375"}]
    }
    res = BiharJamabandiParser.parse_dict(payload)
    assert res.success is True
    assert res.khata_number is None or res.khata_number == ""
    assert res.khata_number != "0"
    assert res.khata_number != "UNKNOWN"


def test_9_missing_owner_preservation():
    """Verify missing owner does not fabricate placeholder names."""
    payload = {
        "location": {"district": "PATNA", "anchal": "PATNA SADAR", "mauza": "BEGAMPUR"},
        "register_identifiers": {"khata_number": "78", "khesra_number": "245"},
        "raiyat_details": [],
        "land_schedule": [{"khesra_no": "245", "area_acre": "0.375"}]
    }
    res = BiharJamabandiParser.parse_dict(payload)
    assert res.success is True
    assert len(res.owners) == 0


def test_10_unexpected_table_structure():
    """Verify unstructured foreign table does not cause uncaught crash."""
    random_html = """
    <html>
      <body>
        <table id="tblUnrelatedStats">
          <tr><th>ColA</th><th>ColB</th><th>ColC</th></tr>
          <tr><td>Val1</td><td>Val2</td><td>Val3</td></tr>
        </table>
      </body>
    </html>
    """
    res = BiharJamabandiParser.parse_html(random_html, requested_plot="50")
    assert res.verification.status == RoRVerificationStatus.INSUFFICIENT_DATA
    assert res.verification.location_match is False
