// Copyright (c) Final Evolution Lab.
// Subscription manager implementation.

#include "FELSubscriptionManager.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "TimerManager.h"
#include "Engine/World.h"
#include "HttpModule.h"
#include "Interfaces/IHttpRequest.h"
#include "Interfaces/IHttpResponse.h"

DEFINE_LOG_CATEGORY_STATIC(LogFELSubscription, Log, All);

static const FString SUBSCRIPTION_SAVE_PATH = FPaths::ProjectSavedDir() / TEXT("FEL/subscription.json");
static const FString STRIPE_API_BASE = TEXT("https://api.finalevolutiongroup.com/v1/subscription");

/* ─────────────────────────  LIFECYCLE  ───────────────────────────── */

void UFELSubscriptionManager::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	LoadSubscriptionState();

	UE_LOG(LogFELSubscription, Log, TEXT("SubscriptionManager init — status=%d, trial_hours_left=%d"),
		(int32)SubData.Status, GetTrialHoursRemaining());
}

void UFELSubscriptionManager::Deinitialize()
{
	SaveSubscriptionState();
	Super::Deinitialize();
}

/* ─────────────────────────  PERSISTENCE  ─────────────────────────── */

void UFELSubscriptionManager::LoadSubscriptionState()
{
	FString Path = FPaths::ProjectSavedDir() / TEXT("FEL/subscription.json");
	FString JsonStr;
	if (!FFileHelper::LoadFileToString(JsonStr, *Path))
	{
		// No saved state — first launch
		SubData = FSubscriptionData();
		return;
	}

	TSharedPtr<FJsonObject> Root;
	if (!FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(JsonStr), Root) || !Root.IsValid()) return;

	Root->TryGetStringField(TEXT("userID"), SubData.UserID);

	double D;
	if (Root->TryGetNumberField(TEXT("status"), D))
		SubData.Status = static_cast<ESubscriptionStatus>((int32)D);

	FString DateStr;
	if (Root->TryGetStringField(TEXT("trialStartDate"), DateStr))
		FDateTime::ParseIso8601(*DateStr, SubData.TrialStartDate);
	if (Root->TryGetStringField(TEXT("trialEndDate"), DateStr))
		FDateTime::ParseIso8601(*DateStr, SubData.TrialEndDate);
	if (Root->TryGetStringField(TEXT("subscriptionStartDate"), DateStr))
		FDateTime::ParseIso8601(*DateStr, SubData.SubscriptionStartDate);
	if (Root->TryGetStringField(TEXT("nextBillingDate"), DateStr))
		FDateTime::ParseIso8601(*DateStr, SubData.NextBillingDate);

	if (Root->TryGetNumberField(TEXT("weeklyPrice"), D)) SubData.WeeklyPrice = (float)D;
	Root->TryGetBoolField(TEXT("autoRenew"), SubData.bAutoRenew);
	Root->TryGetStringField(TEXT("paymentMethodID"), SubData.PaymentMethodID);
	Root->TryGetStringField(TEXT("stripeCustomerID"), SubData.StripeCustomerID);
	Root->TryGetStringField(TEXT("stripeSubscriptionID"), SubData.StripeSubscriptionID);

	// Re-evaluate status on load
	if (SubData.Status == ESubscriptionStatus::FreeTrial && !IsTrialActive())
	{
		SetStatus(ESubscriptionStatus::Expired);
	}
}

