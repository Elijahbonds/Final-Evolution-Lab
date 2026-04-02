// Copyright (c) Final Evolution Lab.
// Family sharing management system — invitations, profiles, parental controls.
// Phase 5: Family Sharing

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELSubscription.h"
#include "FELFamilyManager.generated.h"

/* ─────────────────────────  ENUMS  ──────────────────────────────── */

UENUM(BlueprintType)
enum class ESubscriptionTier : uint8
{
	FreeTrial    UMETA(DisplayName = "Free Trial (72h)"),
	Individual   UMETA(DisplayName = "Individual ($6/week)"),
	Family2      UMETA(DisplayName = "Family 2 ($10/week)"),
	Family5Plus  UMETA(DisplayName = "Family 5+ ($19.99/week)")
};

UENUM(BlueprintType)
enum class EFamilyRole : uint8
{
	Owner    UMETA(DisplayName = "Owner"),
	Adult    UMETA(DisplayName = "Adult"),
	Child    UMETA(DisplayName = "Child")
};

UENUM(BlueprintType)
enum class EInviteStatus : uint8
{
	Pending    UMETA(DisplayName = "Pending"),
	Accepted   UMETA(DisplayName = "Accepted"),
	Declined   UMETA(DisplayName = "Declined"),
	Expired    UMETA(DisplayName = "Expired"),
	Revoked    UMETA(DisplayName = "Revoked")
};

/* ─────────────────────────  CONSTANTS  ──────────────────────────── */

namespace FELFamilyConstants
{
	constexpr float INDIVIDUAL_PRICE_USD  = 6.00f;
	constexpr float FAMILY2_PRICE_USD     = 10.00f;
	constexpr float FAMILY5PLUS_PRICE_USD = 19.99f;

	constexpr int32 FAMILY2_MAX_MEMBERS    = 2;
	constexpr int32 FAMILY5PLUS_MAX_MEMBERS = 10;  // Soft cap at 10

	constexpr int32 INVITE_EXPIRY_DAYS = 7;

	/** Stripe product IDs. */
	static const TCHAR* STRIPE_INDIVIDUAL_PRICE  = TEXT("price_FEL_6USD_Weekly");
	static const TCHAR* STRIPE_FAMILY2_PRICE     = TEXT("price_FEL_10USD_Family2");
	static const TCHAR* STRIPE_FAMILY5PLUS_PRICE = TEXT("price_FEL_1999USD_Family5");
}

/* ─────────────────────────  DATA STRUCTS  ───────────────────────── */

USTRUCT(BlueprintType)
struct FParentalControls
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	bool bContentFiltering = true;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	bool bPlayTimeLimits = true;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	int32 DailyPlayTimeLimitMinutes = 120;  // 2 hours

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	bool bRequirePurchaseApproval = true;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	bool bMultiplayerRestrictions = false;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString AllowedPlayTimeStart = TEXT("08:00");

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString AllowedPlayTimeEnd = TEXT("21:00");
};

USTRUCT(BlueprintType)
struct FFamilyMember
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString UserID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString DisplayName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	EFamilyRole Role = EFamilyRole::Adult;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	int32 Age = 18;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FDateTime JoinedDate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FDateTime LastPlayedDate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	float TotalPlayTimeHours = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	int32 WorkoutsCompleted = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FParentalControls ParentalControls;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString AvatarURL;
};

USTRUCT(BlueprintType)
struct FFamilyInvitation
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString InviteCode;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString FamilyID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString InvitedByUserID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString InviteeEmail;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	EInviteStatus Status = EInviteStatus::Pending;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FDateTime CreatedDate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FDateTime ExpiryDate;
};

USTRUCT(BlueprintType)
struct FFamilyGroup
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString FamilyID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString OwnerUserID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	ESubscriptionTier Tier = ESubscriptionTier::Individual;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	TArray<FFamilyMember> Members;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	TArray<FFamilyInvitation> PendingInvites;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	int32 MaxMembers = 1;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	float WeeklyPrice = FELFamilyConstants::INDIVIDUAL_PRICE_USD;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FDateTime CreatedDate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FDateTime NextBillingDate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	bool bAutoRenew = true;
};

USTRUCT(BlueprintType)
struct FFamilyLeaderboardEntry
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString UserID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	FString DisplayName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	int32 WeeklyPoints = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	int32 WorkoutsThisWeek = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	int32 GamesWonThisWeek = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Family")
	int32 Rank = 0;
};

/* ─────────────────────  DELEGATES  ──────────────────────────────── */

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFamilyCreated, const FFamilyGroup&, Family);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnMemberJoined, const FFamilyMember&, Member);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnMemberRemoved, const FString&, UserID);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnTierChanged, ESubscriptionTier, OldTier, ESubscriptionTier, NewTier);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnInviteSent, const FFamilyInvitation&, Invite);

