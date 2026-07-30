"""
lib.sports — per-sport adjudication rules for the shared ball-physics core.

Importing this package registers every implemented sport into
`lib.ball_physics.REGISTRY`. Soccer is the fully-implemented reference sport;
baseball/tennis/etc. plug in here later behind the same `AdjudicationRule` seam.
"""
from lib.ball_physics import REGISTRY
from lib.sports.soccer import SoccerRule

REGISTRY.register(SoccerRule())

__all__ = ["REGISTRY", "SoccerRule"]
