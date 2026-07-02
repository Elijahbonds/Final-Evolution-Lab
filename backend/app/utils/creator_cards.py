"""Seed creator card catalog used when the database is not available."""
from __future__ import annotations

from app.schemas.marketplace_schemas import CreatorCardOut


SEEDED_CREATOR_CARDS: list[CreatorCardOut] = [
    CreatorCardOut(
        id="card_elijah",
        creator_id="elijah_bonds",
        name="Elijah Bonds",
        title="Venice Beach Legend",
        sport="basketball",
        tier="featured",
        style="legendary",
        rarity="legendary",
        image_url="https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=600",
        bio="Professional basketball player. Explosive dunks and creative ball handling.",
        signature_moves=["Magic Reveal Dunk", "Venice Crossover", "Beach Body Fadeaway"],
        challenges=[
            {"name": "Dunk Master", "description": "Score 10 dunks", "reward": 500},
            {"name": "Crossover King", "description": "Complete 50 crossovers", "reward": 300},
        ],
        stats={"games": 1250, "wins": 890, "dunks": 3400},
        price_shards=2000,
        price_usd=99.99,
        price=99.99,
    ),
    CreatorCardOut(
        id="card_amir",
        creator_id="amir_smith",
        name="Amir Smith",
        title="Combat Specialist",
        sport="karate",
        tier="featured",
        style="holographic",
        rarity="epic",
        image_url="https://images.unsplash.com/photo-1555597673-b21d5c935865?w=600",
        bio="Karate champion. Hampton/Metz pro with international experience.",
        signature_moves=["Shadow Strike", "Iron Fist Combo", "Dragon Sweep"],
        challenges=[
            {"name": "Combo Master", "description": "Land 100 combos", "reward": 400},
            {"name": "Perfect Block", "description": "Block 50 attacks", "reward": 250},
        ],
        stats={"matches": 320, "wins": 285, "knockouts": 120},
        price_shards=1500,
        price_usd=79.99,
        price=79.99,
    ),
    CreatorCardOut(
        id="card_eric",
        creator_id="eric_nash",
        name="Eric Nash",
        title="Multi-Sport Coach",
        sport="training",
        tier="verified",
        style="premium",
        rarity="rare",
        image_url="https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=600",
        bio="Venice Beach coach specializing in athletic development.",
        signature_moves=["Foundation Flow", "Power Circuit", "Speed Series"],
        challenges=[
            {"name": "Train with Eric", "description": "Complete 5 workouts", "reward": 200},
            {"name": "Consistency King", "description": "7-day streak", "reward": 350},
        ],
        stats={"athletes_trained": 500, "sessions": 2500, "reviews": 480},
        price_shards=500,
        price_usd=49.99,
        price=49.99,
    ),
]


def get_seeded_creator_cards(category: str | None = None) -> list[CreatorCardOut]:
    """Return seeded cards, optionally filtered by sport/category."""

    if not category:
        return SEEDED_CREATOR_CARDS
    lowered = category.lower()
    return [card for card in SEEDED_CREATOR_CARDS if card.sport.lower() == lowered]


def get_seeded_creator_card(card_id: str) -> CreatorCardOut | None:
    """Return a seeded card by id."""

    return next((card for card in SEEDED_CREATOR_CARDS if card.id == card_id), None)

