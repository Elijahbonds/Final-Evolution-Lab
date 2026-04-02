// Copyright (c) Final Evolution Lab.
// UMG Widget: Active workout session tracking (WBP_WorkoutSession).
// Phase 3: Exercise Animation System

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELWorkoutProgram.h"
#include "FELWorkoutSessionWidget.generated.h"

class UTextBlock;
class UButton;
class UProgressBar;

UCLASS()
class FINALEVOLUTIONLAB_API UFELWorkoutSessionWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void UpdateSessionDisplay();

	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void OnCompleteExercise();

	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void OnEndSession();

protected:
	virtual void NativeConstruct() override;
	virtual void NativeTick(const FGeometry& MyGeometry, float InDeltaTime) override;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* SessionTitleText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* CurrentExerciseText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* SetsRepsText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* TimerText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* CaloriesText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* ProgressCountText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UProgressBar* SessionProgressBar;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* CompleteButton;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* EndSessionButton;
};
