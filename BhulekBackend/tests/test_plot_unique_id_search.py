"""
Plot Unique ID Search Unit Tests
Validates official Plot Unique ID lookup, strict validation, and verification preservation.
"""

import pytest
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient
from main import app
from models.ror_response import (
    RoRResponse,
    OwnerEntry,
    AssociatedPlot,
    RoRVerification,
    RoRVerificationStatus,
    BhulekhLocationIdentity,
)

client = TestClient(app)


def test_1_invalid_plot_unique_id_length_rejected():
    """1. Rejects short or empty plot unique ID."""
    res = client.post(
        "/api/v1/search/plot-unique-id",
        json={"plot_unique_id": "12"},
    )
    assert res.status_code == 400
    assert "Invalid Plot Unique ID" in res.json()["detail"]


def test_2_post_search_plot_unique_id_success():
    """2. Validates successful official Plot Unique ID search endpoint."""
    mock_res = RoRResponse(
        success=True,
        plot="1182",
        village="G KERI 271",
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        khata_number="142",
        area="1.45 Acre",
        land_type="Sarada-1",
        owners=[OwnerEntry(name="Dillip Kumar Mahanta", share="1.000", khata_number="142")],
        plots=[AssociatedPlot(plot_number="1182", area="1.45 Acre", land_type="Sarada-1")],
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
            details="Verified via Plot Unique ID from official portal.",
        ),
    )

    with patch("services.ror_service.RoRService.get_ror", AsyncMock(return_value=mock_res)):
        res = client.post(
            "/api/v1/search/plot-unique-id",
            json={"plot_unique_id": "OD-KJ-07-04-179-1182"},
        )
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        assert data["plot_unique_id"] == "OD-KJ-07-04-179-1182"
        assert data["plot_number"] == "1182"
        assert data["khata_number"] == "142"
        assert len(data["owners"]) == 1
        assert data["verification"]["status"] == "VERIFIED"
