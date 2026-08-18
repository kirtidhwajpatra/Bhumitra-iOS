"""
Remote Configuration Test Suite
Tests PostgreSQL persistence of app configuration, admin updates,
version compatibility rules, maintenance mode, and feature flags.
"""

import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app import create_app
from db.base import Base
from db.session import get_db
from models.db_models import AppConfigDB
from services.config_service import config_service, CONFIG_DB_KEY


@pytest.fixture
def test_config_env(tmp_path, monkeypatch):
    # Setup test database
    db_file = tmp_path / "test_config_suite.db"
    engine = create_engine(f"sqlite:///{db_file}", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    from contextlib import contextmanager

    @contextmanager
    def test_get_db_session():
        session = TestingSessionLocal()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    def override_get_db():
        session = TestingSessionLocal()
        try:
            yield session
        finally:
            session.close()

    # Monkeypatch
    import db.session as session_mod
    import services.config_service as cs_mod
    import routers.config as config_router_mod

    monkeypatch.setattr(session_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(session_mod, "SessionLocal", TestingSessionLocal)
    monkeypatch.setattr(cs_mod, "get_db_session", test_get_db_session)

    # Admin key
    test_admin_key = "test_super_secret_admin_key_999"
    monkeypatch.setattr(config_router_mod, "ADMIN_API_KEY", test_admin_key)

    # Clear config service cache
    config_service._cached_config = None
    config_service._cache_timestamp = 0

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    return client, TestingSessionLocal, test_admin_key


# ==============================================================================
# TESTS
# ==============================================================================

def test_1_get_default_remote_config(test_config_env):
    """1. GET /api/v1/app-config returns complete default configuration."""
    client, _, _ = test_config_env
    res = client.get("/api/v1/app-config")
    assert res.status_code == 200
    data = res.json()
    assert data["min_supported_version"] == "1.0.0"
    assert data["recommended_version"] == "1.0.0"
    assert data["latest_version"] == "1.0.0"
    assert data["maintenance_mode"] is False
    assert data["subscription_enabled"] is True
    assert data["features"]["pdf_download"] is True
    assert "app_store_url" in data
    assert data["config_version"] >= 1


def test_2_update_config_authenticated(test_config_env):
    """2. PUT /api/v1/app-config with valid X-Admin-Key updates values and increments config_version."""
    client, _, admin_key = test_config_env

    # Initial version
    initial_res = client.get("/api/v1/app-config")
    v_init = initial_res.json()["config_version"]

    # Admin update
    update_payload = {
        "min_supported_version": "2.0.0",
        "recommended_version": "2.2.0",
        "latest_version": "2.3.0",
        "app_store_url": "https://apps.apple.com/app/bhumitra-pro/id6742337788",
    }

    put_res = client.put(
        "/api/v1/app-config",
        headers={"X-Admin-Key": admin_key},
        json=update_payload,
    )
    assert put_res.status_code == 200
    updated_data = put_res.json()
    assert updated_data["min_supported_version"] == "2.0.0"
    assert updated_data["recommended_version"] == "2.2.0"
    assert updated_data["latest_version"] == "2.3.0"
    assert updated_data["config_version"] == v_init + 1
    assert updated_data["app_store_url"] == "https://apps.apple.com/app/bhumitra-pro/id6742337788"

    # Verify subsequent GET returns updated values
    get_res = client.get("/api/v1/app-config")
    assert get_res.json()["min_supported_version"] == "2.0.0"


def test_3_update_config_unauthorized(test_config_env):
    """3. PUT /api/v1/app-config without or with incorrect X-Admin-Key is rejected with 401."""
    client, _, _ = test_config_env

    # Missing header
    res1 = client.put(
        "/api/v1/app-config",
        json={"maintenance_mode": True},
    )
    assert res1.status_code == 401

    # Wrong key
    res2 = client.put(
        "/api/v1/app-config",
        headers={"X-Admin-Key": "wrong_key_attempt"},
        json={"maintenance_mode": True},
    )
    assert res2.status_code == 401


def test_4_maintenance_mode_toggle(test_config_env):
    """4. Setting maintenance_mode=True and custom maintenance_message reflects dynamically."""
    client, _, admin_key = test_config_env

    put_res = client.put(
        "/api/v1/app-config",
        headers={"X-Admin-Key": admin_key},
        json={
            "maintenance_mode": True,
            "maintenance_message": "Upgrading Cadastral GIS Servers. Back at 6:00 PM IST.",
        },
    )
    assert put_res.status_code == 200
    assert put_res.json()["maintenance_mode"] is True
    assert "Upgrading Cadastral" in put_res.json()["maintenance_message"]

    get_res = client.get("/api/v1/app-config")
    assert get_res.json()["maintenance_mode"] is True


def test_5_feature_flags_and_paywall_mutation(test_config_env):
    """5. Feature flags and dynamic paywall copy can be modified without app binary updates."""
    client, _, admin_key = test_config_env

    put_res = client.put(
        "/api/v1/app-config",
        headers={"X-Admin-Key": admin_key},
        json={
            "features": {
                "advanced_search": True,
                "property_history": True,
                "valuation": False,
                "pdf_download": True,
                "satellite_view": False,
            },
            "paywall": {
                "headline": "Special Monsoon Land Ownership Offer",
                "subheadline": "Unlimited RoR search and certified PDF downloads",
                "default_tier": "bhumitra_premium_yearly",
                "available_tiers": ["bhumitra_premium_yearly"],
            },
        },
    )
    assert put_res.status_code == 200
    data = put_res.json()
    assert data["features"]["property_history"] is True
    assert data["features"]["satellite_view"] is False
    assert data["paywall"]["headline"] == "Special Monsoon Land Ownership Offer"


def test_6_subscription_disabled_kill_switch(test_config_env):
    """6. subscription_enabled=False serves as an emergency kill-switch."""
    client, _, admin_key = test_config_env

    put_res = client.put(
        "/api/v1/app-config",
        headers={"X-Admin-Key": admin_key},
        json={"subscription_enabled": False, "premium_enabled": False},
    )
    assert put_res.status_code == 200
    assert put_res.json()["subscription_enabled"] is False
    assert put_res.json()["premium_enabled"] is False
