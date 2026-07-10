"""
card_effects.py — Map Creator Card IDs to runtime modifier values.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Dict, List

@dataclass
class CardModifiers:
    jump_multiplier: float = 1.0      # >1 = higher jump
    speed_multiplier: float = 1.0     # >1 = faster
    execution_bonus: float = 0.0      # additive to execution_quality
    stamina_multiplier: float = 1.0
    description: str = ""

# Master mapping: card_id -> modifiers
CARD_EFFECT_MAP: Dict[str, CardModifiers] = {
    "speed_demon":     CardModifiers(speed_multiplier=1.20, description="+20% speed"),
    "iron_grip":       CardModifiers(execution_bonus=0.08, description="+8% execution"),
    "sky_walker":      CardModifiers(jump_multiplier=1.25, description="+25% jump"),
    "endurance_king":  CardModifiers(stamina_multiplier=1.30, description="+30% stamina"),
    "clutch_gene":     CardModifiers(execution_bonus=0.12, description="+12% execution under pressure"),
    "beast_mode":      CardModifiers(speed_multiplier=1.10, jump_multiplier=1.10, description="+10% speed/jump"),
    # default for unknown cards
    "default":         CardModifiers(description="No special modifiers"),
}

def compute_loadout_modifiers(loadout: list) -> dict:
    """Aggregate runtime modifiers for a list of Creator Cards."""
    result = CardModifiers()
    for card in loadout:
        card_id = card.get("id", "")
        fx = CARD_EFFECT_MAP.get(card_id, CARD_EFFECT_MAP["default"])
        result.jump_multiplier *= fx.jump_multiplier
        result.speed_multiplier *= fx.speed_multiplier
        result.execution_bonus += fx.execution_bonus
        result.stamina_multiplier *= fx.stamina_multiplier
    # Cap multipliers
    result.jump_multiplier = min(result.jump_multiplier, 2.0)
    result.speed_multiplier = min(result.speed_multiplier, 2.0)
    result.execution_bonus = min(result.execution_bonus, 0.30)
    return {
        "jump_multiplier": round(result.jump_multiplier, 3),
        "speed_multiplier": round(result.speed_multiplier, 3),
        "execution_bonus": round(result.execution_bonus, 3),
        "stamina_multiplier": round(result.stamina_multiplier, 3),
    }
