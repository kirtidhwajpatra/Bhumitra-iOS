"""
Unit and Integration Tests for Google Authentication Endpoint (/api/v1/auth/google)
"""

import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app import create_app
from db.base import Base
from db.session import get_db
from services.google_auth_service import GoogleAuthError


@pytest.fixture
def test_client(tmp_path):
    db_file = tmp_path / "test_google_auth.db"
    engine = create_engine(f"sqlite:///{db_file}", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as client:
        yield client

    app.dependency_overrides.clear()


def test_google_auth_success(test_client):
    mock_payload = {
        "sub": "109876543210987654321",
        "email": "kirtidhwajpatra@gmail.com",
        "name": "Kirtidhwaj Patra",
        "picture": "https://lh3.googleusercontent.com/a/default-user",
        "iss": "https://accounts.google.com",
        "email_verified": True,
    }

    with patch("services.google_auth_service.google_auth_service.verify_identity_token", return_value=mock_payload):
        response = test_client.post(
            "/api/v1/auth/google",
            json={
                "id_token": "mock.google.id.token",
                "app_account_token": "test-uuid-1234",
                "full_name": "Kirtidhwaj Patra",
                "email": "kirtidhwajpatra@gmail.com",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert data["user"]["id"] == "google_109876543210987654321"
        assert data["message"] == "Sign in with Google verified successfully."


def test_google_auth_invalid_token(test_client):
    with patch("services.google_auth_service.google_auth_service.verify_identity_token", side_effect=GoogleAuthError("Invalid Google token signature", status_code=401)):
        response = test_client.post(
            "/api/v1/auth/google",
            json={
                "id_token": "invalid.token",
                "app_account_token": "test-uuid-1234",
            },
        )

        assert response.status_code == 401
        data = response.json()
        assert "Invalid Google token signature" in data["detail"]
