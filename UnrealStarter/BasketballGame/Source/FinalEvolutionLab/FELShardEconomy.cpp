// Copyright (c) Final Evolution Lab.
// Shard economy system implementation.
// Phase 5: Shard Economy

#include "FELShardEconomy.h"
#include "Misc/Guid.h"

void UFELShardEconomy::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	InitializeStoreCatalog();
	InitializeLoginSchedule();
	UE_LOG(LogTemp, Log, TEXT("[FEL-Shards] Shard economy initialized. Store items: %d"), StoreCatalog.Num());
}

void UFELShardEconomy::Deinitialize()
{
	Wallets.Empty();
	OwnedItems.Empty();
	Super::Deinitialize();
}

/* ─────────────  Wallet  ─────────────────────────────────────────── */

FShardWallet UFELShardEconomy::GetWallet(const FString& UserID) const
{
	if (const auto* W = Wallets.Find(UserID)) return *W;
	FShardWallet Empty; Empty.UserID = UserID;
	return Empty;
}

int32 UFELShardEconomy::GetEvolutionShards(const FString& UserID) const
{
	if (const auto* W = Wallets.Find(UserID)) return W->EvolutionShards;
	return 0;
}

int32 UFELShardEconomy::GetPremiumShards(const FString& UserID) const
{
	if (const auto* W = Wallets.Find(UserID)) return W->PremiumShards;
	return 0;
}

int32 UFELShardEconomy::GetTotalShards(const FString& UserID) const
{
	return GetEvolutionShards(UserID) + GetPremiumShards(UserID);
}

/* ─────────────  Earning  ────────────────────────────────────────── */

int32 UFELShardEconomy::AwardShards(const FString& UserID, int32 Amount, EShardSource Source, const FString& Description)
{
	if (Amount <= 0) return 0;

	FShardWallet& Wallet = GetOrCreateWallet(UserID);
	Wallet.EvolutionShards += Amount;
	Wallet.LifetimeEarned += Amount;

	RecordTransaction(Wallet, Amount, EShardType::EvolutionShard, Source, Description);

	OnShardsEarned.Broadcast(EShardType::EvolutionShard, Amount, Source);
	OnBalanceChanged.Broadcast(Wallet.EvolutionShards, Wallet.PremiumShards);

	UE_LOG(LogTemp, Log, TEXT("[FEL-Shards] %s earned %d evolution shards (%s). Balance: %d"),
		*UserID, Amount, *Description, Wallet.EvolutionShards);
	return Amount;
}

int32 UFELShardEconomy::AwardPremiumShards(const FString& UserID, int32 Amount, const FString& Description)
{
	if (Amount <= 0) return 0;

	FShardWallet& Wallet = GetOrCreateWallet(UserID);
	Wallet.PremiumShards += Amount;

	RecordTransaction(Wallet, Amount, EShardType::PremiumShard, EShardSource::Purchase, Description);

	OnShardsEarned.Broadcast(EShardType::PremiumShard, Amount, EShardSource::Purchase);
	OnBalanceChanged.Broadcast(Wallet.EvolutionShards, Wallet.PremiumShards);

	return Amount;
}

int32 UFELShardEconomy::AwardGameReward(const FString& UserID, bool bWon, bool bMVP, bool bPerfect, bool bComeback)
{
	int32 Total = 0;

	if (bWon)
	{
		Total += AwardShards(UserID, FELShardConstants::GAME_WIN_SHARDS, EShardSource::GameWin, TEXT("Game Win"));
	}
	else
	{
		Total += AwardShards(UserID, FELShardConstants::GAME_LOSE_SHARDS, EShardSource::GameLose, TEXT("Game Participation"));
	}

	if (bMVP)
	{
		Total += AwardShards(UserID, FELShardConstants::MVP_BONUS_SHARDS, EShardSource::MVP, TEXT("MVP Bonus"));
	}
	if (bPerfect)
	{
		Total += AwardShards(UserID, FELShardConstants::PERFECT_GAME_SHARDS, EShardSource::PerfectGame, TEXT("Perfect Game"));
	}
	if (bComeback)
	{
		Total += AwardShards(UserID, FELShardConstants::COMEBACK_WIN_SHARDS, EShardSource::ComebackWin, TEXT("Comeback Win"));
	}

	return Total;
}

