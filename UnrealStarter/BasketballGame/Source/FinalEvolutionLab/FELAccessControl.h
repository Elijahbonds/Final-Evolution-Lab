// Copyright (c) Final Evolution Lab.
// Access control: gate game modes and features behind subscription.
// Phase 3: Subscription Model

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELSubscription.h"
#include "FELAccessControl.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnAccessDenied);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnSubscriptionRequired, const FString&, FeatureName);

UCLASS()
class FINALEVOLUTIONLAB_API UFELAccessControl : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;

	/** Check if user can access a specific game mode. Shows subscription prompt if not. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Access")
	bool CanAccessGameMode(const FString& GameModeID);

	/** Check if user can access workout features. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Access")
	bool CanAccessWorkouts();

	/** Check if user can access exercise library. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Access")
	bool CanAccessExerciseLibrary();

	/** Check if user can access a creator's content. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Access")
	bool CanAccessCreatorContent(const FString& CreatorID);

	/** Generic access check — returns true if trial or subscription is active. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Access")
	bool CheckAccess(const FString& FeatureName);

	/** Get a user-friendly message for why access is denied. */
	UFUNCTION(BlueprintPure, Category = "FEL|Access")
	FString GetAccessDeniedMessage() const;

	// ── delegates ────────────────────────────────────────────────────
	UPROPERTY(BlueprintAssignable, Category = "FEL|Access")
	FOnAccessDenied OnAccessDenied;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Access")
	FOnSubscriptionRequired OnSubscriptionRequired;
};
