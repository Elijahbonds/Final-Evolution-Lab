// Copyright (c) Final Evolution Lab.
// Access control implementation.

#include "FELAccessControl.h"
#include "FELSubscriptionManager.h"

DEFINE_LOG_CATEGORY_STATIC(LogFELAccess, Log, All);

void UFELAccessControl::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	UE_LOG(LogFELAccess, Log, TEXT("AccessControl subsystem initialised."));
}

bool UFELAccessControl::CheckAccess(const FString& FeatureName)
{
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELSubscriptionManager* SubMgr = GI->GetSubsystem<UFELSubscriptionManager>())
		{
			if (SubMgr->HasAccess())
			{
				return true;
			}
		}
	}

	// Access denied
	OnAccessDenied.Broadcast();
	OnSubscriptionRequired.Broadcast(FeatureName);
	UE_LOG(LogFELAccess, Warning, TEXT("Access denied for feature '%s' — subscription required."), *FeatureName);
	return false;
}

bool UFELAccessControl::CanAccessGameMode(const FString& GameModeID)
{
	return CheckAccess(FString::Printf(TEXT("Game Mode: %s"), *GameModeID));
}

bool UFELAccessControl::CanAccessWorkouts()
{
	return CheckAccess(TEXT("Workout Programs"));
}

bool UFELAccessControl::CanAccessExerciseLibrary()
{
	return CheckAccess(TEXT("Exercise Library"));
}

bool UFELAccessControl::CanAccessCreatorContent(const FString& CreatorID)
{
	return CheckAccess(FString::Printf(TEXT("Creator Content: %s"), *CreatorID));
}

FString UFELAccessControl::GetAccessDeniedMessage() const
{
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELSubscriptionManager* SubMgr = GI->GetSubsystem<UFELSubscriptionManager>())
		{
			switch (SubMgr->GetStatus())
			{
			case ESubscriptionStatus::Expired:
				return TEXT("Your free trial has ended. Subscribe for just $6/week to continue training!");
			case ESubscriptionStatus::Cancelled:
				return TEXT("Your subscription has been cancelled. Reactivate for $6/week to get back in the game.");
			case ESubscriptionStatus::PaymentFailed:
				return TEXT("Your payment couldn't be processed. Update your payment method to continue.");
			default:
				break;
			}
		}
	}
	return TEXT("A subscription is required to access this feature. Start your 72-hour free trial!");
}
