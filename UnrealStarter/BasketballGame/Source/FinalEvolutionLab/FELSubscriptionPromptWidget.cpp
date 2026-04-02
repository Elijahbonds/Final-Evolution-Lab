// Copyright (c) Final Evolution Lab.

#include "FELSubscriptionPromptWidget.h"
#include "FELSubscriptionManager.h"
#include "Components/TextBlock.h"
#include "Components/RichTextBlock.h"
#include "Components/Button.h"

void UFELSubscriptionPromptWidget::NativeConstruct()
{
	Super::NativeConstruct();

	if (HeadlineText)
		HeadlineText->SetText(FText::FromString(TEXT("UNLOCK YOUR FULL EVOLUTION")));

	if (BenefitsText)
		BenefitsText->SetText(FText::FromString(
			TEXT("✅ 17 game modes across 8 sports\n")
			TEXT("✅ 23 animated exercise demonstrations\n")
			TEXT("✅ 5 pre-built workout programs\n")
			TEXT("✅ Custom workout builder\n")
			TEXT("✅ Creator challenges & content\n")
			TEXT("✅ Progress tracking & personal records\n")
			TEXT("✅ Form validation & coaching")));

	if (PriceText)
		PriceText->SetText(FText::FromString(TEXT("Only $6/week — Cancel anytime")));

	if (SubscribeButton)
		SubscribeButton->OnClicked.AddDynamic(this, &UFELSubscriptionPromptWidget::OnSubscribeClicked);
	if (MaybeLaterButton)
		MaybeLaterButton->OnClicked.AddDynamic(this, &UFELSubscriptionPromptWidget::OnMaybeLaterClicked);
}

void UFELSubscriptionPromptWidget::OnSubscribeClicked()
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELSubscriptionManager* SubMgr = GI->GetSubsystem<UFELSubscriptionManager>();
	if (!SubMgr) return;

	SubMgr->CreateStripeCheckoutSession();
}

void UFELSubscriptionPromptWidget::OnMaybeLaterClicked()
{
	RemoveFromParent();
}