void UFELSubscriptionManager::SaveSubscriptionState()
{
	TSharedPtr<FJsonObject> Root = MakeShared<FJsonObject>();
	Root->SetStringField(TEXT("userID"), SubData.UserID);
	Root->SetNumberField(TEXT("status"), (double)SubData.Status);
	Root->SetStringField(TEXT("trialStartDate"), SubData.TrialStartDate.ToIso8601());
	Root->SetStringField(TEXT("trialEndDate"), SubData.TrialEndDate.ToIso8601());
	Root->SetStringField(TEXT("subscriptionStartDate"), SubData.SubscriptionStartDate.ToIso8601());
	Root->SetStringField(TEXT("nextBillingDate"), SubData.NextBillingDate.ToIso8601());
	Root->SetNumberField(TEXT("weeklyPrice"), SubData.WeeklyPrice);
	Root->SetBoolField(TEXT("autoRenew"), SubData.bAutoRenew);
	Root->SetStringField(TEXT("paymentMethodID"), SubData.PaymentMethodID);
	Root->SetStringField(TEXT("stripeCustomerID"), SubData.StripeCustomerID);
	Root->SetStringField(TEXT("stripeSubscriptionID"), SubData.StripeSubscriptionID);

	FString Out;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&Out);
	FJsonSerializer::Serialize(Root.ToSharedRef(), Writer);

	FString Path = FPaths::ProjectSavedDir() / TEXT("FEL/subscription.json");
	FFileHelper::SaveStringToFile(Out, *Path);
}

/* ─────────────────────────  STATUS  QUERIES  ──────────────────────── */

bool UFELSubscriptionManager::IsTrialActive() const
{
	if (SubData.Status != ESubscriptionStatus::FreeTrial) return false;
	return FDateTime::UtcNow() < SubData.TrialEndDate;
}

bool UFELSubscriptionManager::IsSubscriptionActive() const
{
	return SubData.Status == ESubscriptionStatus::Active ||
	       SubData.Status == ESubscriptionStatus::GracePeriod;
}

bool UFELSubscriptionManager::HasAccess() const
{
	return IsTrialActive() || IsSubscriptionActive();
}

int32 UFELSubscriptionManager::GetTrialHoursRemaining() const
{
	if (SubData.Status != ESubscriptionStatus::FreeTrial) return 0;
	FTimespan Remaining = SubData.TrialEndDate - FDateTime::UtcNow();
	return FMath::Max(0, (int32)Remaining.GetTotalHours());
}

ESubscriptionStatus UFELSubscriptionManager::GetStatus() const
{
	return SubData.Status;
}

FString UFELSubscriptionManager::GetStatusDisplayText() const
{
	switch (SubData.Status)
	{
	case ESubscriptionStatus::FreeTrial:
	{
		int32 Hours = GetTrialHoursRemaining();
		return FString::Printf(TEXT("Free Trial: %d hours remaining"), Hours);
	}
	case ESubscriptionStatus::Active:
		return TEXT("Active Subscription — $6/week");
	case ESubscriptionStatus::Expired:
		return TEXT("Trial Expired — Subscribe for $6/week");
	case ESubscriptionStatus::Cancelled:
		return TEXT("Subscription Cancelled");
	case ESubscriptionStatus::PaymentFailed:
		return TEXT("Payment Failed — Update payment method");
	case ESubscriptionStatus::GracePeriod:
		return TEXT("Grace Period — Update payment to continue");
	default:
		return TEXT("Unknown");
	}
}

/* ─────────────────────────  TRIAL  ──────────────────────────────── */

void UFELSubscriptionManager::StartFreeTrial()
{
	// Don't restart if already active or was already trialled
	if (SubData.Status == ESubscriptionStatus::Active) return;
	if (SubData.TrialStartDate != FDateTime()) return; // Already trialled once

	SubData.TrialStartDate = FDateTime::UtcNow();
	SubData.TrialEndDate = SubData.TrialStartDate + FTimespan(FELSubscriptionConstants::TRIAL_HOURS, 0, 0);
	SetStatus(ESubscriptionStatus::FreeTrial);
	SaveSubscriptionState();

	UE_LOG(LogFELSubscription, Log, TEXT("Free trial started — expires %s"), *SubData.TrialEndDate.ToIso8601());
}

/* ─────────────────────────  SUBSCRIPTION  LIFECYCLE  ────────────────── */

