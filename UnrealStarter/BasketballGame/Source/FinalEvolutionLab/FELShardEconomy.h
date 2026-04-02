// Copyright (c) Final Evolution Lab.
// Shard economy system — dual currency, earning, spending, store.
// Phase 5: Shard Economy

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELShardEconomy.generated.h"

/* ─────────────────────────  ENUMS  ──────────────────────────────── */

UENUM(BlueprintType)
enum class EShardType : uint8
{
	EvolutionShard   UMETA(DisplayName = "Evolution Shard (Free)"),
	PremiumShard     UMETA(DisplayName = "Premium Shard (Paid)")
};

UENUM(BlueprintType)
enum class EShardSource : uint8
{
	GameWin          UMETA(DisplayName = "Game Win"),
	GameLose         UMETA(DisplayName = "Game Loss"),
	MVP              UMETA(DisplayName = "MVP Award"),
	PerfectGame      UMETA(DisplayName = "Perfect Game"),
	ComebackWin      UMETA(DisplayName = "Comeback Win"),
	WorkoutComplete  UMETA(DisplayName = "Workout Complete"),
	PerfectForm      UMETA(DisplayName = "Perfect Form"),
	PersonalRecord   UMETA(DisplayName = "New Personal Record"),
	StreakBonus      UMETA(DisplayName = "Streak Bonus"),
	DailyChallenge   UMETA(DisplayName = "Daily Challenge"),
	WeeklyChallenge  UMETA(DisplayName = "Weekly Challenge"),
	CreatorChallenge UMETA(DisplayName = "Creator Challenge"),
	SpecialEvent     UMETA(DisplayName = "Special Event"),
	Achievement      UMETA(DisplayName = "Achievement"),
	DailyLogin       UMETA(DisplayName = "Daily Login"),
	Purchase         UMETA(DisplayName = "IAP Purchase"),
	Refund           UMETA(DisplayName = "Refund"),
	AdminGrant       UMETA(DisplayName = "Admin Grant")
};

UENUM(BlueprintType)
enum class EStoreCategory : uint8
{
	Cosmetics       UMETA(DisplayName = "Cosmetics"),
	Environments    UMETA(DisplayName = "Environments"),
	Gameplay        UMETA(DisplayName = "Gameplay"),
	Customization   UMETA(DisplayName = "Customization"),
	Progression     UMETA(DisplayName = "Progression")
};

UENUM(BlueprintType)
enum class EItemRarity : uint8
{
	Common      UMETA(DisplayName = "Common"),
	Rare        UMETA(DisplayName = "Rare"),
	Epic        UMETA(DisplayName = "Epic"),
	Legendary   UMETA(DisplayName = "Legendary")
};

/* ─────────────────────────  CONSTANTS  ──────────────────────────── */

namespace FELShardConstants
{
	// ── Gameplay Rewards ──
	constexpr int32 GAME_WIN_SHARDS         = 75;
	constexpr int32 GAME_LOSE_SHARDS        = 35;
	constexpr int32 MVP_BONUS_SHARDS        = 25;
	constexpr int32 PERFECT_GAME_SHARDS     = 50;
	constexpr int32 COMEBACK_WIN_SHARDS     = 75;

	// ── Exercise/Workout Rewards ──
	constexpr int32 WORKOUT_COMPLETE_SHARDS = 45;
	constexpr int32 PERFECT_FORM_SHARDS     = 20;
	constexpr int32 NEW_PR_SHARDS           = 40;
	constexpr int32 STREAK_BONUS_SHARDS     = 10;  // per day

	// ── Challenge Rewards ──
	constexpr int32 DAILY_CHALLENGE_SHARDS  = 50;
	constexpr int32 WEEKLY_CHALLENGE_SHARDS = 200;
	constexpr int32 CREATOR_CHALLENGE_MIN   = 100;
	constexpr int32 CREATOR_CHALLENGE_MAX   = 300;
	constexpr int32 SPECIAL_EVENT_MIN       = 500;

	// ── Achievement Rewards ──
	constexpr int32 FIRST_DUNK_SHARDS       = 100;
	constexpr int32 HUNDRED_GAMES_SHARDS    = 500;
	constexpr int32 FIFTY_WORKOUTS_SHARDS   = 300;
	constexpr int32 ALL_ENVIRONMENTS_SHARDS = 1000;

	// ── Daily Login Rewards ──
	constexpr int32 LOGIN_DAY1_SHARDS       = 10;
	constexpr int32 LOGIN_DAY2_SHARDS       = 20;
	constexpr int32 LOGIN_DAY3_SHARDS       = 30;
	constexpr int32 LOGIN_DAY7_SHARDS       = 100;

	// ── Premium Shard Pricing (USD) ──
	constexpr float PREMIUM_TIER1_PRICE     = 0.99f;   // 100 shards
	constexpr int32 PREMIUM_TIER1_AMOUNT    = 100;
	constexpr float PREMIUM_TIER2_PRICE     = 4.99f;   // 600 shards (20% bonus)
	constexpr int32 PREMIUM_TIER2_AMOUNT    = 600;
	constexpr float PREMIUM_TIER3_PRICE     = 9.99f;   // 1300 shards (30% bonus)
	constexpr int32 PREMIUM_TIER3_AMOUNT    = 1300;
	constexpr float PREMIUM_TIER4_PRICE     = 19.99f;  // 3000 shards (50% bonus)
	constexpr int32 PREMIUM_TIER4_AMOUNT    = 3000;

	// ── Earning Rate Targets (shards/hour) ──
	constexpr int32 CASUAL_EARN_RATE        = 150;
	constexpr int32 AVERAGE_EARN_RATE       = 300;
	constexpr int32 HARDCORE_EARN_RATE      = 650;
}