int32 UFELShardEconomy::AwardWorkoutReward(const FString& UserID, bool bPerfectForm, bool bNewPR, int32 StreakDays)
{
	int32 Total = AwardShards(UserID, FELShardConstants::WORKOUT_COMPLETE_SHARDS,
		EShardSource::WorkoutComplete, TEXT("Workout Complete"));

	if (bPerfectForm)
	{
		Total += AwardShards(UserID, FELShardConstants::PERFECT_FORM_SHARDS,
			EShardSource::PerfectForm, TEXT("Perfect Form Bonus"));
	}
	if (bNewPR)
	{
		Total += AwardShards(UserID, FELShardConstants::NEW_PR_SHARDS,
			EShardSource::PersonalRecord, TEXT("New Personal Record"));
	}
	if (StreakDays > 0)
	{
		int32 StreakReward = FELShardConstants::STREAK_BONUS_SHARDS * StreakDays;
		Total += AwardShards(UserID, StreakReward,
			EShardSource::StreakBonus, FString::Printf(TEXT("%d-day streak bonus"), StreakDays));
	}

	return Total;
}

/* ─────────────  Spending  ───────────────────────────────────────── */

bool UFELShardEconomy::SpendShards(const FString& UserID, int32 Amount, EShardType PreferredType, const FString& Description)
{
	FShardWallet& Wallet = GetOrCreateWallet(UserID);

	if (PreferredType == EShardType::PremiumShard)
	{
		if (Wallet.PremiumShards >= Amount)
		{
			Wallet.PremiumShards -= Amount;
			Wallet.LifetimeSpent += Amount;
			RecordTransaction(Wallet, -Amount, EShardType::PremiumShard, EShardSource::Purchase, Description);
			OnShardsSpent.Broadcast(EShardType::PremiumShard, Amount);
			OnBalanceChanged.Broadcast(Wallet.EvolutionShards, Wallet.PremiumShards);
			return true;
		}
	}

	if (Wallet.EvolutionShards >= Amount)
	{
		Wallet.EvolutionShards -= Amount;
		Wallet.LifetimeSpent += Amount;
		RecordTransaction(Wallet, -Amount, EShardType::EvolutionShard, EShardSource::Purchase, Description);
		OnShardsSpent.Broadcast(EShardType::EvolutionShard, Amount);
		OnBalanceChanged.Broadcast(Wallet.EvolutionShards, Wallet.PremiumShards);
		return true;
	}

	// Try combining both currencies
	int32 Total = Wallet.EvolutionShards + Wallet.PremiumShards;
	if (Total >= Amount)
	{
		int32 FromEvolution = FMath::Min(Wallet.EvolutionShards, Amount);
		int32 FromPremium = Amount - FromEvolution;
		Wallet.EvolutionShards -= FromEvolution;
		Wallet.PremiumShards -= FromPremium;
		Wallet.LifetimeSpent += Amount;
		RecordTransaction(Wallet, -Amount, EShardType::EvolutionShard, EShardSource::Purchase, Description);
		OnShardsSpent.Broadcast(EShardType::EvolutionShard, Amount);
		OnBalanceChanged.Broadcast(Wallet.EvolutionShards, Wallet.PremiumShards);
		return true;
	}

	UE_LOG(LogTemp, Warning, TEXT("[FEL-Shards] %s insufficient shards: need %d, have %d"),
		*UserID, Amount, Total);
	return false;
}

bool UFELShardEconomy::CanAfford(const FString& UserID, int32 EvolutionCost, int32 PremiumCost) const
{
	int32 EvShards = GetEvolutionShards(UserID);
	int32 PrShards = GetPremiumShards(UserID);
	return EvShards >= EvolutionCost && PrShards >= PremiumCost;
}

/* ─────────────  Store  ──────────────────────────────────────────── */

TArray<FStoreItem> UFELShardEconomy::GetStoreItems(EStoreCategory Category) const
{
	TArray<FStoreItem> Filtered;
	for (const FStoreItem& Item : StoreCatalog)
	{
		if (Item.Category == Category) Filtered.Add(Item);
	}
	return Filtered;
}

TArray<FStoreItem> UFELShardEconomy::GetAllStoreItems() const
{
	return StoreCatalog;
}

