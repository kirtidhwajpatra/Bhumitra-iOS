"""
Launch billing rules for /api/v1/ror:
  - a user pays once per plot; re-opening it is free (even at 0 credits)
  - unverified or mismatched records are never charged
  - a stale client asking for preview=true still gets the full record when the
    server says the account has credit
  - unsigned Xcode/LocalTesting StoreKit JWS are rejected in production
"""
from contextlib import contextmanager

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import create_app
from core.security import create_access_token
from db.base import Base
from db.session import get_db
from models.db_models import CreditLedgerDB, UserDB
from services.usage_service import usage_service

URL = "/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot={plot}"


@pytest.fixture
def env(monkeypatch):
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine, autoflush=False)

    @contextmanager
    def test_session():
        s = Session()
        try:
            yield s
            s.commit()
        except Exception:
            s.rollback()
            raise
        finally:
            s.close()

    import db.session as session_mod
    import routers.ror as ror_mod
    import services.usage_service as us_mod
    monkeypatch.setattr(session_mod, "get_db_session", test_session)
    monkeypatch.setattr(session_mod, "SessionLocal", Session)
    monkeypatch.setattr(us_mod, "get_db_session", test_session)

    state = {"status": "VERIFIED", "plot_override": None, "calls": 0}

    async def fake_get_ror(*args, **kwargs):
        state["calls"] += 1
        return {
            "success": True, "district": "KEONJHAR", "tahasil": "SADAR", "village": "KERI",
            "plot": state["plot_override"] or kwargs.get("plot"), "khata_number": "142",
            "owners": [{"name": "Test Owner"}], "area": "0.15", "land_type": "Gharabari",
            "source": "bhulekh.ori.nic.in",
            "verification": {
                "status": state["status"], "requested_district": "KEONJHAR", "requested_tahasil": "SADAR",
                "requested_village": "KERI", "requested_plot": kwargs.get("plot"), "details": "test",
            },
        }

    monkeypatch.setattr(ror_mod.ror_service, "get_ror", fake_get_ror)

    def make_user(uid, credits):
        s = Session()
        s.add(UserDB(id=uid, free_credits=0, plot_credits=credits))
        s.commit()
        s.close()
        return {"Authorization": f"Bearer {create_access_token(user_id=uid)}"}

    def credits(uid):
        s = Session()
        try:
            return s.query(UserDB).filter_by(id=uid).first().plot_credits
        finally:
            s.close()

    def override_get_db():
        s = Session()
        try:
            yield s
        finally:
            s.close()

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as client:
        yield client, make_user, credits, state, Session


def test_same_plot_is_charged_once_and_stays_open_at_zero_credits(env):
    client, make_user, credits, _, _ = env
    h = make_user("bill_1", 1)
    first = client.get(URL.format(plot="1182"), headers=h)
    assert first.status_code == 200 and first.headers["X-Credit-Charged"] == "true"
    assert credits("bill_1") == 0
    # Re-open with 0 credits, even when the client asks for a preview.
    again = client.get(URL.format(plot="1182") + "&preview=true", headers=h)
    assert again.status_code == 200 and again.headers["X-Credit-Charged"] == "false"
    assert again.json()["owners"][0]["name"] == "Test Owner"
    assert credits("bill_1") == 0
    # A different plot is a new search and is blocked at 0 credits.
    assert client.get(URL.format(plot="999"), headers=h).status_code == 403


def test_unlock_key_normalizes_spacing_and_case():
    a = usage_service.plot_unlock_key("keonjhar", "Sadar ", "KERI", " 1182")
    b = usage_service.plot_unlock_key("KEONJHAR", "SADAR", "keri", "1182")
    assert a == b and a.startswith("ror_plot:")
    assert a != usage_service.plot_unlock_key("KEONJHAR", "SADAR", "KERI", "1183")


@pytest.mark.parametrize("status,override", [("MISMATCH", None), ("INSUFFICIENT_DATA", None), ("VERIFIED", "77")])
def test_unverified_or_mismatched_records_are_free(env, status, override):
    client, make_user, credits, state, Session = env
    state["status"], state["plot_override"] = status, override
    h = make_user("bill_2", 3)
    r = client.get(URL.format(plot="1182"), headers=h)
    assert r.status_code == 200 and r.headers["X-Credit-Charged"] == "false"
    assert credits("bill_2") == 3
    s = Session()
    assert s.query(CreditLedgerDB).filter_by(user_id="bill_2").count() == 0
    s.close()


def test_stale_client_preview_request_gets_full_record_when_server_has_credit(env):
    client, make_user, credits, _, _ = env
    h = make_user("bill_3", 2)
    r = client.get(URL.format(plot="1182") + "&preview=true", headers=h)
    assert r.status_code == 200 and r.headers["X-Credit-Charged"] == "true"
    assert r.json()["owners"][0]["name"] == "Test Owner"
    assert credits("bill_3") == 1


def test_zero_credit_preview_is_masked_and_free(env):
    client, make_user, credits, _, _ = env
    h = make_user("bill_4", 0)
    r = client.get(URL.format(plot="1182") + "&preview=true", headers=h)
    assert r.status_code == 200, r.text
    assert r.headers.get("X-Credit-Charged") in (None, "false")
    assert credits("bill_4") == 0


def test_production_rejects_unsigned_xcode_storekit_jws(monkeypatch):
    from appstoreserverlibrary.models.Environment import Environment
    from services.apple_verification_service import AppleVerificationService
    monkeypatch.setenv("ENV", "production")
    svc = AppleVerificationService()
    assert Environment.XCODE not in svc.verifiers and Environment.LOCAL_TESTING not in svc.verifiers
    assert svc._environment_order() == [Environment.PRODUCTION, Environment.SANDBOX]
    monkeypatch.setenv("ALLOW_LOCAL_STOREKIT_TESTING", "1")
    import base64, json
    body = base64.urlsafe_b64encode(json.dumps({
        "environment": "Xcode", "productId": "bhumitra.plots.200", "transactionId": "1",
        "bundleId": "com.kirtidhwaj.Bhumitra"}).encode()).decode().rstrip("=")
    from services.apple_verification_service import AppleVerificationError
    with pytest.raises(AppleVerificationError):
        svc.verify_and_decode_transaction(f"e30.{body}.sig")
    assert svc.APP_APPLE_ID == 6760656162
