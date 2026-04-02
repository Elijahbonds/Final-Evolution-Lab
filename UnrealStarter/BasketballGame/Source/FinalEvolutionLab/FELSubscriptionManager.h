// Copyright (c) Final Evolution Lab.
// Subscription lifecycle manager: trial tracking, payments, Stripe integration.
// Phase 3: Subscription Model

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELSubscription.h"
#include "FELSubscriptionManager.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnSubscriptionStatusChanged, ESubscriptionStatus, NewStatus);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnTrialTimeUpdate, int32, HoursRemaining);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnPaymentSuccess);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnPaymentFailed, const FString&, Reason);

UCLASS()
class FINALEVOLUTIONLAB_API UFELSubscriptionManager : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// ── status queries ────────────────────────────────────────────────
	UFUNCTION(BlueprintPure, Category = "FEL|Subscription")
	bool IsTrialActive() const;

	UFUNCTION(BlueprintPure, Category = "FEL|Subscription")
	bool IsSubscriptionActive() const;

	/** Returns true if user has any form of valid access (trial OR subscription). */
	UFUNCTION(BlueprintPure, Category = "FEL|Subscription")
	bool HasAccess() const;

	UFUNCTION(BlueprintPure, Category = "FEL|Subscription")
	int32 GetTrialHoursRemaining() const;

	UFUNCTION(BlueprintPure, Category = "FEL|Subscription")
	ESubscriptionStatus GetStatus() const;

	UFUNCTION(BlueprintPure, Category = "FEL|Subscription")
	FSubscriptionData GetSubscriptionData() const { return SubData; }

	UFUNCTION(BlueprintPure, Category = "FEL|Subscription")
	FString GetStatusDisplayText() const;

	// ── trial management ─────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Subscription")
	void StartFreeTrial();

	// ── subscription lifecycle ───────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Subscription")
	void ActivateSubscription(const FString& StripeCustomerID, const FString& StripeSubscriptionID);

	UFUNCTION(BlueprintCallable, Category = "FEL|Subscription")
	void CancelSubscription();

	UFUNCTION(BlueprintCallable, Category = "FEL|Subscription")
	void HandlePaymentSuccess(const FPaymentReceipt& Receipt);

	UFUNCTION(BlueprintCallable, Category = "FEL|Subscription")
	void HandlePaymentFailure(const FString& Reason);

	UFUNCTION(BlueprintCallable, Category = "FEL|Subscription")
	void RestoreSubscription(const FString& ReceiptData);

	// ── Stripe integration (HTTP calls) ─────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Subscription")
	void CreateStripeCheckoutSession();

	UFUNCTION(BlueprintCallable, Category = "FEL|Subscription")
	void UpdatePaymentMethod(const FString& NewPaymentMethodID);

	// ── delegates ────────────────────────────────────────────────────
	UPROPERTY(BlueprintAssignable, Category = "FEL|Subscription")
	FOnSubscriptionStatusChanged OnStatusChanged;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Subscription")
	FOnTrialTimeUpdate OnTrialTimeUpdate;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Subscription")
	FOnPaymentSuccess OnPaymentSuccess;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Subscription")
	FOnPaymentFailed OnPaymentFailed;

private:
	void LoadSubscriptionState();
	void SaveSubscriptionState();
	void SetStatus(ESubscriptionStatus NewStatus);
	void TickTrialCheck();

	FSubscriptionData SubData;
	FTimerHandle TrialCheckTimer;
};
