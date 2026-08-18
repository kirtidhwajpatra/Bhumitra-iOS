"""
FastAPI Application Factory
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import ror, subscriptions, config, support, auth


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
        description="Backend service for Land Records & Apple StoreKit 2 Server Subscriptions",
        version="1.0.0",
    )

    # Allow requests from the iOS app (or a local dev frontend)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Narrow to your production domain in prod
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(auth.router, prefix="/api/v1", tags=["Authentication"])
    app.include_router(ror.router, prefix="/api/v1", tags=["RoR"])
    app.include_router(subscriptions.router, prefix="/api/v1", tags=["Subscriptions"])
    app.include_router(config.router, prefix="/api/v1", tags=["Config"])
    app.include_router(support.router, prefix="/api/v1", tags=["Support"])

    @app.get("/health")
    async def health():
        return {"status": "ok", "service": "MyBhoomi RoR API"}

    return app
