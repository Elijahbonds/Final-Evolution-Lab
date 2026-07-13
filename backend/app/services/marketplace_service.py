"""Creator Cards marketplace service."""
from __future__ import annotations

from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.economy_transaction import EconomyTransaction
from app.models.marketplace import CreatorCard, InventoryItem, Listing, Order, Purchase, Rating
from app.models.wallet import Wallet
from app.schemas.marketplace_schemas import (
    CreatorCardOut,
    ListingOut,
    OrderOut,
    OrderRequest,
    PurchaseOut,
    RatingIn,
    RatingOut,
)
from app.services.payment_service import payment_service
from app.services.payout_service import compute_order_split, payout_service
from app.utils.creator_cards import get_seeded_creator_card, get_seeded_creator_cards

# Curation tier boosts applied to the listing rank score (spec: rating & ranking —
# low-rated content is de-ranked, curated/featured content surfaces first).
CURATION_TIER_BOOST: dict[str, float] = {"featured": 2.0, "curated": 1.0, "open": 0.0}


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

    # ------------------------------------------------------------------
    # Nexus marketplace completion: listings, idempotent orders, ratings
    # ------------------------------------------------------------------

    async def ensure_card_row(self, *, db: AsyncSession, card_id: str) -> CreatorCard:
        """Return the DB card row, importing it from the seeded catalog if missing."""

        result = await db.execute(select(CreatorCard).where(CreatorCard.id == card_id))
        row = result.scalar_one_or_none()
        if row is not None:
            return row
        seeded = get_seeded_creator_card(card_id)
        if seeded is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Card not found")
        row = CreatorCard(
            id=seeded.id,
            creator_id=seeded.creator_id,
            name=seeded.name,
            title=seeded.title,
            sport=seeded.sport,
            tier=seeded.tier,
            style=seeded.style,
            rarity=seeded.rarity,
            price_shards=seeded.price_shards,
            price_usd=seeded.price_usd,
            image_url=seeded.image_url,
            bio=seeded.bio,
            traits={
                "signature_moves": seeded.signature_moves,
                "challenges": seeded.challenges,
                "stats": seeded.stats,
            },
            is_active=seeded.for_sale,
        )
        db.add(row)
        await db.flush()
        return row

    async def ensure_listing(self, *, db: AsyncSession, card_id: str) -> Listing:
        """Return the card's listing, creating an 'open' tier one on first touch."""

        result = await db.execute(select(Listing).where(Listing.card_id == card_id))
        listing = result.scalar_one_or_none()
        if listing is None:
            await self.ensure_card_row(db=db, card_id=card_id)
            listing = Listing(card_id=card_id)
            db.add(listing)
            await db.flush()
        return listing

    async def list_listings(self, *, db: AsyncSession, category: str | None = None) -> list[ListingOut]:
        """Active listings joined with their cards, best rank first."""

        query = (
            select(Listing, CreatorCard)
            .join(CreatorCard, CreatorCard.id == Listing.card_id)
            .where(Listing.is_active.is_(True), CreatorCard.is_active.is_(True))
            .order_by(Listing.rank_score.desc(), Listing.sales_count.desc())
        )
        if category:
            query = query.where(CreatorCard.sport == category)
        result = await db.execute(query)
        return [self._listing_out(listing, card) for listing, card in result.all()]

    async def create_order(self, *, db: AsyncSession, buyer_id: str, request: OrderRequest) -> OrderOut:
        """Validated, idempotent purchase: funds -> ledger -> inventory -> listing stats.

        Replaying the same (buyer, idempotency_key) returns the original order
        without moving any balance a second time.
        """

        existing = await self._find_order(db=db, buyer_id=buyer_id, idempotency_key=request.idempotency_key)
        if existing is not None:
            return self._order_out(existing, replay=True)

        card = await self.ensure_card_row(db=db, card_id=request.card_id)
        if not card.is_active:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Card is not for sale")
        listing = await self.ensure_listing(db=db, card_id=card.id)
        if not listing.is_active:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Listing is not active")

        owned = await db.execute(
            select(InventoryItem).where(
                InventoryItem.user_id == buyer_id, InventoryItem.card_id == card.id
            )
        )
        if owned.scalar_one_or_none() is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Item already owned")

        if request.currency == "shards":
            order = await self._create_shard_order(
                db=db, buyer_id=buyer_id, card=card, listing=listing, request=request
            )
        else:
            order = await self._create_usd_order(
                db=db, buyer_id=buyer_id, card=card, listing=listing, request=request
            )

        try:
            await db.commit()
        except IntegrityError:
            # Concurrent replay of the same idempotency key: return the winner.
            await db.rollback()
            existing = await self._find_order(
                db=db, buyer_id=buyer_id, idempotency_key=request.idempotency_key
            )
            if existing is not None:
                return self._order_out(existing, replay=True)
            raise
        return self._order_out(order, wallet_after=getattr(order, "_wallet_after", None))

    async def _create_shard_order(
        self, *, db: AsyncSession, buyer_id: str, card: CreatorCard, listing: Listing, request: OrderRequest
    ) -> Order:
        """Soft-currency order: completes atomically, never touches payout accrual."""

        wallet_result = await db.execute(
            select(Wallet).where(Wallet.user_id == buyer_id).with_for_update()
        )
        wallet = wallet_result.scalar_one_or_none()
        if wallet is None or wallet.shards < card.price_shards:
            have = wallet.shards if wallet is not None else 0
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail=f"Insufficient shards. Need {card.price_shards}, have {have}",
            )

        wallet.shards -= card.price_shards
        order = Order(
            buyer_id=buyer_id,
            card_id=card.id,
            listing_id=listing.id,
            idempotency_key=request.idempotency_key,
            currency="SHARDS",
            amount_shards=card.price_shards,
            status="completed",
            provider="shards",
            metadata_json={"card_name": card.name},
        )
        db.add(order)
        db.add(InventoryItem(user_id=buyer_id, card_id=card.id, acquired_via="order_shards"))
        db.add(
            EconomyTransaction(
                user_id=buyer_id,
                session_id=None,
                transaction_type="purchase",
                currency="shards",
                amount=-card.price_shards,
                metadata_json={"card_id": card.id, "card_name": card.name, "order": True},
            )
        )
        listing.sales_count += 1
        card.total_sold += 1
        self._rerank(listing)
        order._wallet_after = {"shards": wallet.shards, "xp": wallet.xp}  # type: ignore[attr-defined]
        return order

    async def _create_usd_order(
        self, *, db: AsyncSession, buyer_id: str, card: CreatorCard, listing: Listing, request: OrderRequest
    ) -> Order:
        """Hard-currency order: pending until the (stubbed) provider confirms."""

        gross_cents = int(round(card.price_usd * 100))
        split = compute_order_split(gross_cents)
        intent = await payment_service.create_payment_intent(
            amount_cents=gross_cents,
            metadata={"user_id": buyer_id, "item_type": "creator_card", "item_id": card.id},
        )
        order = Order(
            buyer_id=buyer_id,
            card_id=card.id,
            listing_id=listing.id,
            idempotency_key=request.idempotency_key,
            currency="USD",
            gross_cents=split.gross_cents,
            store_fee_cents=split.store_fee_cents,
            net_cents=split.net_cents,
            creator_share_cents=split.creator_share_cents,
            platform_share_cents=split.platform_share_cents,
            status="pending",
            provider="stripe",
            provider_reference=intent.payment_intent_id,
            metadata_json={"card_name": card.name, "creator_id": card.creator_id},
        )
        db.add(order)
        return order

    async def complete_usd_order(self, *, db: AsyncSession, order_id: str) -> OrderOut:
        """Confirm a pending hard-currency order: inventory + ledger + payout accrual.

        Idempotent: completing an already-completed order is a no-op replay.
        Called by the payment webhook path (or tests) once the provider confirms.
        """

        result = await db.execute(select(Order).where(Order.id == order_id).with_for_update())
        order = result.scalar_one_or_none()
        if order is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
        if order.status == "completed":
            return self._order_out(order, replay=True)
        if order.currency != "USD" or order.status != "pending":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Order not completable from status={order.status} currency={order.currency}",
            )

        card = await self.ensure_card_row(db=db, card_id=order.card_id)
        listing = await self.ensure_listing(db=db, card_id=order.card_id)
        order.status = "completed"
        db.add(InventoryItem(user_id=order.buyer_id, card_id=order.card_id, acquired_via="order_usd"))
        db.add(
            EconomyTransaction(
                user_id=order.buyer_id,
                session_id=None,
                transaction_type="purchase",
                currency="usd_cents",
                amount=-order.gross_cents,
                metadata_json={"card_id": order.card_id, "order_id": order.id},
            )
        )
        listing.sales_count += 1
        card.total_sold += 1
        self._rerank(listing)
        await payout_service.accrue(
            db=db, creator_id=card.creator_id, amount_cents=order.creator_share_cents
        )
        await db.commit()
        return self._order_out(order)

    async def rate_card(
        self, *, db: AsyncSession, reviewer_id: str, card_id: str, rating: RatingIn
    ) -> RatingOut:
        """Record one star rating per buyer per card, then re-rank the listing."""

        card = await self.ensure_card_row(db=db, card_id=card_id)
        owned = await db.execute(
            select(InventoryItem).where(
                InventoryItem.user_id == reviewer_id, InventoryItem.card_id == card.id
            )
        )
        if owned.scalar_one_or_none() is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only owners can rate a card — purchase it first",
            )
        duplicate = await db.execute(
            select(Rating).where(
                Rating.reviewer_id == reviewer_id,
                Rating.subject_type == "card",
                Rating.subject_id == card.id,
            )
        )
        if duplicate.scalar_one_or_none() is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="You already rated this card"
            )

        row = Rating(
            subject_type="card",
            subject_id=card.id,
            reviewer_id=reviewer_id,
            stars=rating.stars,
            comment=rating.comment,
        )
        db.add(row)
        listing = await self.ensure_listing(db=db, card_id=card.id)
        # Incremental average keeps re-rank O(1) per rating.
        total = listing.rating_avg * listing.rating_count + rating.stars
        listing.rating_count += 1
        listing.rating_avg = round(total / listing.rating_count, 4)
        self._rerank(listing)
        try:
            await db.commit()
        except IntegrityError as exc:
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="You already rated this card"
            ) from exc
        return RatingOut(
            rating_id=row.id,
            card_id=card.id,
            reviewer_id=reviewer_id,
            stars=row.stars,
            comment=row.comment,
            listing=self._listing_out(listing, None),
        )

    async def list_card_ratings(self, *, db: AsyncSession, card_id: str) -> list[RatingOut]:
        """All ratings for one card, newest first."""

        result = await db.execute(
            select(Rating)
            .where(Rating.subject_type == "card", Rating.subject_id == card_id)
            .order_by(Rating.created_at.desc())
        )
        return [
            RatingOut(
                rating_id=r.id,
                card_id=r.subject_id,
                reviewer_id=r.reviewer_id,
                stars=r.stars,
                comment=r.comment,
            )
            for r in result.scalars().all()
        ]

    async def _find_order(
        self, *, db: AsyncSession, buyer_id: str, idempotency_key: str
    ) -> Order | None:
        result = await db.execute(
            select(Order).where(
                Order.buyer_id == buyer_id, Order.idempotency_key == idempotency_key
            )
        )
        return result.scalar_one_or_none()

    @staticmethod
    def _rerank(listing: Listing) -> None:
        """Deterministic rank: rating quality x sales traction + curation boost."""

        traction = 1.0 + min(listing.sales_count, 100) / 100.0
        boost = CURATION_TIER_BOOST.get(listing.curation_tier, 0.0)
        listing.rank_score = round(listing.rating_avg * traction + boost, 4)

    @staticmethod
    def _listing_out(listing: Listing, card: CreatorCard | None) -> ListingOut:
        return ListingOut(
            id=listing.id,
            card_id=listing.card_id,
            curation_tier=listing.curation_tier,
            rating_avg=listing.rating_avg,
            rating_count=listing.rating_count,
            sales_count=listing.sales_count,
            rank_score=listing.rank_score,
            is_active=listing.is_active,
            card=MarketplaceService._card_out(card) if card is not None else None,
        )

    @staticmethod
    def _order_out(order: Order, *, replay: bool = False, wallet_after: dict | None = None) -> OrderOut:
        return OrderOut(
            order_id=order.id,
            buyer_id=order.buyer_id,
            card_id=order.card_id,
            currency=order.currency,
            amount_shards=order.amount_shards,
            gross_cents=order.gross_cents,
            store_fee_cents=order.store_fee_cents,
            net_cents=order.net_cents,
            creator_share_cents=order.creator_share_cents,
            platform_share_cents=order.platform_share_cents,
            status=order.status,
            idempotent_replay=replay,
            wallet_after=wallet_after,
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

