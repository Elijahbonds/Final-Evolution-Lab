// Copyright (c) Final Evolution Lab.
// UMG Widget: First-time user onboarding flow.
// Phase 3: Integration

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELOnboardingWidget.generated.h"

class UTextBlock;
class UButton;
class UWidgetSwitcher;
class UImage;

UENUM(BlueprintType)
enum class EOnboardingStep : uint8
{
	Welcome,
	TrialExplain,
	AccountCreate,
	TrialActivation,
	Tutorial,
	StartPlaying
};

UCLASS()
class FINALEVOLUTIONLAB_API UFELOnboardingWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void AdvanceStep();

	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void SkipToGame();

protected:
	virtual void NativeConstruct() override;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UWidgetSwitcher* StepSwitcher;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* StepTitleText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* StepDescText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* NextButton;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* SkipButton;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* StepCounterText;

private:
	UFUNCTION()
	void OnNextClicked();

	UFUNCTION()
	void OnSkipClicked();

	void UpdateStepDisplay();
	void ActivateTrial();

	EOnboardingStep CurrentStep = EOnboardingStep::Welcome;
};
