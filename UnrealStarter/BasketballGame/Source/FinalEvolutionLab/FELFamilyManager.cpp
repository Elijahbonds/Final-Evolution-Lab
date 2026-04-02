// Copyright (c) Final Evolution Lab.
// Family sharing management implementation.
// Phase 5: Family Sharing

#include "FELFamilyManager.h"
#include "Misc/Guid.h"

void UFELFamilyManager::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	UE_LOG(LogTemp, Log, TEXT("[FEL-Family] Family manager subsystem initialized."));
}

void UFELFamilyManager::Deinitialize()
{
	Families.Empty();
	UserToFamily.Empty();
	InviteCodeMap.Empty();
	Super::Deinitialize();
}

/* ─────────────  Family Creation  ───────────────────────────────── */

FString UFELFamilyManager::CreateFamily(const FString& OwnerUserID, const FString& OwnerName, ESubscriptionTier Tier)
{
	// Owner can't already be in a family
	if (UserToFamily.Contains(OwnerUserID))
	{
		UE_LOG(LogTemp, Warning, TEXT("[FEL-Family] User %s already in a family."), *OwnerUserID);
		return TEXT("");
	}

	FFamilyGroup Family;
	Family.FamilyID = GenerateFamilyID();
	Family.OwnerUserID = OwnerUserID;
	Family.Tier = Tier;
	Family.CreatedDate = FDateTime::UtcNow();
	Family.NextBillingDate = FDateTime::UtcNow() + FTimespan::FromDays(7);
	UpdateTierSettings(Family);

	// Add owner as first member
	FFamilyMember OwnerMember;
	OwnerMember.UserID = OwnerUserID;
	OwnerMember.DisplayName = OwnerName;
	OwnerMember.Role = EFamilyRole::Owner;
	OwnerMember.JoinedDate = FDateTime::UtcNow();
	Family.Members.Add(OwnerMember);

	Families.Add(Family.FamilyID, Family);
	UserToFamily.Add(OwnerUserID, Family.FamilyID);

	OnFamilyCreated.Broadcast(Family);

	UE_LOG(LogTemp, Log, TEXT("[FEL-Family] Family '%s' created by %s (Tier: %s)"),
		*Family.FamilyID, *OwnerUserID, *UEnum::GetValueAsString(Tier));
	return Family.FamilyID;
}

bool UFELFamilyManager::DisbandFamily(const FString& FamilyID, const FString& RequestingUserID)
{
	FFamilyGroup* Family = Families.Find(FamilyID);
	if (!Family || Family->OwnerUserID != RequestingUserID) return false;

	// Remove all member mappings
	for (const FFamilyMember& M : Family->Members)
	{
		UserToFamily.Remove(M.UserID);
	}

	// Remove invite mappings
	for (const FFamilyInvitation& Inv : Family->PendingInvites)
	{
		InviteCodeMap.Remove(Inv.InviteCode);
	}

	Families.Remove(FamilyID);
	UE_LOG(LogTemp, Log, TEXT("[FEL-Family] Family %s disbanded."), *FamilyID);
	return true;
}

FFamilyGroup UFELFamilyManager::GetFamily(const FString& FamilyID) const
{
	if (const auto* F = Families.Find(FamilyID)) return *F;
	return FFamilyGroup();
}

FFamilyGroup UFELFamilyManager::GetFamilyForUser(const FString& UserID) const
{
	if (const FString* FID = UserToFamily.Find(UserID))
	{
		if (const auto* F = Families.Find(*FID)) return *F;
	}
	return FFamilyGroup();
}

bool UFELFamilyManager::IsInFamily(const FString& UserID) const
{
	return UserToFamily.Contains(UserID);
}

/* ─────────────  Tier Management  ─────────────────────────────────── */

bool UFELFamilyManager::UpgradeTier(const FString& FamilyID, ESubscriptionTier NewTier)
{
	FFamilyGroup* Family = Families.Find(FamilyID);
	if (!Family) return false;
	if ((uint8)NewTier <= (uint8)Family->Tier) return false;

	ESubscriptionTier OldTier = Family->Tier;
	Family->Tier = NewTier;
	UpdateTierSettings(*Family);

	OnTierChanged.Broadcast(OldTier, NewTier);
	UE_LOG(LogTemp, Log, TEXT("[FEL-Family] Family %s upgraded to %s"),
		*FamilyID, *UEnum::GetValueAsString(NewTier));
	return true;
}

