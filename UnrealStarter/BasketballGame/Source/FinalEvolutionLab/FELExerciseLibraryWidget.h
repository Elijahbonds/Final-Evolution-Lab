// Copyright (c) Final Evolution Lab.
// UMG Widget: Browse all 23 exercises with filtering.
// Phase 3: Exercise Animation System — WBP_ExerciseLibrary

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELExercise.h"
#include "FELExerciseLibraryWidget.generated.h"

class UVerticalBox;
class UTextBlock;
class UButton;
class UEditableTextBox;
class UComboBoxString;

UCLASS()
class FINALEVOLUTIONLAB_API UFELExerciseLibraryWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void RefreshExerciseList();

	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void FilterByCategory(EExerciseCategory Category);

	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void SearchExercises(const FString& Query);

	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void SelectExercise(const FString& ExerciseID);

protected:
	virtual void NativeConstruct() override;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UVerticalBox* ExerciseListContainer;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UEditableTextBox* SearchBox;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UComboBoxString* CategoryFilter;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* ExerciseNameText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* ExerciseDescText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* ExerciseStatsText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* ExerciseCountText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* PlayDemoButton;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* BackButton;

private:
	UFUNCTION()
	void OnSearchChanged(const FText& Text);

	UFUNCTION()
	void OnCategorySelected(FString SelectedItem, ESelectInfo::Type SelectionType);

	UFUNCTION()
	void OnPlayDemoClicked();

	FString SelectedExerciseID;
};
