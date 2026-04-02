// Copyright (c) Final Evolution Lab.

#include "FELTrialBannerWidget.h"
#include "FELSubscriptionManager.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/Border.h"

void UFELTrialBannerWidget::NativeConstruct()
{
	Super::NativeConstruct();

	if (SubscribeNowButton)
		SubscribeNowButton->OnClicked.AddDynamic(this, &UFELTrialBannerWidget::OnSubscribeNowClicked);

	if (SubscribeInfoText)
		SubscribeInfoText->SetText(FText::FromString(TEXT("Subscribe for $6/week after trial")));

	UpdateBanner();
}

void UFELTrialBannerWidget::NativeTick(const FGeometry& MyGeometry, float InDeltaTime)
{
	Super::NativeTick(MyGeometry, InDeltaTime);

	TickAccum += InDeltaTime;
	if (TickAccum >= 60.f) // Update every minute
	{
		TickAccum = 0.f;
		UpdateBanner();
	}
}

void UFELTrialBannerWidget::UpdateBanner()
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELSubscriptionManager* SubMgr = GI->GetSubsystem<UFELSubscriptionManager>();
	if (!SubMgr) return;

	ESubscriptionStatus Status = SubMgr->GetStatus();

	// Only show banner during trial
	if (Status == ESubscriptionStatus::FreeTrial)
	{
		SetVisibility(ESlateVisibility::Visible);
		int32 Hours = SubMgr->GetTrialHoursRemaining();

		FString Msg;
		if (Hours > 24)
			Msg = FString::Printf(TEXT("FREE TRIAL: %d hours remaining"), Hours);
		else if (Hours > 1)
			Msg = FString::Printf(TEXT("⚠️ FREE TRIAL: %d hours remaining!"), Hours);
		else
			Msg = TEXT("⚠️ FREE TRIAL: Less than 1 hour remaining!");

		if (TrialMessageText)
			TrialMessageText->SetText(FText::FromString(Msg));
	}
	else if (Status == ESubscriptionStatus::Active)
	{
		SetVisibility(ESlateVisibility::Collapsed);
	}
	else // Expired
	{
		SetVisibility(ESlateVisibility::Visible);
		if (TrialMessageText)
			TrialMessageText->SetText(FText::FromString(TEXT("TRIAL ENDED — Subscribe to continue")));
	}
}

void UFELTrialBannerWidget::OnSubscribeNowClicked()
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELSubscriptionManager* SubMgr = GI->GetSubsystem<UFELSubscriptionManager>();
	if (!SubMgr) return;

	SubMgr->CreateStripeCheckoutSession();
}
