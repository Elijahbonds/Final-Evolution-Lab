from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List, Optional

import pytest
from starlette.requests import Request

import server


@dataclass
class UpdateResult:
    modified_count: int = 1
    upserted_id: Optional[str] = None


class FakeCollection:
    def __init__(self, docs: Optional[List[Dict[str, Any]]] = None):
        self.docs = list(docs or [])
        self.inserted: List[Dict[str, Any]] = []
        self.updates: List[tuple[Dict[str, Any], Dict[str, Any], bool]] = []

    async def find_one(self, filt: Dict[str, Any], projection: Optional[Dict[str, Any]] = None):
        for doc in self.docs:
            if all(doc.get(k) == v for k, v in filt.items() if not isinstance(v, dict)):
                return dict(doc)
        return None

    async def insert_one(self, doc: Dict[str, Any]):
        self.inserted.append(dict(doc))
        return type("InsertResult", (), {"inserted_id": doc.get("id")})()

    async def update_one(self, filt: Dict[str, Any], update: Dict[str, Any], upsert: bool = False):
        self.updates.append((dict(filt), dict(update), upsert))
        for doc in self.docs:
            if not all(_matches_filter(doc, k, v) for k, v in filt.items()):
                continue
            for key, val in update.get("$inc", {}).items():
                doc[key] = doc.get(key, 0) + val
            for key, val in update.get("$set", {}).items():
                doc[key] = val
            return UpdateResult(modified_count=1)
        if upsert:
            self.docs.append(dict(update.get("$setOnInsert", filt)))
            return UpdateResult(modified_count=0, upserted_id=self.docs[-1].get("id"))
        return UpdateResult(modified_count=0)


def _matches_filter(doc: Dict[str, Any], key: str, expected: Any) -> bool:
    actual = doc.get(key)
    if isinstance(expected, dict) and "$gte" in expected:
        return actual is not None and actual >= expected["$gte"]
    return actual == expected


class FakeDb:
    def __init__(self, user_doc: Optional[Dict[str, Any]] = None):
        self.users = FakeCollection([user_doc] if user_doc else [])
        self.orders = FakeCollection()
        self.user_cards = FakeCollection()
        self.creator_cards = FakeCollection()


def _request(headers: Optional[List[tuple[bytes, bytes]]] = None) -> Request:
    return Request({"type": "http", "method": "POST", "path": "/", "headers": headers or []})


def _user(shards: int = 1000) -> server.User:
    return server.User(
        user_id="test-user",
        email="test@example.com",
        name="Test User",
        coins=shards,
    )


def test_seeded_creator_cards_are_marketplace_priced() -> None:
    cards = [server._creator_card_response(card) for card in server.get_seeded_creator_cards()]

    assert {card["id"] for card in cards} >= {"card_elijah", "card_amir", "card_eric"}
    assert all(card["price_usd"] > 0 for card in cards)
    assert all(card["price_shards"] > 0 for card in cards)
    assert next(card for card in cards if card["id"] == "card_eric")["price_shards"] == 500


@pytest.mark.asyncio
async def test_marketplace_stripe_purchase_returns_checkout_contract(monkeypatch: pytest.MonkeyPatch) -> None:
    fake_db = FakeDb({"user_id": "test-user", "coins": 1000})
    monkeypatch.setattr(server, "db", fake_db)

    data = await server.purchase_marketplace_item(
        _request(),
        {
            "item_type": "creator_card",
            "item_id": "card_elijah",
            "payment_method": "stripe",
            "return_url": "http://localhost:3000/cards",
        },
        _user(),
    )

    assert data["status"] == "pending"
    assert data["payment_method"] == "stripe"
    assert data["stripe_client_secret"].startswith("pi_offline_")
    assert "checkout_session=cs_offline_" in data["checkout_url"]
    assert fake_db.orders.inserted[0]["item_type"] == "card"


@pytest.mark.asyncio
async def test_marketplace_shard_purchase_deducts_and_grants_card(monkeypatch: pytest.MonkeyPatch) -> None:
    fake_db = FakeDb({"user_id": "test-user", "shards": 1000, "coins": 1000})
    monkeypatch.setattr(server, "db", fake_db)

    data = await server.purchase_marketplace_item(
        _request(),
        {"item_type": "creator_card", "item_id": "card_eric", "payment_method": "shards"},
        _user(),
    )

    assert data["status"] == "completed"
    assert data["amount_shards"] == 500
    assert fake_db.users.docs[0]["shards"] == 500
    assert fake_db.users.docs[0]["coins"] == 500
    assert fake_db.user_cards.updates[0][0] == {"user_id": "test-user", "card_id": "card_eric"}
