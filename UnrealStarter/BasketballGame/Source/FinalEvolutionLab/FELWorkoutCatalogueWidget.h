// Copyright (c) Final Evolution Lab.
// UMG Widget: Browse workout programmes from the catalogue.
// Phase 3: Exercise Animation System — WBP_WorkoutCatalogue

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELWorkoutProgram.h"
#include "FELWorkoutCatalogueWidget.generated.h"

class UVerticalBox;
class UTextBlock;
class UButton;
class UImage;

UCLASS()
class FINALEVOLUTIONLAB_API UFELWorkoutCatalogueWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void RefreshProgramList();

	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void FilterByGoal(EWorkoutGoal Goal);

	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void SelectProgram(const FString& ProgramID);

protected:
	virtual void NativeConstruct() override;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UVerticalBox* ProgramListContainer;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* TitleText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* SelectedProgramName;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* SelectedProgramDescription;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* SelectedProgramStats;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* StartProgramButton;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* BackButton;

private:
	UFUNCTION()
	void OnStartProgramClicked();

	UFUNCTION()
	void OnBackClicked();

	FString SelectedProgramID;
};
