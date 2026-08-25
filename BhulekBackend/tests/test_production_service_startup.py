"""
Regression tests for Gate 1.3.1: Production Service Startup and Model Resolution
Proves that services.ror_service can be imported without NameError,
RoRService can be instantiated, and list_districts returns properly typed models.
"""
import pytest
from fastapi.testclient import TestClient


def test_ror_service_module_import_and_instantiation():
    """Verify services.ror_service imports cleanly without NameError."""
    import services.ror_service as ror_mod
    service = ror_mod.RoRService()
    assert service is not None
    assert hasattr(service, "list_districts")
    assert hasattr(service, "list_tahasils")
    assert hasattr(service, "list_villages")
    assert hasattr(service, "list_ri_circles")


@pytest.mark.anyio
async def test_ror_service_list_districts_returns_models():
    """Verify list_districts returns properly formed BhulekhDistrict objects."""
    from services.ror_service import RoRService
    from models.ror_response import BhulekhDistrict
    
    service = RoRService()
    districts = await service.list_districts()
    assert len(districts) == 30
    assert isinstance(districts[0], BhulekhDistrict)
    assert districts[0].id == "1"
    assert districts[0].official_name == "BALASORE"


def test_fastapi_production_startup_endpoints():
    """Verify FastAPI application boots and health + GIS endpoints respond cleanly."""
    from app import create_app
    app = create_app()
    client = TestClient(app)
    
    # 1. Health Liveness Probe
    resp_health = client.get("/health")
    assert resp_health.status_code == 200
    data_health = resp_health.json()
    assert data_health["status"] == "ok"
    
    # 2. Readiness Probe
    resp_ready = client.get("/ready")
    assert resp_ready.status_code in [200, 503]  # If DB is not connected locally, returns 503 structured
    
    # 3. GIS Districts Endpoint
    resp_gis = client.get("/api/v1/gis/districts")
    assert resp_gis.status_code == 200
    districts = resp_gis.json()
    assert len(districts) == 30
    assert any(d.get("name") == "BHADRAK" or d.get("official_name") == "BHADRAK" or d.get("id") == "178" for d in districts)