/* ─────────────────────  SUBSYSTEM  ──────────────────────────────── */

UCLASS()
class FINALEVOLUTIONLAB_API UFELFamilyManager : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// ── Family Creation & Management ───────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Family")
	FString CreateFamily(const FString& OwnerUserID, const FString& OwnerName, ESubscriptionTier Tier);

	UFUNCTION(BlueprintCallable, Category = "FEL|Family")
	bool DisbandFamily(const FString& FamilyID, const FString& RequestingUserID);

	UFUNCTION(BlueprintPure, Category = "FEL|Family")
	FFamilyGroup GetFamily(const FString& FamilyID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Family")
	FFamilyGroup GetFamilyForUser(const FString& UserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Family")
	bool IsInFamily(const FString& UserID) const;

	// ── Tier Management ───────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Family")
	bool UpgradeTier(const FString& FamilyID, ESubscriptionTier NewTier);

	UFUNCTION(BlueprintCallable, Category = "FEL|Family")
	bool DowngradeTier(const FString& FamilyID, ESubscriptionTier NewTier);

	UFUNCTION(BlueprintPure, Category = "FEL|Family")
	float GetTierPrice(ESubscriptionTier Tier) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Family")
	int32 GetTierMaxMembers(ESubscriptionTier Tier) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Family")
	float GetSavingsPerWeek(ESubscriptionTier Tier) const;

	// ── Member Management ─────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Family")
	bool AddMember(const FString& FamilyID, const FFamilyMember& Member);

	UFUNCTION(BlueprintCallable, Category = "FEL|Family")
	bool RemoveMember(const FString& FamilyID, const FString& UserID, const FString& RequestingUserID);

	UFUNCTION(BlueprintPure, Category = "FEL|Family")
	TArray<FFamilyMember> GetMembers(const FString& FamilyID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Family")
	int32 GetMemberCount(const FString& FamilyID) const;

	// ── Invitations ───────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Family")
	FFamilyInvitation GenerateInviteCode(const FString& FamilyID, const FString& InviterUserID);

	UFUNCTION(BlueprintCallable, Category = "FEL|Family")
	bool SendInviteByEmail(const FString& FamilyID, const FString& InviterUserID, const FString& Email);

	UFUNCTION(BlueprintCallable, Category = "FEL|Family")
	bool AcceptInvite(const FString& InviteCode, const FString& UserID, const FString& DisplayName);

	UFUNCTION(BlueprintCallable, Category = "FEL|Family")
	bool DeclineInvite(const FString& InviteCode);

	UFUNCTION(BlueprintCallable, Category = "FEL|Family")
	bool RevokeInvite(const FString& InviteCode, const FString& RequestingUserID);

	// ── Parental Controls ─────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Family")
	bool SetParentalControls(const FString& FamilyID, const FString& ChildUserID,
		const FParentalControls& Controls, const FString& RequestingUserID);

	UFUNCTION(BlueprintPure, Category = "FEL|Family")
	FParentalControls GetParentalControls(const FString& FamilyID, const FString& ChildUserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Family")
	bool IsWithinAllowedPlayTime(const FString& FamilyID, const FString& ChildUserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Family")
	bool HasExceededDailyLimit(const FString& FamilyID, const FString& ChildUserID) const;

	// ── Leaderboard ───────────────────────────────────────────────
	UFUNCTION(BlueprintPure, Category = "FEL|Family")
	TArray<FFamilyLeaderboardEntry> GetFamilyLeaderboard(const FString& FamilyID) const;

	// ── Delegates ──────────────────────────────────────────────────
	UPROPERTY(BlueprintAssignable, Category = "FEL|Family")
	FOnFamilyCreated OnFamilyCreated;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Family")
	FOnMemberJoined OnMemberJoined;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Family")
	FOnMemberRemoved OnMemberRemoved;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Family")
	FOnTierChanged OnTierChanged;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Family")
	FOnInviteSent OnInviteSent;

private:
	/** All family groups keyed by FamilyID. */
	TMap<FString, FFamilyGroup> Families;

	/** User-to-family mapping for quick lookup. */
	TMap<FString, FString> UserToFamily;

	/** Invite code to family mapping. */
	TMap<FString, FFamilyInvitation> InviteCodeMap;

	FString GenerateFamilyID() const;
	FString GenerateInviteCodeString() const;
	void UpdateTierSettings(FFamilyGroup& Family);
	bool IsOwnerOrAdult(const FFamilyGroup& Family, const FString& UserID) const;
};
