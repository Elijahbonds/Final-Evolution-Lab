"""SQLAlchemy model registry."""
from app.models.base import Base
from app.models.economy_transaction import EconomyTransaction
from app.models.education import EducationAttempt, EducationProgress
from app.models.game_session import GameSession
from app.models.leaderboard import EducationCourse, Leaderboard, Referral
from app.models.marketplace import CreatorCard, InventoryItem, Listing, Order, Purchase, Rating
from app.models.match import Match, MatchEvent
from app.models.payout import PayoutAccount, PayoutSettlement
from app.models.prq_profile import PRQProfile
from app.models.sequencing import MasteryState, Recommendation
from app.models.user import User
from app.models.wallet import Wallet

__all__ = [
    "Base",
    "CreatorCard",
    "EconomyTransaction",
    "EducationAttempt",
    "EducationCourse",
    "EducationProgress",
    "GameSession",
    "InventoryItem",
    "Leaderboard",
    "Listing",
    "MasteryState",
    "Match",
    "MatchEvent",
    "Order",
    "PRQProfile",
    "PayoutAccount",
    "PayoutSettlement",
    "Purchase",
    "Rating",
    "Recommendation",
    "Referral",
    "User",
    "Wallet",
]