bool UFELFamilyManager::DowngradeTier(const FString& FamilyID, ESubscriptionTier NewTier)
{
	FFamilyGroup* Family = Families.Find(FamilyID);
	if (!Family) return false;

	int32 NewMax = GetTierMaxMembers(NewTier);
	if (Family->Members.Num() > NewMax)
	{
		UE_LOG(LogTemp, Warning, TEXT("[FEL-Family] Cannot downgrade: too many members (%d > %d)"),
			Family->Members.Num(), NewMax);
		return false;
	}

	ESubscriptionTier OldTier = Family->Tier;
	Family->Tier = NewTier;
	UpdateTierSettings(*Family);

	OnTierChanged.Broadcast(OldTier, NewTier);
	return true;
}

float UFELFamilyManager::GetTierPrice(ESubscriptionTier Tier) const
{
	switch (Tier)
	{
	case ESubscriptionTier::Individual:  return FELFamilyConstants::INDIVIDUAL_PRICE_USD;
	case ESubscriptionTier::Family2:     return FELFamilyConstants::FAMILY2_PRICE_USD;
	case ESubscriptionTier::Family5Plus: return FELFamilyConstants::FAMILY5PLUS_PRICE_USD;
	default: return 0.f;
	}
}

int32 UFELFamilyManager::GetTierMaxMembers(ESubscriptionTier Tier) const
{
	switch (Tier)
	{
	case ESubscriptionTier::FreeTrial:   return 1;
	case ESubscriptionTier::Individual:  return 1;
	case ESubscriptionTier::Family2:     return FELFamilyConstants::FAMILY2_MAX_MEMBERS;
	case ESubscriptionTier::Family5Plus: return FELFamilyConstants::FAMILY5PLUS_MAX_MEMBERS;
	default: return 1;
	}
}

float UFELFamilyManager::GetSavingsPerWeek(ESubscriptionTier Tier) const
{
	int32 Members = GetTierMaxMembers(Tier);
	float IndividualCost = Members * FELFamilyConstants::INDIVIDUAL_PRICE_USD;
	return IndividualCost - GetTierPrice(Tier);
}

/* ─────────────  Member Management  ───────────────────────────────── */

bool UFELFamilyManager::AddMember(const FString& FamilyID, const FFamilyMember& Member)
{
	FFamilyGroup* Family = Families.Find(FamilyID);
	if (!Family) return false;

	if (Family->Members.Num() >= Family->MaxMembers)
	{
		UE_LOG(LogTemp, Warning, TEXT("[FEL-Family] Family %s at capacity (%d/%d)"),
			*FamilyID, Family->Members.Num(), Family->MaxMembers);
		return false;
	}

	if (UserToFamily.Contains(Member.UserID))
	{
		UE_LOG(LogTemp, Warning, TEXT("[FEL-Family] User %s already in a family."), *Member.UserID);
		return false;
	}

	FFamilyMember NewMember = Member;
	NewMember.JoinedDate = FDateTime::UtcNow();

	// Auto-set child role for under-13
	if (NewMember.Age < 13)
	{
		NewMember.Role = EFamilyRole::Child;
		NewMember.ParentalControls.bContentFiltering = true;
		NewMember.ParentalControls.bPlayTimeLimits = true;
		NewMember.ParentalControls.bRequirePurchaseApproval = true;
	}

	Family->Members.Add(NewMember);
	UserToFamily.Add(NewMember.UserID, FamilyID);

	OnMemberJoined.Broadcast(NewMember);

	UE_LOG(LogTemp, Log, TEXT("[FEL-Family] %s joined family %s (%d/%d)"),
		*NewMember.DisplayName, *FamilyID, Family->Members.Num(), Family->MaxMembers);
	return true;
}

bool UFELFamilyManager::RemoveMember(const FString& FamilyID, const FString& UserID, const FString& RequestingUserID)
{
	FFamilyGroup* Family = Families.Find(FamilyID);
	if (!Family) return false;

	// Only owner/adult can remove members, or member can remove themselves
	if (RequestingUserID != UserID && !IsOwnerOrAdult(*Family, RequestingUserID)) return false;

	// Can't remove the owner
	if (UserID == Family->OwnerUserID) return false;

	Family->Members.RemoveAll([&UserID](const FFamilyMember& M) { return M.UserID == UserID; });
	UserToFamily.Remove(UserID);

	OnMemberRemoved.Broadcast(UserID);
	UE_LOG(LogTemp, Log, TEXT("[FEL-Family] %s removed from family %s"), *UserID, *FamilyID);
	return true;
}