TArray<FStoreItem> UFELShardEconomy::GetFeaturedItems() const
{
	TArray<FStoreItem> Featured;
	for (const FStoreItem& Item : StoreCatalog)
	{
		if (Item.Rarity >= EItemRarity::Epic) Featured.Add(Item);
	}
	return Featured;
}

bool UFELShardEconomy::PurchaseItem(const FString& UserID, const FString& ItemID, EShardType PaymentType)
{
	// Already owned?
	if (OwnsItem(UserID, ItemID))
	{
		UE_LOG(LogTemp, Warning, TEXT("[FEL-Shards] %s already owns item %s"), *UserID, *ItemID);
		return false;
	}

	// Find item
	const FStoreItem* Item = nullptr;
	for (const FStoreItem& SI : StoreCatalog)
	{
		if (SI.ItemID == ItemID) { Item = &SI; break; }
	}
	if (!Item) return false;

	int32 Price = (PaymentType == EShardType::PremiumShard && Item->PricePremiumShards > 0)
		? Item->PricePremiumShards : Item->PriceEvolutionShards;

	if (!SpendShards(UserID, Price, PaymentType, FString::Printf(TEXT("Purchase: %s"), *Item->ItemName)))
	{
		return false;
	}

	// Add to owned items
	if (!OwnedItems.Contains(UserID))
	{
		OwnedItems.Add(UserID, TArray<FString>());
	}
	OwnedItems[UserID].Add(ItemID);

	OnItemPurchased.Broadcast(*Item);
	UE_LOG(LogTemp, Log, TEXT("[FEL-Shards] %s purchased '%s' for %d shards"),
		*UserID, *Item->ItemName, Price);
	return true;
}

TArray<FString> UFELShardEconomy::GetOwnedItems(const FString& UserID) const
{
	if (const auto* Items = OwnedItems.Find(UserID)) return *Items;
	return TArray<FString>();
}

bool UFELShardEconomy::OwnsItem(const FString& UserID, const FString& ItemID) const
{
	if (const auto* Items = OwnedItems.Find(UserID))
	{
		return Items->Contains(ItemID);
	}
	return false;
}

/* ─────────────  Daily Login  ────────────────────────────────────── */

FDailyLoginReward UFELShardEconomy::ClaimDailyLogin(const FString& UserID)
{
	FShardWallet& Wallet = GetOrCreateWallet(UserID);
	FDateTime Today = FDateTime::Today();

	// Check if already claimed today
	if (Wallet.LastLoginDate.GetDate() == Today.GetDate())
	{
		FDailyLoginReward Empty;
		Empty.bClaimed = true;
		return Empty;
	}

	// Check streak continuity
	FDateTime Yesterday = Today - FTimespan::FromDays(1);
	if (Wallet.LastLoginDate.GetDate() == Yesterday.GetDate())
	{
		Wallet.ConsecutiveLoginDays++;
	}
	else
	{
		Wallet.ConsecutiveLoginDays = 1;
	}

	Wallet.LastLoginDate = FDateTime::UtcNow();

	// Determine reward (cycle through 7-day schedule)
	int32 DayIndex = (Wallet.ConsecutiveLoginDays - 1) % LoginSchedule.Num();
	FDailyLoginReward Reward = LoginSchedule[DayIndex];
	Reward.bClaimed = true;

	AwardShards(UserID, Reward.ShardReward, EShardSource::DailyLogin,
		FString::Printf(TEXT("Day %d login reward"), Wallet.ConsecutiveLoginDays));

	OnLoginRewardClaimed.Broadcast(Reward);
	return Reward;
}

int32 UFELShardEconomy::GetLoginStreak(const FString& UserID) const
{
	if (const auto* W = Wallets.Find(UserID)) return W->ConsecutiveLoginDays;
	return 0;
}

TArray<FDailyLoginReward> UFELShardEconomy::GetLoginRewardSchedule() const
{
	return LoginSchedule;
}

/* ─────────────  Premium Purchase  ───────────────────────────────── */

