"""Creator Cards marketplace service."""
from __future__ import annotations

from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.economy_transaction import EconomyTransaction
from app.models.marketplace import CreatorCard, InventoryItem, Purchase
from app.models.wallet import Wallet
from app.schemas.marketplace_schemas import CreatorCardOut, PurchaseOut
from app.services.payment_service import payment_service
from app.utils.creator_cards import get_seeded_creator_card, get_seeded_creator_cards


class MarketplaceService:
    """Marketplace read and purchase operations."""

    async def list_cards(self, *, db: AsyncSession | None = None, category: str | None = None) -> list[CreatorCardOut]:
        """Return active cards from DB or the seeded fallback catalog."""

        if db is not None:
            try:
                query = select(CreatorCard).where(CreatorCard.is_active.is_(True))
                if category:
                    query = query.where(CreatorCard.sport == category)
                result = await db.execute(query)
                rows = result.scalars().all()
                if rows:
                    return [self._card_out(row) for row in rows]
            except Exception:
                await db.rollback()
        return get_seeded_creator_cards(category)

    async def get_card(self, *, db: AsyncSession | None = None, card_id: str) -> CreatorCardOut:
        """Return one card by id."""

        if db is not None:
            try:
                result = await db.execute(select(CreatorCard).where(CreatorCard.id == card_id))
                row = result.scalar_one_or_none()
                if row is not None:
                    return self._card_out(row)
            except Exception:
                await db.rollback()
        card = get_seeded_creator_card(card_id)
        if card is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Card not found")
        return card

    async def purchase_with_shards(
        self,
        *,
        db: AsyncSession | None,
        user_id: str,
        item_id: str,
    ) -> PurchaseOut:
        """Atomic shard purchase when DB is available; offline completed receipt otherwise."""

        card = await self.get_card(db=db, card_id=item_id)
        if db is None:
            return self._offline_shard_purchase(user_id=user_id, card=card)

        try:
            wallet_result = await db.execute(select(Wallet).where(Wallet.user_id == user_id).with_for_update())
            wallet = wallet_result.scalar_one_or_none()
            if wallet is None:
                return self._offline_shard_purchase(user_id=user_id, card=card)
            if wallet.shards < card.price_shards:
                raise HTTPException(
                    status_code=status.HTTP_402_PAYMENT_REQUIRED,
                    detail=f"Insufficient shards. Need {card.price_shards}, have {wallet.shards}",
                )

            owned = await db.execute(
                select(InventoryItem).where(
                    InventoryItem.user_id == user_id,
                    InventoryItem.card_id == item_id,
                )
            )
            if owned.scalar_one_or_none() is not None:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Item already owned")

            wallet.shards -= card.price_shards
            purchase_id = str(uuid4())
            db.add(
                InventoryItem(
                    user_id=user_id,
                    card_id=item_id,
                    acquired_via="purchase_shards",
                )
            )
            db.add(
                Purchase(
                    id=purchase_id,
                    user_id=user_id,
                    item_type="creator_card",
                    item_id=item_id,
                    provider="shards",
                    amount_shards=card.price_shards,
                    amount_cents=0,
                    currency="SHARDS",
                    status="completed",
                    metadata_json={"item_name": card.name},
                )
            )
            db.add(
                EconomyTransaction(
                    user_id=user_id,
                    session_id=None,
                    transaction_type="purchase",
                    currency="shards",
                    amount=-card.price_shards,
                    metadata_json={"item_id": item_id, "item_name": card.name},
                )
            )
            await db.commit()
            return PurchaseOut(
                purchase_id=purchase_id,
                item_type="creator_card",
                item_id=item_id,
                item_name=card.name,
                payment_method="shards",
                amount_shards=card.price_shards,
                status="completed",
                wallet_after={"shards": wallet.shards, "xp": wallet.xp},
            )
        except HTTPException:
            raise
        except Exception:
            await db.rollback()
            return self._offline_shard_purchase(user_id=user_id, card=card)

    async def purchase_with_stripe(
        self,
        *,
        db: AsyncSession | None,
        user_id: str,
        item_id: str,
        return_url: str | None = None,
        cancel_url: str | None = None,
    ) -> PurchaseOut:
        """Create a Stripe/offline payment intent for a Creator Card."""

        card = await self.get_card(db=db, card_id=item_id)
        amount_cents = int(round(card.price_usd * 100))
        intent = await payment_service.create_payment_intent(
            amount_cents=amount_cents,
            metadata={"user_id": user_id, "item_type": "creator_card", "item_id": item_id},
        )
        checkout = await payment_service.create_checkout_session(
            price_cents=amount_cents,
            item_name=card.name,
            success_url=return_url or "http://localhost:3000/marketplace?success=1",
            cancel_url=cancel_url or "http://localhost:3000/marketplace?cancelled=1",
            metadata={"user_id": user_id, "item_type": "creator_card", "item_id": item_id},
        )

        purchase_id = str(uuid4())
        if db is not None:
            try:
                db.add(
                    Purchase(
                        id=purchase_id,
                        user_id=user_id,
                        item_type="creator_card",
                        item_id=item_id,
                        provider="stripe",
                        provider_reference=intent.payment_intent_id,
                        amount_cents=amount_cents,
                        currency="USD",
                        status="pending",
                        metadata_json={"item_name": card.name, "checkout_session": checkout["session_id"]},
                    )
                )
                await db.commit()
            except Exception:
                await db.rollback()

        return PurchaseOut(
            purchase_id=purchase_id,
            item_type="creator_card",
            item_id=item_id,
            item_name=card.name,
            payment_method="stripe",
            amount_usd=card.price_usd,
            status="pending",
            stripe_client_secret=intent.client_secret,
            checkout_url=checkout.get("url"),
        )

    @staticmethod
    def _offline_shard_purchase(*, user_id: str, card: CreatorCardOut) -> PurchaseOut:
        purchase_id = f"purchase_offline_{uuid4().hex[:16]}"
        return PurchaseOut(
            purchase_id=purchase_id,
            item_type="creator_card",
            item_id=card.id,
            item_name=card.name,
            payment_method="shards",
            amount_shards=card.price_shards,
            status="completed",
            wallet_after={"shards": "offline", "user_id": user_id},
        )

    @staticmethod
    def _card_out(row: CreatorCard) -> CreatorCardOut:
        traits = row.traits or {}
        return CreatorCardOut(
            id=row.id,
            creator_id=row.creator_id,
            name=row.name,
            title=row.title,
            sport=row.sport,
            tier=row.tier,
            style=row.style,
            rarity=row.rarity,
            image_url=row.image_url or "",
            bio=row.bio,
            signature_moves=list(traits.get("signature_moves", [])),
            challenges=list(traits.get("challenges", [])),
            stats=dict(traits.get("stats", {})),
            price_shards=row.price_shards,
            price_usd=row.price_usd,
            price=row.price_usd,
            for_sale=row.is_active,
        )


marketplace_service = MarketplaceService()