TArray<FFamilyMember> UFELFamilyManager::GetMembers(const FString& FamilyID) const
{
	if (const auto* F = Families.Find(FamilyID)) return F->Members;
	return TArray<FFamilyMember>();
}

int32 UFELFamilyManager::GetMemberCount(const FString& FamilyID) const
{
	if (const auto* F = Families.Find(FamilyID)) return F->Members.Num();
	return 0;
}

/* ─────────────  Invitations  ────────────────────────────────────── */

FFamilyInvitation UFELFamilyManager::GenerateInviteCode(const FString& FamilyID, const FString& InviterUserID)
{
	FFamilyInvitation Invite;
	const FFamilyGroup* Family = Families.Find(FamilyID);
	if (!Family || !IsOwnerOrAdult(*Family, InviterUserID)) return Invite;

	Invite.InviteCode = GenerateInviteCodeString();
	Invite.FamilyID = FamilyID;
	Invite.InvitedByUserID = InviterUserID;
	Invite.Status = EInviteStatus::Pending;
	Invite.CreatedDate = FDateTime::UtcNow();
	Invite.ExpiryDate = FDateTime::UtcNow() + FTimespan::FromDays(FELFamilyConstants::INVITE_EXPIRY_DAYS);

	InviteCodeMap.Add(Invite.InviteCode, Invite);

	// Also store on the family
	FFamilyGroup* MutableFamily = Families.Find(FamilyID);
	if (MutableFamily)
	{
		MutableFamily->PendingInvites.Add(Invite);
	}

	OnInviteSent.Broadcast(Invite);
	UE_LOG(LogTemp, Log, TEXT("[FEL-Family] Invite code %s generated for family %s"), *Invite.InviteCode, *FamilyID);
	return Invite;
}

bool UFELFamilyManager::SendInviteByEmail(const FString& FamilyID, const FString& InviterUserID, const FString& Email)
{
	FFamilyInvitation Invite = GenerateInviteCode(FamilyID, InviterUserID);
	if (Invite.InviteCode.IsEmpty()) return false;

	Invite.InviteeEmail = Email;

	// In production: send email via backend API
	UE_LOG(LogTemp, Log, TEXT("[FEL-Family] Invite sent to %s with code %s"), *Email, *Invite.InviteCode);
	return true;
}

bool UFELFamilyManager::AcceptInvite(const FString& InviteCode, const FString& UserID, const FString& DisplayName)
{
	FFamilyInvitation* Invite = InviteCodeMap.Find(InviteCode);
	if (!Invite || Invite->Status != EInviteStatus::Pending) return false;

	// Check expiry
	if (FDateTime::UtcNow() > Invite->ExpiryDate)
	{
		Invite->Status = EInviteStatus::Expired;
		return false;
	}

	// Add member to family
	FFamilyMember NewMember;
	NewMember.UserID = UserID;
	NewMember.DisplayName = DisplayName;
	NewMember.Role = EFamilyRole::Adult;

	if (!AddMember(Invite->FamilyID, NewMember)) return false;

	Invite->Status = EInviteStatus::Accepted;

	UE_LOG(LogTemp, Log, TEXT("[FEL-Family] %s accepted invite %s to family %s"),
		*UserID, *InviteCode, *Invite->FamilyID);
	return true;
}

bool UFELFamilyManager::DeclineInvite(const FString& InviteCode)
{
	FFamilyInvitation* Invite = InviteCodeMap.Find(InviteCode);
	if (!Invite || Invite->Status != EInviteStatus::Pending) return false;

	Invite->Status = EInviteStatus::Declined;
	return true;
}

bool UFELFamilyManager::RevokeInvite(const FString& InviteCode, const FString& RequestingUserID)
{
	FFamilyInvitation* Invite = InviteCodeMap.Find(InviteCode);
	if (!Invite) return false;

	const FFamilyGroup* Family = Families.Find(Invite->FamilyID);
	if (!Family || !IsOwnerOrAdult(*Family, RequestingUserID)) return false;

	Invite->Status = EInviteStatus::Revoked;
	return true;
}

