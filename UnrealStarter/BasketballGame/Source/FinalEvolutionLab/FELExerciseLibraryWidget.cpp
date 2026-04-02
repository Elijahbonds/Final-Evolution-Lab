// Copyright (c) Final Evolution Lab.

#include "FELExerciseLibraryWidget.h"
#include "FELExerciseManager.h"
#include "Components/VerticalBox.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/EditableTextBox.h"
#include "Components/ComboBoxString.h"

void UFELExerciseLibraryWidget::NativeConstruct()
{
	Super::NativeConstruct();

	if (CategoryFilter)
	{
		CategoryFilter->AddOption(TEXT("All"));
		CategoryFilter->AddOption(TEXT("Warm-Up"));
		CategoryFilter->AddOption(TEXT("Strength"));
		CategoryFilter->AddOption(TEXT("Mobility"));
		CategoryFilter->AddOption(TEXT("Plyometrics"));
		CategoryFilter->AddOption(TEXT("Recovery"));
		CategoryFilter->SetSelectedOption(TEXT("All"));
		CategoryFilter->OnSelectionChanged.AddDynamic(this, &UFELExerciseLibraryWidget::OnCategorySelected);
	}

	if (PlayDemoButton)
		PlayDemoButton->OnClicked.AddDynamic(this, &UFELExerciseLibraryWidget::OnPlayDemoClicked);

	RefreshExerciseList();
}

void UFELExerciseLibraryWidget::RefreshExerciseList()
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELExerciseManager* Mgr = GI->GetSubsystem<UFELExerciseManager>();
	if (!Mgr) return;

	TArray<FExerciseData> All = Mgr->GetAllExercises();

	if (ExerciseCountText)
		ExerciseCountText->SetText(FText::FromString(
			FString::Printf(TEXT("%d exercises"), All.Num())));
}

void UFELExerciseLibraryWidget::FilterByCategory(EExerciseCategory Category)
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELExerciseManager* Mgr = GI->GetSubsystem<UFELExerciseManager>();
	if (!Mgr) return;

	TArray<FExerciseData> Filtered = Mgr->GetExercisesByCategory(Category);
	// Update exercise list container with filtered items
}

void UFELExerciseLibraryWidget::SearchExercises(const FString& Query)
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELExerciseManager* Mgr = GI->GetSubsystem<UFELExerciseManager>();
	if (!Mgr) return;

	TArray<FExerciseData> Results = Mgr->SearchExercises(Query);
	// Update exercise list container with results
}

void UFELExerciseLibraryWidget::SelectExercise(const FString& ExerciseID)
{
	SelectedExerciseID = ExerciseID;

	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELExerciseManager* Mgr = GI->GetSubsystem<UFELExerciseManager>();
	if (!Mgr) return;

	FExerciseData Ex;
	if (Mgr->GetExerciseByID(ExerciseID, Ex))
	{
		if (ExerciseNameText)
			ExerciseNameText->SetText(FText::FromString(Ex.DisplayName));
		if (ExerciseDescText)
			ExerciseDescText->SetText(FText::FromString(Ex.Description));

		FExerciseProgress Prog = Mgr->GetExerciseProgress(ExerciseID);
		if (ExerciseStatsText)
		{
			FString Stats = FString::Printf(
				TEXT("%d completions · %.0f calories · %d sets x %d reps"),
				Prog.TotalCompletions, Prog.TotalCaloriesBurned,
				Ex.DefaultSets, Ex.DefaultReps);
			ExerciseStatsText->SetText(FText::FromString(Stats));
		}
	}
}

void UFELExerciseLibraryWidget::OnSearchChanged(const FText& Text)
{
	SearchExercises(Text.ToString());
}

void UFELExerciseLibraryWidget::OnCategorySelected(FString SelectedItem, ESelectInfo::Type SelectionType)
{
	if (SelectedItem == TEXT("All"))
		RefreshExerciseList();
	else if (SelectedItem == TEXT("Warm-Up"))
		FilterByCategory(EExerciseCategory::WarmUp);
	else if (SelectedItem == TEXT("Strength"))
		FilterByCategory(EExerciseCategory::Strength);
	else if (SelectedItem == TEXT("Mobility"))
		FilterByCategory(EExerciseCategory::Mobility);
	else if (SelectedItem == TEXT("Plyometrics"))
		FilterByCategory(EExerciseCategory::Plyometrics);
	else if (SelectedItem == TEXT("Recovery"))
		FilterByCategory(EExerciseCategory::Recovery);
}

void UFELExerciseLibraryWidget::OnPlayDemoClicked()
{
	if (SelectedExerciseID.IsEmpty()) return;

	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELExerciseManager* Mgr = GI->GetSubsystem<UFELExerciseManager>();
	if (!Mgr) return;

	Mgr->LoadExerciseAnimation(SelectedExerciseID);
}
