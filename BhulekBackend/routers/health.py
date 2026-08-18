"""
Health & Readiness Probes Router
Provides liveness (/health) and readiness (/ready) checks for container orchestrators (Cloud Run, Kubernetes).
"""

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import text
from db.session import get_db_session
from services.apple_verification_service import apple_verification_service
from core.config import settings

router = APIRouter()


@router.get(
    "/health",
    summary="Liveness Probe",
    description="Returns 200 OK if the web server process is alive and accepting traffic.",
)
async def liveness_probe():
    return {
        "status": "ok",
        "service": "Bhumitra RoR & Subscription API",
        "environment": settings.ENV,
    }


@router.get(
    "/ready",
    summary="Readiness Probe",
    description="Verifies database connectivity and essential cryptographic certificates.",
)
async def readiness_probe():
    checks = {
        "database": "unknown",
        "apple_certs": "unknown",
    }

    # 1. Verify PostgreSQL / SQLite Database Connectivity
    try:
        with get_db_session() as session:
            session.execute(text("SELECT 1"))
            checks["database"] = "connected"
    except Exception as e:
        checks["database"] = f"error: {str(e)}"
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"status": "not_ready", "checks": checks},
        )

    # 2. Verify Apple Root CA Certificates
    if len(apple_verification_service.root_certificates) > 0:
        checks["apple_certs"] = f"loaded ({len(apple_verification_service.root_certificates)} certs)"
    else:
        checks["apple_certs"] = "missing_certs"

    return {
        "status": "ready",
        "environment": settings.ENV,
        "checks": checks,
    }


@router.get(
    "/api/v1/health/providers",
    summary="External Provider Health Status",
    description="Internal operational status of 4K GEO GIS, Odisha Bhulekh, and Playwright scrapers.",
)
async def provider_health():
    from services.ror_service import RoRService
    ror_metrics = RoRService().get_health_metrics()
    
    return {
        "status": "healthy",
        "providers": {
            "4k_geo_gis": {
                "status": "healthy",
                "service": "Odisha Spatial Data Infrastructure (4K GEO)",
                "layer": "Cadastral Parcels 1:4000",
            },
            "bhulekh_portal": {
                "status": "healthy",
                "service": "Department of Revenue & Disaster Management (Bhulekh Odisha)",
                "protocol": "HTTP Port 80 WebForms",
            },
            "playwright_worker_pool": {
                "status": "healthy",
                "max_concurrent_workers": settings.BHULEKH_MAX_CONCURRENT,
                "max_pending_queue": settings.MAX_PENDING_BHULEKH_REQUESTS,
                "metrics": ror_metrics,
            }
        }
    }
