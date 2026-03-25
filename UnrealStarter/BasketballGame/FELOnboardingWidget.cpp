// Copyright (c) Final Evolution Lab.

#include "FELOnboardingWidget.h"
#include "FELBasketballGameMode.h"
#include "FELPlatformPaths.h"
#include "Blueprint/WidgetTree.h"
#include "Components/Button.h"
#include "Components/PanelWidget.h"
#include "Components/TextBlock.h"
#include "Components/VerticalBox.h"
#include "Components/VerticalBoxSlot.h"
#include "Engine/World.h"
#include "GameFramework/GameModeBase.h"
#include "GameFramework/PlayerController.h"

void UFELOnboardingWidget::NativeConstruct()
{
	Super::NativeConstruct();
	BuildFallbackLayout();
}

void UFELOnboardingWidget::BuildFallbackLayout()
{
	if (!WidgetTree)
	{
		return;
	}
	if (BodyTextBlock && DismissButton && WatchDemoButton)
	{
		return;
	}

	// Blueprint may supply Body + Dismiss only — insert Watch Demo before Dismiss.
	if (BodyTextBlock && DismissButton && !WatchDemoButton)
	{
		if (UVerticalBox* RootVBox = Cast<UVerticalBox>(WidgetTree->RootWidget))
		{
			WatchDemoButton = WidgetTree->ConstructWidget<UButton>(UButton::StaticClass());
			UTextBlock* WatchLabel = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
			WatchLabel->SetText(NSLOCTEXT("FEL", "OnboardingWatchDemo", "Watch Demo (Perfect Form)"));
			WatchLabel->SetJustification(ETextJustify::Center);
			WatchDemoButton->AddChild(WatchLabel);
			WatchDemoButton->OnClicked.AddLambda(
				[this]()
				{
					OnWatchDemoClicked();
				});
			const int32 DismissIdx = RootVBox->GetChildIndex(DismissButton);
			if (DismissIdx != INDEX_NONE)
			{
				RootVBox->InsertChildAt(DismissIdx, WatchDemoButton);
			}
			else
			{
				if (UVerticalBoxSlot* Sw = RootVBox->AddChildToVerticalBox(WatchDemoButton))
				{
					Sw->SetPadding(FMargin(28.f, 0.f, 28.f, 12.f));
				}
			}
		}
		return;
	}

	BodyTextBlock = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	BodyTextBlock->SetAutoWrapText(true);
	BodyTextBlock->SetJustification(ETextJustify::Center);
	BodyTextBlock->SetColorAndOpacity(FSlateColor(FLinearColor::White));

	WatchDemoButton = WidgetTree->ConstructWidget<UButton>(UButton::StaticClass());
	UTextBlock* WatchLabel = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	WatchLabel->SetText(NSLOCTEXT("FEL", "OnboardingWatchDemo", "Watch Demo (Perfect Form)"));
	WatchLabel->SetJustification(ETextJustify::Center);
	WatchDemoButton->AddChild(WatchLabel);
	WatchDemoButton->OnClicked.AddLambda(
		[this]()
		{
			OnWatchDemoClicked();
		});

	DismissButton = WidgetTree->ConstructWidget<UButton>(UButton::StaticClass());
	UTextBlock* BtnLabel = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	BtnLabel->SetText(NSLOCTEXT("FEL", "OnboardingOk", "Got it — enter the Lab"));
	BtnLabel->SetJustification(ETextJustify::Center);
	DismissButton->AddChild(BtnLabel);
	DismissButton->OnClicked.AddLambda(
		[this]()
		{
			OnDismissClicked();
		});

	UVerticalBox* RootVBox = WidgetTree->ConstructWidget<UVerticalBox>(UVerticalBox::StaticClass());
	WidgetTree->RootWidget = RootVBox;
	if (UVerticalBoxSlot* S = RootVBox->AddChildToVerticalBox(BodyTextBlock))
	{
		S->SetPadding(FMargin(28.f, 28.f, 28.f, 16.f));
	}
	if (UVerticalBoxSlot* Sw = RootVBox->AddChildToVerticalBox(WatchDemoButton))
	{
		Sw->SetPadding(FMargin(28.f, 0.f, 28.f, 12.f));
	}
	if (UVerticalBoxSlot* S2 = RootVBox->AddChildToVerticalBox(DismissButton))
	{
		S2->SetPadding(FMargin(28.f, 0.f, 28.f, 28.f));
	}
}

void UFELOnboardingWidget::InitializeLabOnboarding()
{
	if (BodyTextBlock)
	{
		BodyTextBlock->SetText(NSLOCTEXT(
			"FEL",
			"LabOnboardingBody",
			"Welcome to the Lab.\n\n"
			"• Use Get Ready → Play → Result like Arena (PROJECT_FLOWS).\n"
			"• Dunk Contest uses the same neuro readiness export as Swift (PRQ, hang time, leakage).\n"
			"• Brain Brawl quizzes can boost PRQ during a match — check session_results.json after play.\n"
			"• Watch Demo shows Bonds Bounce–scaled perfect form before you play."));
	}
}

void UFELOnboardingWidget::OnWatchDemoClicked()
{
	if (UWorld* World = GetWorld())
	{
		if (AGameModeBase* GM = World->GetAuthGameMode())
		{
			if (AFELBasketballGameMode* Mode = Cast<AFELBasketballGameMode>(GM))
			{
				Mode->TriggerExerciseDemo();
			}
		}
	}
}

void UFELOnboardingWidget::OnDismissClicked()
{
	if (UWorld* World = GetWorld())
	{
		if (AGameModeBase* GM = World->GetAuthGameMode())
		{
			if (AFELBasketballGameMode* Mode = Cast<AFELBasketballGameMode>(GM))
			{
				Mode->EndExerciseDemoIfActive();
			}
		}
	}
	FELPlatformPaths::SetLabOnboardingCompleted();
	if (APlayerController* PC = GetOwningPlayer())
	{
		PC->SetShowMouseCursor(false);
		FInputModeGameOnly Mode;
		PC->SetInputMode(Mode);
	}
	OnDismissed.Broadcast();
	RemoveFromParent();
}