void UFELSubscriptionManager::ActivateSubscription(const FString& CustomerID, const FString& SubscriptionID)
{
	SubData.StripeCustomerID = CustomerID;
	SubData.StripeSubscriptionID = SubscriptionID;
	SubData.SubscriptionStartDate = FDateTime::UtcNow();
	SubData.NextBillingDate = SubData.SubscriptionStartDate + FTimespan(7, 0, 0, 0); // +7 days
	SubData.FailedPaymentAttempts = 0;
	SetStatus(ESubscriptionStatus::Active);
	SaveSubscriptionState();

	UE_LOG(LogFELSubscription, Log, TEXT("Subscription activated — next billing %s"),
		*SubData.NextBillingDate.ToIso8601());
}

void UFELSubscriptionManager::CancelSubscription()
{
	SetStatus(ESubscriptionStatus::Cancelled);
	SubData.bAutoRenew = false;
	SaveSubscriptionState();

	UE_LOG(LogFELSubscription, Log, TEXT("Subscription cancelled."));
}

void UFELSubscriptionManager::HandlePaymentSuccess(const FPaymentReceipt& Receipt)
{
	SubData.NextBillingDate = FDateTime::UtcNow() + FTimespan(7, 0, 0, 0);
	SubData.FailedPaymentAttempts = 0;
	if (SubData.Status != ESubscriptionStatus::Active)
		SetStatus(ESubscriptionStatus::Active);
	SaveSubscriptionState();

	OnPaymentSuccess.Broadcast();
	UE_LOG(LogFELSubscription, Log, TEXT("Payment success — txn=%s, amount=%.2f %s"),
		*Receipt.TransactionID, Receipt.Amount, *Receipt.Currency);
}

void UFELSubscriptionManager::HandlePaymentFailure(const FString& Reason)
{
	SubData.FailedPaymentAttempts++;

	if (SubData.FailedPaymentAttempts >= 3)
	{
		SetStatus(ESubscriptionStatus::PaymentFailed);
	}
	else
	{
		SetStatus(ESubscriptionStatus::GracePeriod);
	}
	SaveSubscriptionState();

	OnPaymentFailed.Broadcast(Reason);
	UE_LOG(LogFELSubscription, Warning, TEXT("Payment failed (%d attempts): %s"),
		SubData.FailedPaymentAttempts, *Reason);
}

void UFELSubscriptionManager::RestoreSubscription(const FString& ReceiptData)
{
	// Validate receipt with backend (Apple/Google receipt validation)
	// For now, trust the receipt and activate
	UE_LOG(LogFELSubscription, Log, TEXT("Restoring subscription from receipt..."));

	TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Request = FHttpModule::Get().CreateRequest();
	Request->SetURL(STRIPE_API_BASE / TEXT("restore"));
	Request->SetVerb(TEXT("POST"));
	Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));

	TSharedPtr<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetStringField(TEXT("receiptData"), ReceiptData);
	Body->SetStringField(TEXT("userID"), SubData.UserID);

	FString BodyStr;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&BodyStr);
	FJsonSerializer::Serialize(Body.ToSharedRef(), Writer);
	Request->SetContentAsString(BodyStr);

	Request->OnProcessRequestComplete().BindLambda(
		[this](FHttpRequestPtr Req, FHttpResponsePtr Resp, bool bSuccess)
		{
			if (bSuccess && Resp.IsValid() && Resp->GetResponseCode() == 200)
			{
				TSharedPtr<FJsonObject> RespObj;
				FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Resp->GetContentAsString()), RespObj);
				if (RespObj.IsValid())
				{
					FString CustID, SubID;
					RespObj->TryGetStringField(TEXT("customerID"), CustID);
					RespObj->TryGetStringField(TEXT("subscriptionID"), SubID);
					ActivateSubscription(CustID, SubID);
				}
			}
			else
			{
				UE_LOG(LogFELSubscription, Warning, TEXT("Restore failed."));
			}
		});

	Request->ProcessRequest();
}