bool UFELShardEconomy::ProcessPremiumPurchase(const FString& UserID, int32 Tier, const FString& ReceiptData)
{
	// In production: validate receipt with Apple/Google/Stripe server

	int32 Amount = 0;
	switch (Tier)
	{
	case 1: Amount = FELShardConstants::PREMIUM_TIER1_AMOUNT; break;
	case 2: Amount = FELShardConstants::PREMIUM_TIER2_AMOUNT; break;
	case 3: Amount = FELShardConstants::PREMIUM_TIER3_AMOUNT; break;
	case 4: Amount = FELShardConstants::PREMIUM_TIER4_AMOUNT; break;
	default:
		UE_LOG(LogTemp, Error, TEXT("[FEL-Shards] Invalid premium tier: %d"), Tier);
		return false;
	}

	AwardPremiumShards(UserID, Amount, FString::Printf(TEXT("Premium Tier %d purchase"), Tier));
	UE_LOG(LogTemp, Log, TEXT("[FEL-Shards] %s purchased %d premium shards (Tier %d)"),
		*UserID, Amount, Tier);
	return true;
}

/* ─────────────  Transaction History  ────────────────────────────── */

TArray<FShardTransaction> UFELShardEconomy::GetTransactionHistory(const FString& UserID, int32 MaxEntries) const
{
	if (const auto* W = Wallets.Find(UserID))
	{
		if (W->History.Num() <= MaxEntries) return W->History;

		TArray<FShardTransaction> Recent;
		int32 Start = W->History.Num() - MaxEntries;
		for (int32 i = Start; i < W->History.Num(); ++i)
		{
			Recent.Add(W->History[i]);
		}
		return Recent;
	}
	return TArray<FShardTransaction>();
}

/* ─────────────  Internal  ───────────────────────────────────────── */

void UFELShardEconomy::InitializeStoreCatalog()
{
	// ── Cosmetics ──
	auto AddItem = [this](const FString& ID, const FString& Name, const FString& Desc,
		EStoreCategory Cat, EItemRarity Rarity, int32 EvPrice, int32 PrPrice)
	{
		FStoreItem Item;
		Item.ItemID = ID; Item.ItemName = Name; Item.Description = Desc;
		Item.Category = Cat; Item.Rarity = Rarity;
		Item.PriceEvolutionShards = EvPrice; Item.PricePremiumShards = PrPrice;
		StoreCatalog.Add(Item);
	};

	// Cosmetics
	AddItem(TEXT("skin_fire_jersey"), TEXT("Fire Jersey"), TEXT("Blazing orange jersey with flame effects"),
		EStoreCategory::Cosmetics, EItemRarity::Rare, 1200, 600);
	AddItem(TEXT("skin_neon_jersey"), TEXT("Neon Glow Jersey"), TEXT("Cyberpunk-style neon jersey"),
		EStoreCategory::Cosmetics, EItemRarity::Epic, 2500, 1250);
	AddItem(TEXT("skin_gold_jersey"), TEXT("Golden Champion Jersey"), TEXT("Legendary golden jersey for champions"),
		EStoreCategory::Cosmetics, EItemRarity::Legendary, 5000, 2500);
	AddItem(TEXT("shoes_air_max"), TEXT("Air Evolution Shoes"), TEXT("Custom shoes with +2 visual jump effect"),
		EStoreCategory::Cosmetics, EItemRarity::Rare, 1500, 750);
	AddItem(TEXT("shoes_lightning"), TEXT("Lightning Bolt Shoes"), TEXT("Electric trail shoes"),
		EStoreCategory::Cosmetics, EItemRarity::Epic, 2000, 1000);
	AddItem(TEXT("emote_dunk_celebrate"), TEXT("Dunk Celebration"), TEXT("Epic dunk celebration emote"),
		EStoreCategory::Cosmetics, EItemRarity::Common, 500, 250);
	AddItem(TEXT("emote_fire_dance"), TEXT("Fire Dance"), TEXT("Legendary fire dance emote"),
		EStoreCategory::Cosmetics, EItemRarity::Legendary, 3000, 1500);
	AddItem(TEXT("headband_cyber"), TEXT("Cyber Headband"), TEXT("Futuristic headband accessory"),
		EStoreCategory::Cosmetics, EItemRarity::Common, 600, 300);

	// Environments
	AddItem(TEXT("env_night_court"), TEXT("Night Court"), TEXT("Play under the stars"),
		EStoreCategory::Environments, EItemRarity::Rare, 2000, 1000);
	AddItem(TEXT("env_sunset_beach"), TEXT("Sunset Beach Court"), TEXT("Golden hour at Venice Beach"),
		EStoreCategory::Environments, EItemRarity::Epic, 3000, 1500);
	AddItem(TEXT("env_rain_court"), TEXT("Rainy Court"), TEXT("Play in the rain with puddle reflections"),
		EStoreCategory::Environments, EItemRarity::Rare, 1500, 750);
	AddItem(TEXT("env_snow_court"), TEXT("Snow Court"), TEXT("Winter wonderland basketball"),
		EStoreCategory::Environments, EItemRarity::Epic, 2500, 1250);

	// Gameplay
	AddItem(TEXT("game_xp_boost_2x"), TEXT("2x XP Boost (1hr)"), TEXT("Double XP for 1 hour"),
		EStoreCategory::Gameplay, EItemRarity::Common, 500, 250);
	AddItem(TEXT("game_skill_boost"), TEXT("Skill Boost (30min)"), TEXT("Temporary accuracy bonus"),
		EStoreCategory::Gameplay, EItemRarity::Rare, 800, 400);

	// Customization
	AddItem(TEXT("ball_chrome"), TEXT("Chrome Basketball"), TEXT("Shiny chrome basketball"),
		EStoreCategory::Customization, EItemRarity::Common, 400, 200);
	AddItem(TEXT("ball_galaxy"), TEXT("Galaxy Basketball"), TEXT("Space-themed basketball with stars"),
		EStoreCategory::Customization, EItemRarity::Epic, 1800, 900);
	AddItem(TEXT("hud_cyber"), TEXT("Cyber HUD Theme"), TEXT("Cyberpunk-style UI theme"),
		EStoreCategory::Customization, EItemRarity::Rare, 1000, 500);

	// Progression
	AddItem(TEXT("prog_xp_boost_week"), TEXT("Weekly XP Boost"), TEXT("25% more XP for a week"),
		EStoreCategory::Progression, EItemRarity::Common, 300, 150);
	AddItem(TEXT("prog_workout_unlock"), TEXT("Workout Fast Track"), TEXT("Unlock next workout program"),
		EStoreCategory::Progression, EItemRarity::Rare, 500, 250);
}

