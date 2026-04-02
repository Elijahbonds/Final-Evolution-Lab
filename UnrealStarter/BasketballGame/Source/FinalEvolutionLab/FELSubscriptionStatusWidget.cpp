// Copyright (c) Final Evolution Lab.

#include "FELSubscriptionStatusWidget.h"
#include "FELSubscriptionManager.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/ProgressBar.h"

void UFELSubscriptionStatusWidget::NativeConstruct()
{
	Super::NativeConstruct();

	if (ManageButton)
		ManageButton->OnClicked.AddDynamic(this, &UFELSubscriptionStatusWidget::OnManageClicked);
	if (SubscribeButton)
		SubscribeButton->OnClicked.AddDynamic(this, &UFELSubscriptionStatusWidget::OnSubscribeClicked);

	RefreshStatus();
}

void UFELSubscriptionStatusWidget::NativeTick(const FGeometry& MyGeometry, float InDeltaTime)
{
	Super::NativeTick(MyGeometry, InDeltaTime);

	// Update every 30 seconds to avoid unnecessary overhead
	TickAccum += InDeltaTime;
	if (TickAccum >= 30.f)
	{
		TickAccum = 0.f;
		RefreshStatus();
	}
}

void UFELSubscriptionStatusWidget::RefreshStatus()
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELSubscriptionManager* SubMgr = GI->GetSubsystem<UFELSubscriptionManager>();
	if (!SubMgr) return;

	ESubscriptionStatus Status = SubMgr->GetStatus();

	if (StatusText)
		StatusText->SetText(FText::FromString(SubMgr->GetStatusDisplayText()));

	if (PriceText)
		PriceText->SetText(FText::FromString(TEXT("$6/week")));

	// Trial-specific UI
	if (Status == ESubscriptionStatus::FreeTrial)
	{
		int32 Hours = SubMgr->GetTrialHoursRemaining();
		if (TrialCountdownText)
			TrialCountdownText->SetText(FText::FromString(
				FString::Printf(TEXT("%d hours remaining"), Hours)));

		if (TrialProgressBar)
			TrialProgressBar->SetPercent((float)Hours / (float)FELSubscriptionConstants::TRIAL_HOURS);

		if (SubscribeButton)
			SubscribeButton->SetVisibility(ESlateVisibility::Visible);
		if (ManageButton)
			ManageButton->SetVisibility(ESlateVisibility::Collapsed);
	}
	else if (Status == ESubscriptionStatus::Active)
	{
		if (TrialCountdownText)
			TrialCountdownText->SetVisibility(ESlateVisibility::Collapsed);
		if (TrialProgressBar)
			TrialProgressBar->SetVisibility(ESlateVisibility::Collapsed);
		if (SubscribeButton)
			SubscribeButton->SetVisibility(ESlateVisibility::Collapsed);
		if (ManageButton)
			ManageButton->SetVisibility(ESlateVisibility::Visible);

		FSubscriptionData Data = SubMgr->GetSubscriptionData();
		if (NextBillingText)
			NextBillingText->SetText(FText::FromString(
				FString::Printf(TEXT("Next billing: %s"), *Data.NextBillingDate.ToString(TEXT("%B %d, %Y")))));
	}
	else // Expired, Cancelled, PaymentFailed
	{
		if (TrialCountdownText)
			TrialCountdownText->SetVisibility(ESlateVisibility::Collapsed);
		if (TrialProgressBar)
			TrialProgressBar->SetVisibility(ESlateVisibility::Collapsed);
		if (SubscribeButton)
			SubscribeButton->SetVisibility(ESlateVisibility::Visible);
		if (ManageButton)
			ManageButton->SetVisibility(ESlateVisibility::Collapsed);
	}
}

void UFELSubscriptionStatusWidget::OnManageClicked()
{
	// Open subscription management (billing portal URL)
	FPlatformProcess::LaunchURL(TEXT("https://billing.finalevolutiongroup.com/portal"), nullptr, nullptr);
}

void UFELSubscriptionStatusWidget::OnSubscribeClicked()
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELSubscriptionManager* SubMgr = GI->GetSubsystem<UFELSubscriptionManager>();
	if (!SubMgr) return;

	SubMgr->CreateStripeCheckoutSession();
}
