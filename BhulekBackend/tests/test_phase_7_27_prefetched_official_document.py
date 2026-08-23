"""
Phase 7.27.1 Tests: Pre-fetched Official RoR Document Architecture & Cache
Validates that single Playwright verification session captures both structured data and official PDF.
Ensures download endpoint serves cached documents with zero secondary portal lookups.
"""
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi.testclient import TestClient
from main import app
from services.official_document_cache import official_document_cache, OfficialDocumentCache
from models.ror_response import (
    RoRResponse,
    RoRVerification,
    RoRVerificationStatus,
    OfficialRoRDocument,
    OwnerEntry,
)


@pytest.fixture
def client():
    return TestClient(app)


def test_1_document_cache_store_and_retrieve():
    """Verify OfficialDocumentCache correctly stores and retrieves PDF bytes by canonical ID."""
    cache = OfficialDocumentCache(maxsize=10, ttl=60)
    fake_pdf = b"%PDF-1.4 official bhulekh content for test_parcel_777"
    canonical_id = "test:99:88:77:777"
    
    # Ensure fresh state
    if cache.has(canonical_id):
        import os
        os.remove(cache._file_path(canonical_id))
    
    assert not cache.has(canonical_id)
    assert cache.get(canonical_id) is None
    
    cache.store(canonical_id, fake_pdf, metadata={"district": "TestDistrict", "plot": "777"})
    
    assert cache.has(canonical_id)
    retrieved = cache.get(canonical_id)
    assert retrieved == fake_pdf


def test_2_canonical_identity_isolation():
    """Verify that different parcels with same plot number are strictly isolated by canonical key."""
    cache = OfficialDocumentCache(maxsize=10, ttl=60)
    chandakuda_pdf = b"%PDF-1.4 Chandakuda Plot 241"
    utkuda_pdf = b"%PDF-1.4 Utkuda Plot 241"
    
    cache.store("16:3:22:241", chandakuda_pdf)
    cache.store("16:3:8:241", utkuda_pdf)
    
    # Verify strict key isolation
    assert cache.get("16:3:22:241") == chandakuda_pdf
    assert cache.get("16:3:8:241") == utkuda_pdf
    assert cache.get("16:3:22:241") != utkuda_pdf
    assert cache.get("241") is None


def test_3_official_document_endpoint_serves_from_cache(client):
    """Verify GET /api/v1/ror/official-document/{document_id} returns cached PDF without scraping."""
    fake_pdf = b"%PDF-1.4 Official Bhulekh Document for Buxibazar 1110"
    canonical_id = "3:4:196:1110"
    official_document_cache.store(canonical_id, fake_pdf)
    
    response = client.get(f"/api/v1/ror/official-document/{canonical_id}")
    
    assert response.status_code == 200
    assert response.content == fake_pdf
    assert response.headers["content-type"] == "application/pdf"
    assert response.headers["x-official-document-source"] == "odisha_bhulekh"
    assert response.headers["x-canonical-identity"] == canonical_id


def test_4_official_document_endpoint_404_for_unknown_parcel(client):
    """Verify GET /api/v1/ror/official-document/{document_id} returns 404 when document not cached."""
    unknown_id = "99:99:999:9999"
    response = client.get(f"/api/v1/ror/official-document/{unknown_id}")
    
    assert response.status_code == 404
    detail = response.json().get("detail", {})
    assert detail.get("code") == "DOCUMENT_NOT_FOUND"


def test_5_unverified_parcel_has_no_cached_document(client):
    """Verify that unverified or failed lookups do not populate official documents."""
    unverified_id = "07:04:027:9999"
    assert not official_document_cache.has(unverified_id)
    
    response = client.get(f"/api/v1/ror/official-document/{unverified_id}")
    assert response.status_code == 404


def test_6_legacy_ror_pdf_endpoint_uses_fast_path(client):
    """Verify GET /api/v1/ror/pdf serves pre-rendered PDF from cache without executing Playwright."""
    fake_pdf = b"%PDF-1.4 Pre-rendered PDF for Simulia Barimelak 378"
    canonical_id = "1:6:140:378"
    official_document_cache.store(canonical_id, fake_pdf)
    
    # Call /ror/pdf with params matching canonical ID
    with patch("services.ror_service.RoRService.get_ror_pdf") as mock_scrape:
        response = client.get("/api/v1/ror/pdf?district=Baleswar&tahasil=Simulia&village=Barimelak&plot=378&b_id=0106&v_id=0106140")
        assert response.status_code == 200
        assert response.content == fake_pdf
        # Verify that heavy Playwright scraping method was NOT called
        mock_scrape.assert_not_called()