void UFELShardEconomy::InitializeLoginSchedule()
{
	LoginSchedule.Empty();

	auto AddDay = [this](int32 Day, int32 Shards)
	{
		FDailyLoginReward R;
		R.Day = Day;
		R.ShardReward = Shards;
		LoginSchedule.Add(R);
	};

	AddDay(1, FELShardConstants::LOGIN_DAY1_SHARDS);   // 10
	AddDay(2, FELShardConstants::LOGIN_DAY2_SHARDS);   // 20
	AddDay(3, FELShardConstants::LOGIN_DAY3_SHARDS);   // 30
	AddDay(4, 40);
	AddDay(5, 50);
	AddDay(6, 75);
	AddDay(7, FELShardConstants::LOGIN_DAY7_SHARDS);   // 100
}

FShardWallet& UFELShardEconomy::GetOrCreateWallet(const FString& UserID)
{
	if (!Wallets.Contains(UserID))
	{
		FShardWallet NewWallet;
		NewWallet.UserID = UserID;
		Wallets.Add(UserID, NewWallet);
	}
	return Wallets[UserID];
}

FString UFELShardEconomy::GenerateTransactionID() const
{
	return FString::Printf(TEXT("TXN-%s"), *FGuid::NewGuid().ToString(EGuidFormats::Short));
}

void UFELShardEconomy::RecordTransaction(FShardWallet& Wallet, int32 Amount,
	EShardType Type, EShardSource Source, const FString& Desc)
{
	FShardTransaction TX;
	TX.TransactionID = GenerateTransactionID();
	TX.Timestamp = FDateTime::UtcNow();
	TX.Amount = Amount;
	TX.Type = Type;
	TX.Source = Source;
	TX.Description = Desc.IsEmpty() ? UEnum::GetValueAsString(Source) : Desc;

	Wallet.History.Add(TX);

	// Keep history manageable
	if (Wallet.History.Num() > 500)
	{
		Wallet.History.RemoveAt(0, Wallet.History.Num() - 500);
	}
}
