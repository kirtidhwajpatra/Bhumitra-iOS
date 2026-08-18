"""
FastAPI Application Factory
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import ror, subscriptions


def create_app() -> FastAPI:
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

    app.include_router(ror.router, prefix="/api/v1", tags=["RoR"])
    app.include_router(subscriptions.router, prefix="/api/v1", tags=["Subscriptions"])

    @app.get("/health")
    async def health():
        return {"status": "ok", "service": "MyBhoomi RoR API"}

    return app
