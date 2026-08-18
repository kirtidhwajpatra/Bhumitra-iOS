"""
Exact Khata / Khatiyan Search Unit Tests
Validates multi-plot Khata extraction, confirmation Khata number verification,
and fail-closed rejection on mismatched Khata records.
"""

import pytest
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient
from main import app
from scrapers.structured_ror_parser import parse_structured_khata_ror, parse_associated_plots
from models.ror_response import (
    RoRResponse,
    OwnerEntry,
    AssociatedPlot,
    RoRVerification,
    RoRVerificationStatus,
    BhulekhLocationIdentity,
)

client = TestClient(app)

MULTI_PLOT_KHATA_HTML = """
<html>
    <body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G KERI 271</span>
        <span id="lblKhatiyanslNo">142</span>
        <span id="lblName">Dillip Kumar Mahanta</span>
        <table id="gvfront">
            <tr>
                <td><span id="lblName">Dillip Kumar Mahanta</span></td>
                <td><span id="lblShare">1.000</span></td>
            </tr>
        </table>
        <table id="gvRorBack">
            <tr>
                <td><span id="lblPlotNo">1182</span></td>
                <td><span id="lbllType">Sarada-1</span></td>
                <td><span id="lblAcre">1</span></td>
                <td><span id="lblDecimil">25</span></td>
            </tr>
            <tr>
                <td><span id="lblPlotNo">1183</span></td>
                <td><span id="lbllType">Gharabari</span></td>
                <td><span id="lblAcre">0</span></td>
                <td><span id="lblDecimil">20</span></td>
            </tr>
            <tr>
                <td><span id="lblPlotNo">1184</span></td>
                <td><span id="lbllType">Baje-Fasali</span></td>
                <td><span id="lblAcre">0</span></td>
                <td><span id="lblDecimil">50</span></td>
            </tr>
        </table>
    </body>
</html>
"""


def test_1_multiple_plot_khata_extraction():
    """1. Parses all 3 distinct plots from multi-plot Khata without collapsing."""
    result = parse_structured_khata_ror(
        html=MULTI_PLOT_KHATA_HTML,
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        requested_khata="142",
    )
    assert result.success is True
    assert result.exact_khata_number == "142"
    assert len(result.owners) == 1
    assert result.owners[0].name == "Dillip Kumar Mahanta"
    assert result.total_plots_count == 3
    assert len(result.plots) == 3

    # Check distinct plot properties
    assert result.plots[0].plot_number == "1182"
    assert result.plots[0].land_type == "Sarada-1"
    assert result.plots[0].area == "1 Acre 25 Decimal"

    assert result.plots[1].plot_number == "1183"
    assert result.plots[1].land_type == "Gharabari"
    assert result.plots[1].area == "0 Acre 20 Decimal"

    assert result.plots[2].plot_number == "1184"
    assert result.plots[2].land_type == "Baje-Fasali"
    assert result.plots[2].area == "0 Acre 50 Decimal"


def test_2_mismatched_khata_rejected():
    """2. Rejects with ValueError if portal returned Khata 142 when Khata 500 was requested."""
    with pytest.raises(ValueError, match="Khata mismatch"):
        parse_structured_khata_ror(
            html=MULTI_PLOT_KHATA_HTML,
            district="KEONJHAR",
            tahasil="KEONJHAR SADAR",
            village="G KERI 271",
            requested_khata="500",  # Mismatched Khata
        )


def test_3_post_search_khata_endpoint_success():
    """3. Validates successful exact Khata search endpoint response with multi-plots."""
    mock_res = RoRResponse(
        success=True,
        plot="1182",
        village="G KERI 271",
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        khata_number="142",
        area="1.95 Acre",
        land_type="Sarada-1",
        owners=[OwnerEntry(name="Dillip Kumar Mahanta", share="1.000", khata_number="142")],
        plots=[
            AssociatedPlot(plot_number="1182", area="1 Acre 25 Decimal", land_type="Sarada-1"),
            AssociatedPlot(plot_number="1183", area="0 Acre 20 Decimal", land_type="Gharabari"),
        ],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED,
            requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR",
            requested_village="G KERI 271",
            requested_plot="1182",
            returned_district="KEONJHAR",
            returned_tahasil="KEONJHAR SADAR",
            returned_village="G KERI 271",
            returned_plot="1182",
            location_match=True,
            plot_match=True,
            details="Verified from mock portal.",
        ),
    )

    with patch("services.ror_service.RoRService.get_ror", AsyncMock(return_value=mock_res)):
        res = client.post(
            "/api/v1/search/khata",
            json={
                "district_id": "7",
                "tahasil_id": "4",
                "village_id": "179",
                "exact_khata_number": "142",
            },
        )
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        assert data["exact_khata_number"] == "142"
        assert len(data["plots"]) == 2
        assert data["plots"][0]["plot_number"] == "1182"
        assert data["plots"][1]["plot_number"] == "1183"
