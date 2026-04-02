// Copyright (c) Final Evolution Lab.
// Subscription data types: trial, weekly $6 subscription, access control.
// Phase 3: Subscription Model

#pragma once

#include "CoreMinimal.h"
#include "FELSubscription.generated.h"

/* ─────────────────────────────  CONSTANTS  ─────────────────────────── */

namespace FELSubscriptionConstants
{
	/** Free trial duration in hours. */
	constexpr int32 TRIAL_HOURS           = 72;

	/** Weekly subscription price in USD. */
	constexpr float WEEKLY_PRICE_USD      = 6.00f;

	/** Grace period after payment failure in hours. */
	constexpr int32 GRACE_PERIOD_HOURS    = 24;

	/** Hours before trial end to show first warning. */
	constexpr int32 TRIAL_WARN_HOURS      = 24;

	/** Stripe product ID (production). */
	static const TCHAR* STRIPE_PRODUCT_ID = TEXT("prod_FEL_Weekly");

	/** Stripe price ID (production). */
	static const TCHAR* STRIPE_PRICE_ID   = TEXT("price_FEL_6USD_Weekly");
}

/* ─────────────────────────────  ENUMS  ───────────────────────────── */

UENUM(BlueprintType)
enum class ESubscriptionStatus : uint8
{
	FreeTrial       UMETA(DisplayName = "Free Trial"),
	Active          UMETA(DisplayName = "Active Subscription"),
	Expired         UMETA(DisplayName = "Expired"),
	Cancelled       UMETA(DisplayName = "Cancelled"),
	PaymentFailed   UMETA(DisplayName = "Payment Failed"),
	GracePeriod     UMETA(DisplayName = "Grace Period")
};

UENUM(BlueprintType)
enum class EPaymentProvider : uint8
{
	Stripe          UMETA(DisplayName = "Stripe"),
	AppleIAP        UMETA(DisplayName = "Apple In-App Purchase"),
	GooglePlayIAP   UMETA(DisplayName = "Google Play IAP")
};

/* ────────────────────────  SUBSCRIPTION  DATA  ───────────────────── */

USTRUCT(BlueprintType)
struct FSubscriptionData
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	FString UserID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	ESubscriptionStatus Status = ESubscriptionStatus::FreeTrial;

	/** UTC timestamp when the free trial started. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	FDateTime TrialStartDate;

	/** UTC timestamp when the free trial ends. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	FDateTime TrialEndDate;

	/** UTC timestamp when the paid subscription started. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	FDateTime SubscriptionStartDate;

	/** UTC timestamp for the next billing date. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	FDateTime NextBillingDate;

	/** Weekly price in USD. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	float WeeklyPrice = FELSubscriptionConstants::WEEKLY_PRICE_USD;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	bool bAutoRenew = true;

	/** Stripe customer / payment method IDs (encrypted at rest). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	FString PaymentMethodID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	FString StripeCustomerID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	FString StripeSubscriptionID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	EPaymentProvider Provider = EPaymentProvider::Stripe;

	/** Number of consecutive failed payment attempts. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Subscription")
	int32 FailedPaymentAttempts = 0;
};

/* ──────────────────────  PAYMENT  RECEIPT  ─────────────────────── */

USTRUCT(BlueprintType)
struct FPaymentReceipt
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Subscription")
	FString TransactionID;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Subscription")
	float Amount = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Subscription")
	FString Currency = TEXT("USD");

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Subscription")
	FDateTime Timestamp;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Subscription")
	bool bSuccess = false;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Subscription")
	FString FailureReason;
};
