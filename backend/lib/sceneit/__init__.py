"""
Who Scene It — modular visual-puzzle trivia engine (Nexus philosophy).

Module seams (each independently swappable):
  - rounds.RoundModule / ROUND_REGISTRY  — round types drop in without touching the core loop
  - scoring.ScoringModule / BuzzRiskScoring — buzz-in risk scoring (countdown + wrong-buzz penalty)
  - content.SceneContentModule / LocalDatadumpProvider — content source (local original-asset datadump;
    documented seam for a future licensed-data provider)
  - cards.CardProvider — Creator Card data model + deep-dive payloads

IP CONSTRAINT: all content is original, in-universe (Final Evolution universe).
No real films, actors, posters, or IMDb-derived data. Every content item carries
`source` + `license` fields so QA can verify shippability.
"""
from .scoring import ScoringModule, BuzzRiskScoring, ScoringConfig  # noqa: F401
from .content import SceneContentModule, LocalDatadumpProvider, get_default_provider  # noqa: F401
from .rounds import RoundModule, ROUND_REGISTRY, register_round, get_round, list_rounds  # noqa: F401
from .cards import CardProvider, creator_card_for  # noqa: F401