/* ─────────────────────────  DATA STRUCTS  ───────────────────────── */

USTRUCT(BlueprintType)
struct FShardTransaction
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	FDateTime Timestamp;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	int32 Amount = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	EShardType Type = EShardType::EvolutionShard;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	EShardSource Source = EShardSource::GameWin;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	FString Description;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	FString TransactionID;
};

USTRUCT(BlueprintType)
struct FShardWallet
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	FString UserID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	int32 EvolutionShards = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	int32 PremiumShards = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	int32 LifetimeEarned = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	int32 LifetimeSpent = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	TArray<FShardTransaction> History;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	int32 ConsecutiveLoginDays = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	FDateTime LastLoginDate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	int32 CurrentStreak = 0;
};

USTRUCT(BlueprintType)
struct FStoreItem
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	FString ItemID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	FString ItemName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	FString Description;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	EStoreCategory Category = EStoreCategory::Cosmetics;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	EItemRarity Rarity = EItemRarity::Common;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	int32 PriceEvolutionShards = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	int32 PricePremiumShards = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	FString ThumbnailPath;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	FString AssetPath;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	bool bLimitedTime = false;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	FDateTime AvailableUntil;
};

USTRUCT(BlueprintType)
struct FDailyLoginReward
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	int32 Day = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	int32 ShardReward = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	FString BonusItemID;  // Optional bonus item

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shards")
	bool bClaimed = false;
};

/* ─────────────────────  DELEGATES  ──────────────────────────────── */

DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FOnShardsEarned, EShardType, Type, int32, Amount, EShardSource, Source);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnShardsSpent, EShardType, Type, int32, Amount);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnBalanceChanged, int32, EvolutionShards, int32, PremiumShards);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnStoreItemPurchased, const FStoreItem&, Item);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnDailyLoginRewardClaimed, const FDailyLoginReward&, Reward);

/* ─────────────────────  SUBSYSTEM  ──────────────────────────────── */

UCLASS()
class FINALEVOLUTIONLAB_API UFELShardEconomy : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// ── Wallet ─────────────────────────────────────────────────────
	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	FShardWallet GetWallet(const FString& UserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	int32 GetEvolutionShards(const FString& UserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	int32 GetPremiumShards(const FString& UserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	int32 GetTotalShards(const FString& UserID) const;

	// ── Earning ────────────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Shards")
	int32 AwardShards(const FString& UserID, int32 Amount, EShardSource Source, const FString& Description = TEXT(""));

	UFUNCTION(BlueprintCallable, Category = "FEL|Shards")
	int32 AwardPremiumShards(const FString& UserID, int32 Amount, const FString& Description = TEXT(""));

	UFUNCTION(BlueprintCallable, Category = "FEL|Shards")
	int32 AwardGameReward(const FString& UserID, bool bWon, bool bMVP, bool bPerfect, bool bComeback);

	UFUNCTION(BlueprintCallable, Category = "FEL|Shards")
	int32 AwardWorkoutReward(const FString& UserID, bool bPerfectForm, bool bNewPR, int32 StreakDays);

	// ── Spending ───────────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Shards")
	bool SpendShards(const FString& UserID, int32 Amount, EShardType PreferredType, const FString& Description = TEXT(""));

	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	bool CanAfford(const FString& UserID, int32 EvolutionCost, int32 PremiumCost = 0) const;

	// ── Store ──────────────────────────────────────────────────────
	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	TArray<FStoreItem> GetStoreItems(EStoreCategory Category) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	TArray<FStoreItem> GetAllStoreItems() const;

	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	TArray<FStoreItem> GetFeaturedItems() const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Shards")
	bool PurchaseItem(const FString& UserID, const FString& ItemID, EShardType PaymentType);

	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	TArray<FString> GetOwnedItems(const FString& UserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	bool OwnsItem(const FString& UserID, const FString& ItemID) const;

	// ── Daily Login ─────────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Shards")
	FDailyLoginReward ClaimDailyLogin(const FString& UserID);

	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	int32 GetLoginStreak(const FString& UserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	TArray<FDailyLoginReward> GetLoginRewardSchedule() const;

	// ── Premium Purchase (IAP) ──────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Shards")
	bool ProcessPremiumPurchase(const FString& UserID, int32 Tier, const FString& ReceiptData);

	// ── Transaction History ────────────────────────────────────────
	UFUNCTION(BlueprintPure, Category = "FEL|Shards")
	TArray<FShardTransaction> GetTransactionHistory(const FString& UserID, int32 MaxEntries = 50) const;

	// ── Delegates ──────────────────────────────────────────────────
	UPROPERTY(BlueprintAssignable, Category = "FEL|Shards")
	FOnShardsEarned OnShardsEarned;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Shards")
	FOnShardsSpent OnShardsSpent;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Shards")
	FOnBalanceChanged OnBalanceChanged;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Shards")
	FOnStoreItemPurchased OnItemPurchased;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Shards")
	FOnDailyLoginRewardClaimed OnLoginRewardClaimed;

private:
	/** Wallets keyed by UserID. */
	TMap<FString, FShardWallet> Wallets;

	/** Store catalog. */
	TArray<FStoreItem> StoreCatalog;

	/** Owned items per user. */
	TMap<FString, TArray<FString>> OwnedItems;

	/** Login reward schedule (7 days). */
	TArray<FDailyLoginReward> LoginSchedule;

	void InitializeStoreCatalog();
	void InitializeLoginSchedule();
	FShardWallet& GetOrCreateWallet(const FString& UserID);
	FString GenerateTransactionID() const;
	void RecordTransaction(FShardWallet& Wallet, int32 Amount, EShardType Type, EShardSource Source, const FString& Desc);
};
