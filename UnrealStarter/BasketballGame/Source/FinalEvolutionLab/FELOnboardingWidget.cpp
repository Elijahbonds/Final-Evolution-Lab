// Copyright (c) Final Evolution Lab.

#include "FELOnboardingWidget.h"
#include "FELSubscriptionManager.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/WidgetSwitcher.h"

struct FOnboardingStepContent
{
	FString Title;
	FString Description;
};

static const FOnboardingStepContent StepContents[] =
{
	// Welcome
	{ TEXT("Welcome to Final Evolution Lab"),
	  TEXT("The ultimate sports training platform.\n17 game modes. 23 exercises. Infinite evolution.") },
	// TrialExplain
	{ TEXT("Start Your 72-Hour Free Trial"),
	  TEXT("Get full access to every game mode, workout program, and exercise for 72 hours.\nNo credit card required to start!") },
	// AccountCreate
	{ TEXT("Create Your Account"),
	  TEXT("Set up your profile to track progress, earn achievements, and compete with friends.") },
	// TrialActivation
	{ TEXT("Trial Activated!"),
	  TEXT("Your 72-hour free trial is now active!\nExplore everything Final Evolution Lab has to offer.") },
	// Tutorial
	{ TEXT("Quick Tour"),
	  TEXT("• Exercises: 23 animated demos with form coaching\n"
	       "• Workouts: 5 pre-built programs + custom builder\n"
	       "• Game Modes: Basketball, Soccer, Karate & more\n"
	       "• Creators: Train with pro athletes") },
	// StartPlaying
	{ TEXT("Let's Go!"),
	  TEXT("You're ready to start your evolution.\nChoose a game mode or workout to begin.") },
};

void UFELOnboardingWidget::NativeConstruct()
{
	Super::NativeConstruct();

	CurrentStep = EOnboardingStep::Welcome;

	if (NextButton)
		NextButton->OnClicked.AddDynamic(this, &UFELOnboardingWidget::OnNextClicked);
	if (SkipButton)
		SkipButton->OnClicked.AddDynamic(this, &UFELOnboardingWidget::OnSkipClicked);

	UpdateStepDisplay();
}

void UFELOnboardingWidget::UpdateStepDisplay()
{
	int32 Idx = (int32)CurrentStep;

	if (StepSwitcher && Idx < StepSwitcher->GetNumWidgets())
		StepSwitcher->SetActiveWidgetIndex(Idx);

	if (Idx < UE_ARRAY_COUNT(StepContents))
	{
		if (StepTitleText)
			StepTitleText->SetText(FText::FromString(StepContents[Idx].Title));
		if (StepDescText)
			StepDescText->SetText(FText::FromString(StepContents[Idx].Description));
	}

	if (StepCounterText)
		StepCounterText->SetText(FText::FromString(
			FString::Printf(TEXT("%d / 6"), Idx + 1)));
}

void UFELOnboardingWidget::AdvanceStep()
{
	int32 Next = (int32)CurrentStep + 1;

	// Activate trial at the activation step
	if (CurrentStep == EOnboardingStep::AccountCreate)
		ActivateTrial();

	if (Next > (int32)EOnboardingStep::StartPlaying)
	{
		RemoveFromParent();
		return;
	}

	CurrentStep = (EOnboardingStep)Next;
	UpdateStepDisplay();
}

void UFELOnboardingWidget::SkipToGame()
{
	ActivateTrial();
	RemoveFromParent();
}

void UFELOnboardingWidget::ActivateTrial()
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELSubscriptionManager* SubMgr = GI->GetSubsystem<UFELSubscriptionManager>();
	if (!SubMgr) return;

	SubMgr->StartFreeTrial();
}

void UFELOnboardingWidget::OnNextClicked()
{
	AdvanceStep();
}

void UFELOnboardingWidget::OnSkipClicked()
{
	SkipToGame();
}