/* ─────────────────────────  STRIPE  ─────────────────────────────── */

void UFELSubscriptionManager::CreateStripeCheckoutSession()
{
	TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Request = FHttpModule::Get().CreateRequest();
	Request->SetURL(STRIPE_API_BASE / TEXT("create-checkout"));
	Request->SetVerb(TEXT("POST"));
	Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));

	TSharedPtr<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetStringField(TEXT("userID"), SubData.UserID);
	Body->SetStringField(TEXT("priceID"), FELSubscriptionConstants::STRIPE_PRICE_ID);
	Body->SetNumberField(TEXT("amount"), FELSubscriptionConstants::WEEKLY_PRICE_USD);

	FString BodyStr;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&BodyStr);
	FJsonSerializer::Serialize(Body.ToSharedRef(), Writer);
	Request->SetContentAsString(BodyStr);

	Request->OnProcessRequestComplete().BindLambda(
		[this](FHttpRequestPtr Req, FHttpResponsePtr Resp, bool bSuccess)
		{
			if (bSuccess && Resp.IsValid() && Resp->GetResponseCode() == 200)
			{
				TSharedPtr<FJsonObject> RespObj;
				FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Resp->GetContentAsString()), RespObj);
				if (RespObj.IsValid())
				{
					FString CheckoutURL;
					RespObj->TryGetStringField(TEXT("checkoutUrl"), CheckoutURL);
					UE_LOG(LogFELSubscription, Log, TEXT("Checkout session created: %s"), *CheckoutURL);
					// Open in embedded browser or platform browser
					FPlatformProcess::LaunchURL(*CheckoutURL, nullptr, nullptr);
				}
			}
			else
			{
				UE_LOG(LogFELSubscription, Error, TEXT("Failed to create checkout session."));
				OnPaymentFailed.Broadcast(TEXT("Could not connect to payment server."));
			}
		});

	Request->ProcessRequest();
}

void UFELSubscriptionManager::UpdatePaymentMethod(const FString& NewPaymentMethodID)
{
	SubData.PaymentMethodID = NewPaymentMethodID;

	TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Request = FHttpModule::Get().CreateRequest();
	Request->SetURL(STRIPE_API_BASE / TEXT("update-payment"));
	Request->SetVerb(TEXT("POST"));
	Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));

	TSharedPtr<FJsonObject> Body = MakeShared<FJsonObject>();
	Body->SetStringField(TEXT("customerID"), SubData.StripeCustomerID);
	Body->SetStringField(TEXT("paymentMethodID"), NewPaymentMethodID);

	FString BodyStr;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&BodyStr);
	FJsonSerializer::Serialize(Body.ToSharedRef(), Writer);
	Request->SetContentAsString(BodyStr);

	Request->OnProcessRequestComplete().BindLambda(
		[this](FHttpRequestPtr Req, FHttpResponsePtr Resp, bool bSuccess)
		{
			if (bSuccess && Resp.IsValid() && Resp->GetResponseCode() == 200)
			{
				UE_LOG(LogFELSubscription, Log, TEXT("Payment method updated."));
				SaveSubscriptionState();
			}
		});

	Request->ProcessRequest();
}

/* ─────────────────────────  INTERNAL  ────────────────────────────── */

void UFELSubscriptionManager::SetStatus(ESubscriptionStatus NewStatus)
{
	if (SubData.Status == NewStatus) return;
	SubData.Status = NewStatus;
	OnStatusChanged.Broadcast(NewStatus);
	SaveSubscriptionState();
}

void UFELSubscriptionManager::TickTrialCheck()
{
	if (SubData.Status == ESubscriptionStatus::FreeTrial)
	{
		int32 Hours = GetTrialHoursRemaining();
		OnTrialTimeUpdate.Broadcast(Hours);

		if (Hours <= 0)
		{
			SetStatus(ESubscriptionStatus::Expired);
		}
	}
}
