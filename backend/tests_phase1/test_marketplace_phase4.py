"""Phase 4 marketplace/payment tests."""
from __future__ import annotations

from fastapi.testclient import TestClient

from app.auth.jwt_handler import create_access_token
from app.main import app


def _auth_headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {create_access_token('phase4-user')}"}


def test_marketplace_lists_seeded_creator_cards() -> None:
    client = TestClient(app)

    response = client.get("/api/marketplace/cards")

    assert response.status_code == 200
    cards = response.json()
    assert len(cards) >= 3
    assert {card["id"] for card in cards} >= {"card_elijah", "card_amir", "card_eric"}
    assert all("price_shards" in card and "price_usd" in card for card in cards)


def test_legacy_cards_alias_returns_same_shape() -> None:
    client = TestClient(app)

    response = client.get("/api/cards/card_elijah")

    assert response.status_code == 200
    assert response.json()["name"] == "Elijah Bonds"


def test_offline_payment_intent_is_stripe_shaped() -> None:
    client = TestClient(app)

    response = client.post(
        "/api/payments/payment-intent",
        json={"amount_cents": 999, "currency": "usd", "metadata": {"item_id": "card_elijah"}},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["payment_intent_id"].startswith("pi_offline_")
    assert data["client_secret"].startswith(data["payment_intent_id"])
    assert data["offline"] is True


def test_marketplace_stripe_purchase_returns_checkout_url() -> None:
    client = TestClient(app)

    response = client.post(
        "/api/marketplace/purchase",
        headers=_auth_headers(),
        json={
            "item_type": "creator_card",
            "item_id": "card_elijah",
            "payment_method": "stripe",
            "return_url": "http://localhost:3000/marketplace/success",
            "cancel_url": "http://localhost:3000/marketplace/cancel",
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["payment_method"] == "stripe"
    assert data["status"] == "pending"
    assert data["stripe_client_secret"].startswith("pi_offline_")
    assert "checkout_session=cs_offline_" in data["checkout_url"]


def test_marketplace_shard_purchase_offline_completion() -> None:
    client = TestClient(app)

    response = client.post(
        "/api/marketplace/purchase",
        headers=_auth_headers(),
        json={
            "item_type": "creator_card",
            "item_id": "card_eric",
            "payment_method": "shards",
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["payment_method"] == "shards"
    assert data["status"] == "completed"
    assert data["amount_shards"] == 500


def test_marketplace_shard_purchase_works_for_local_shell_without_bearer() -> None:
    client = TestClient(app)

    response = client.post(
        "/api/marketplace/purchase",
        json={
            "item_type": "creator_card",
            "item_id": "card_eric",
            "payment_method": "shards",
        },
    )

    assert response.status_code == 200
    assert response.json()["status"] == "completed"


def test_stripe_webhook_offline_parser() -> None:
    client = TestClient(app)

    response = client.post(
        "/api/webhooks/stripe",
        json={"type": "payment_intent.succeeded", "data": {"object": {"id": "pi_test"}}},
    )

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "event_type": "payment_intent.succeeded",
        "offline": True,
    }

