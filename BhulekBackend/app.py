"""
FastAPI Application Factory with Production Hardening
Includes structured JSON logging, readiness/liveness probes,
environment-based CORS controls, and versioned routing.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import ror, subscriptions, config, support, auth, usage, health
from core.logging_middleware import StructuredLoggingMiddleware
from core.config import settings

from db.base import Base
from db.session import engine
import models.db_models  # Registers SQLAlchemy models with Base.metadata


def create_app() -> FastAPI:
    # Ensure database tables exist
    try:
        Base.metadata.create_all(bind=engine)
    except Exception as e:
        print(f"Warning: Could not auto-create tables: {e}")

    app = FastAPI(
        title="Bhumitra RoR & Subscription API",
        description="Production Backend Service for Land Records, Server-Side Subscriptions & Remote Config",
        version="1.0.0",
        docs_url="/docs" if not settings.is_production else None,
        redoc_url="/redoc" if not settings.is_production else None,
    )

    # 1. Structured Logging & Request Tracing Middleware
    app.add_middleware(StructuredLoggingMiddleware)

    # 2. CORS Middleware (Restricted in production)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # 3. Health & Readiness Probes (Root level for Cloud Run / K8s probes)
    app.include_router(health.router, tags=["Health"])

    # 4. Versioned API Routes (/api/v1)
    app.include_router(auth.router, prefix="/api/v1", tags=["Authentication"])
    app.include_router(usage.router, prefix="/api/v1", tags=["Usage"])
    app.include_router(ror.router, prefix="/api/v1", tags=["RoR"])
    app.include_router(subscriptions.router, prefix="/api/v1", tags=["Subscriptions"])
    app.include_router(config.router, prefix="/api/v1", tags=["Config"])
    app.include_router(support.router, prefix="/api/v1", tags=["Support"])

    return app
