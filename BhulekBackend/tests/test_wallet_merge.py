"""
Guest-to-account wallet merge (the "can't pay a second time after signing in" bug).

Journey that used to break: buy as a guest -> sign in with Google -> every old
purchase came back as "belongs to a different account" (409 / 403), the
transaction never finished, and StoreKit wouldn't charge again.
"""
import pytest

import services.wallet_service as wallet_mod
from core.security import create_access_token
from models.db_models import (
    AuthIdentityDB, ConsumableTransactionDB, CreditLedgerDB, SubscriptionDB, UserDB,
)
from tests.test_consumable_purchases import pki_helper, test_app_and_db  # noqa: F401 (fixtures)

GUEST = "dev_FC6E3372-TEST"
ACCOUNT = "usr_google_test"
GUEST_TOKEN = "494ca49c-guest-token"
ACCOUNT_TOKEN = "cca33225-account-token"


@pytest.fixture
def env(test_app_and_db, monkeypatch):  # noqa: F811
    client, session_factory = test_app_and_db
    from contextlib import contextmanager

    @contextmanager
    def sess():
        s = session_factory()
        try:
            yield s
            s.commit()
        except Exception:
            s.rollback()
            raise
        finally:
            s.close()

    import services.usage_service as us_mod
    monkeypatch.setattr(wallet_mod, "get_db_session", sess)
    monkeypatch.setattr(us_mod, "get_db_session", sess)
    s = session_factory()
    s.add(UserDB(id=GUEST, app_account_token=GUEST_TOKEN, free_credits=0, plot_credits=0))
    s.add(AuthIdentityDB(user_id=GUEST, provider="device", provider_subject="FC6E3372-TEST"))
    s.add(UserDB(id=ACCOUNT, app_account_token=ACCOUNT_TOKEN, free_credits=5, plot_credits=0))
    s.add(AuthIdentityDB(user_id=ACCOUNT, provider="google", provider_subject="1181999"))
    s.commit()
    s.close()
    return client, session_factory


def auth(uid, token):
    return {"Authorization": f"Bearer {create_access_token(user_id=uid, app_account_token=token)}"}


def buy(client, pki, uid, token, tx, product="bhumitra.plots.50", app_token=None):
    jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra", "productId": product, "transactionId": tx,
        "originalTransactionId": tx, "purchaseDate": 1770000000000, "environment": "Sandbox",
        "appAccountToken": app_token or token,
    })
    return client.post("/api/v1/subscription/credits/purchase", headers=auth(uid, token),
                       json={"signed_transaction_jws": jws})


def merge(client):
    guest_jwt = create_access_token(user_id=GUEST, app_account_token=GUEST_TOKEN)
    return client.post("/api/v1/wallet/merge-guest", headers=auth(ACCOUNT, ACCOUNT_TOKEN),
                       json={"guest_token": guest_jwt})


def test_guest_purchase_then_sign_in_keeps_credits_and_allows_buying_again(pki_helper, env):
    client, sf = env
    assert buy(client, pki_helper, GUEST, GUEST_TOKEN, "tx_g1").json()["credits_granted"] == 50
    # Before the merge, the old purchase is foreign to the account (the old bug).
    assert buy(client, pki_helper, ACCOUNT, ACCOUNT_TOKEN, "tx_g1", app_token=GUEST_TOKEN).status_code == 409

    r = merge(client)
    assert r.status_code == 200, r.text
    assert r.json()["credits_moved"] == 50 and r.json()["purchases_moved"] == 1
    assert r.json()["current_balance"] == 55

    # Old purchase replayed after sign-in: recognised as ours, so the app can finish it.
    replay = buy(client, pki_helper, ACCOUNT, ACCOUNT_TOKEN, "tx_g1", app_token=GUEST_TOKEN)
    assert replay.status_code == 200 and replay.json()["already_processed"] is True
    assert replay.json()["current_balance"] == 55

    # Second, third purchase work and stack.
    for tx in ("tx_a2", "tx_a3"):
        assert buy(client, pki_helper, ACCOUNT, ACCOUNT_TOKEN, tx, product="bhumitra.plots.10").json()["credits_granted"] == 10
    s = sf()
    assert s.query(UserDB).filter_by(id=ACCOUNT).one().plot_credits == 70
    assert s.query(UserDB).filter_by(id=GUEST).one().plot_credits == 0
    assert s.query(UserDB).filter_by(id=GUEST).one().merged_into_user_id == ACCOUNT
    kinds = {e.entry_type for e in s.query(CreditLedgerDB).all()}
    assert {"MERGE_IN", "MERGE_OUT"} <= kinds
    s.close()


def test_merge_is_idempotent_and_picks_up_later_guest_purchases(pki_helper, env):
    client, sf = env
    buy(client, pki_helper, GUEST, GUEST_TOKEN, "tx_g1")
    assert merge(client).json()["credits_moved"] == 50
    assert merge(client).json()["credits_moved"] == 0          # nothing new
    buy(client, pki_helper, GUEST, GUEST_TOKEN, "tx_g2", product="bhumitra.plots.10")  # bought while signed out
    assert merge(client).json()["credits_moved"] == 10
    s = sf()
    assert s.query(UserDB).filter_by(id=ACCOUNT).one().plot_credits == 60
    assert s.query(ConsumableTransactionDB).filter_by(user_id=ACCOUNT).count() == 2
    s.close()


def test_guest_subscription_follows_the_account(pki_helper, env):
    client, sf = env
    s = sf()
    s.add(SubscriptionDB(user_id=GUEST, product_id="bhumitra.unlimited.monthly", plan="monthly",
                         original_transaction_id="sub_orig_1", app_account_token=GUEST_TOKEN,
                         status="active", environment="Sandbox"))
    s.commit()
    s.close()
    assert merge(client).json()["subscriptions_moved"] == 1
    # A renewal still carrying the guest token is accepted for the account (was 403).
    jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra", "productId": "bhumitra.unlimited.monthly",
        "transactionId": "sub_tx_2", "originalTransactionId": "sub_orig_1", "purchaseDate": 1770000000000,
        "expiresDate": 4102444800000, "environment": "Sandbox", "appAccountToken": GUEST_TOKEN,
        "type": "Auto-Renewable Subscription",
    })
    r = client.post("/api/v1/subscription/verify", headers=auth(ACCOUNT, ACCOUNT_TOKEN),
                    json={"signed_transaction_jws": jws, "app_account_token": GUEST_TOKEN})
    assert r.status_code == 200, r.text
    assert r.json()["is_premium"] is True


def test_merge_rejects_forged_or_foreign_wallets(pki_helper, env):
    client, sf = env
    h = auth(ACCOUNT, ACCOUNT_TOKEN)
    assert client.post("/api/v1/wallet/merge-guest", headers=h, json={"guest_token": "not-a-jwt-token"}).status_code == 400
    # Another signed-in account is never merged.
    s = sf()
    s.add(UserDB(id="usr_other", app_account_token="other"))
    s.add(AuthIdentityDB(user_id="usr_other", provider="apple", provider_subject="000111"))
    s.commit()
    s.close()
    other = create_access_token(user_id="usr_other")
    assert client.post("/api/v1/wallet/merge-guest", headers=h, json={"guest_token": other}).status_code == 409
    # A guest can't pull another guest's wallet into itself.
    assert client.post("/api/v1/wallet/merge-guest", headers=auth(GUEST, GUEST_TOKEN),
                       json={"guest_token": create_access_token(user_id=ACCOUNT)}).status_code == 403
    # Unauthenticated.
    assert client.post("/api/v1/wallet/merge-guest", json={"guest_token": other}).status_code in (401, 403)