/* ─────────────  Parental Controls  ─────────────────────────────── */

bool UFELFamilyManager::SetParentalControls(const FString& FamilyID, const FString& ChildUserID,
	const FParentalControls& Controls, const FString& RequestingUserID)
{
	FFamilyGroup* Family = Families.Find(FamilyID);
	if (!Family || !IsOwnerOrAdult(*Family, RequestingUserID)) return false;

	for (FFamilyMember& M : Family->Members)
	{
		if (M.UserID == ChildUserID)
		{
			M.ParentalControls = Controls;
			UE_LOG(LogTemp, Log, TEXT("[FEL-Family] Parental controls updated for %s"), *ChildUserID);
			return true;
		}
	}
	return false;
}

FParentalControls UFELFamilyManager::GetParentalControls(const FString& FamilyID, const FString& ChildUserID) const
{
	if (const FFamilyGroup* Family = Families.Find(FamilyID))
	{
		for (const FFamilyMember& M : Family->Members)
		{
			if (M.UserID == ChildUserID) return M.ParentalControls;
		}
	}
	return FParentalControls();
}

bool UFELFamilyManager::IsWithinAllowedPlayTime(const FString& FamilyID, const FString& ChildUserID) const
{
	FParentalControls Controls = GetParentalControls(FamilyID, ChildUserID);
	if (!Controls.bPlayTimeLimits) return true;

	// Simple time check (in production: parse AllowedPlayTimeStart/End)
	int32 CurrentHour = FDateTime::Now().GetHour();
	return CurrentHour >= 8 && CurrentHour < 21;
}

bool UFELFamilyManager::HasExceededDailyLimit(const FString& FamilyID, const FString& ChildUserID) const
{
	// In production: track actual playtime per session per day
	return false;
}

/* ─────────────  Leaderboard  ───────────────────────────────────── */

TArray<FFamilyLeaderboardEntry> UFELFamilyManager::GetFamilyLeaderboard(const FString& FamilyID) const
{
	TArray<FFamilyLeaderboardEntry> Leaderboard;

	const FFamilyGroup* Family = Families.Find(FamilyID);
	if (!Family) return Leaderboard;

	for (const FFamilyMember& M : Family->Members)
	{
		FFamilyLeaderboardEntry Entry;
		Entry.UserID = M.UserID;
		Entry.DisplayName = M.DisplayName;
		Entry.WorkoutsThisWeek = M.WorkoutsCompleted; // simplified
		Entry.WeeklyPoints = M.WorkoutsCompleted * 50 + (int32)(M.TotalPlayTimeHours * 10);
		Leaderboard.Add(Entry);
	}

	// Sort by points descending
	Leaderboard.Sort([](const FFamilyLeaderboardEntry& A, const FFamilyLeaderboardEntry& B)
	{
		return A.WeeklyPoints > B.WeeklyPoints;
	});

	// Assign ranks
	for (int32 i = 0; i < Leaderboard.Num(); ++i)
	{
		Leaderboard[i].Rank = i + 1;
	}

	return Leaderboard;
}

/* ─────────────  Internal  ───────────────────────────────────────── */

FString UFELFamilyManager::GenerateFamilyID() const
{
	return FString::Printf(TEXT("FAM-%s"), *FGuid::NewGuid().ToString(EGuidFormats::Short));
}

FString UFELFamilyManager::GenerateInviteCodeString() const
{
	// FEL-XXXX-XXXX format
	FString Part1 = FGuid::NewGuid().ToString(EGuidFormats::Short).Left(4).ToUpper();
	FString Part2 = FGuid::NewGuid().ToString(EGuidFormats::Short).Left(4).ToUpper();
	return FString::Printf(TEXT("FEL-%s-%s"), *Part1, *Part2);
}

void UFELFamilyManager::UpdateTierSettings(FFamilyGroup& Family)
{
	Family.WeeklyPrice = GetTierPrice(Family.Tier);
	Family.MaxMembers = GetTierMaxMembers(Family.Tier);
}

bool UFELFamilyManager::IsOwnerOrAdult(const FFamilyGroup& Family, const FString& UserID) const
{
	if (Family.OwnerUserID == UserID) return true;

	for (const FFamilyMember& M : Family.Members)
	{
		if (M.UserID == UserID && M.Role != EFamilyRole::Child) return true;
	}
	return false;
}
