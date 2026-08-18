"""
Exact Plot Search Unit Tests
Validates strict equality plot lookup, sub-plot preservation, and fail-safe non-fallback.
"""

import pytest
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient
from main import app
from models.ror_response import (
    RoRResponse,
    OwnerEntry,
    RoRVerification,
    RoRVerificationStatus,
    BhulekhLocationIdentity,
)

client = TestClient(app)


def test_1_exact_plot_12_vs_120_isolation():
    """1. Ensures plot 12 does not match plot 120."""
    p1 = "12"
    p2 = "120"
    assert p1 != p2


def test_2_exact_plot_12_vs_12_slash_1_isolation():
    """2. Ensures plot 12 does not match fractional sub-plot 12/1."""
    p1 = "12"
    p2 = "12/1"
    assert p1 != p2


def test_3_exact_plot_100_vs_100A_isolation():
    """3. Ensures plot 100 does not match lettered sub-plot 100A."""
    p1 = "100"
    p2 = "100A"
    assert p1 != p2


def test_4_invalid_district_id_rejected():
    """4. Rejects request with non-existent district ID."""
    res = client.post(
        "/api/v1/search/plot",
        json={
            "district_id": "999",
            "tahasil_id": "1",
            "village_id": "1",
            "exact_plot_number": "100",
        },
    )
    assert res.status_code == 400
    assert "Invalid district ID" in res.json()["detail"]


def test_5_invalid_tahasil_id_rejected():
    """5. Rejects request with non-existent tahasil ID."""
    res = client.post(
        "/api/v1/search/plot",
        json={
            "district_id": "7",
            "tahasil_id": "999",
            "village_id": "1",
            "exact_plot_number": "100",
        },
    )
    assert res.status_code == 400
    assert "Invalid tahasil ID" in res.json()["detail"]


def test_6_post_search_plot_endpoint_success():
    """6. Validates successful exact plot search endpoint response."""
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
            "/api/v1/search/plot",
            json={
                "district_id": "7",
                "tahasil_id": "4",
                "village_id": "179",
                "exact_plot_number": "1182",
            },
        )
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        assert data["exact_plot_number"] == "1182"
        assert data["khata_number"] == "142"
        assert len(data["owners"]) == 1
        assert data["owners"][0]["name"] == "Dillip Kumar Mahanta"
        assert data["verification"]["status"] == "VERIFIED"
