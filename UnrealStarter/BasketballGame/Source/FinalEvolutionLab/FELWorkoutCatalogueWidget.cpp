// Copyright (c) Final Evolution Lab.

#include "FELWorkoutCatalogueWidget.h"
#include "Components/VerticalBox.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Kismet/GameplayStatics.h"

void UFELWorkoutCatalogueWidget::NativeConstruct()
{
	Super::NativeConstruct();

	if (TitleText)
		TitleText->SetText(FText::FromString(TEXT("WORKOUT PROGRAMS")));

	if (StartProgramButton)
		StartProgramButton->OnClicked.AddDynamic(this, &UFELWorkoutCatalogueWidget::OnStartProgramClicked);
	if (BackButton)
		BackButton->OnClicked.AddDynamic(this, &UFELWorkoutCatalogueWidget::OnBackClicked);

	RefreshProgramList();
}

void UFELWorkoutCatalogueWidget::RefreshProgramList()
{
	if (!ProgramListContainer) return;

	UGameInstance* GI = GetGameInstance();
	if (!GI) return;

	UFELWorkoutProgramManager* Mgr = GI->GetSubsystem<UFELWorkoutProgramManager>();
	if (!Mgr) return;

	TArray<FWorkoutProgram> Programs = Mgr->GetAllPrograms();

	// Populate list (in Blueprint, each item would be a sub-widget)
	for (const FWorkoutProgram& Prog : Programs)
	{
		UE_LOG(LogTemp, Log, TEXT("Catalogue: %s (%d weeks, %d days/wk)"),
			*Prog.ProgramName, Prog.DurationWeeks, Prog.DaysPerWeek);
	}
}

void UFELWorkoutCatalogueWidget::FilterByGoal(EWorkoutGoal Goal)
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELWorkoutProgramManager* Mgr = GI->GetSubsystem<UFELWorkoutProgramManager>();
	if (!Mgr) return;

	TArray<FWorkoutProgram> Filtered = Mgr->GetProgramsByGoal(Goal);
	// Update UI with filtered list
}

void UFELWorkoutCatalogueWidget::SelectProgram(const FString& ProgramID)
{
	SelectedProgramID = ProgramID;

	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELWorkoutProgramManager* Mgr = GI->GetSubsystem<UFELWorkoutProgramManager>();
	if (!Mgr) return;

	FWorkoutProgram Prog;
	if (Mgr->GetProgramByID(ProgramID, Prog))
	{
		if (SelectedProgramName)
			SelectedProgramName->SetText(FText::FromString(Prog.ProgramName));
		if (SelectedProgramDescription)
			SelectedProgramDescription->SetText(FText::FromString(Prog.Description));
		if (SelectedProgramStats)
		{
			FString Stats = FString::Printf(TEXT("%d weeks · %d days/week"),
				Prog.DurationWeeks, Prog.DaysPerWeek);
			SelectedProgramStats->SetText(FText::FromString(Stats));
		}
	}
}

void UFELWorkoutCatalogueWidget::OnStartProgramClicked()
{
	if (SelectedProgramID.IsEmpty()) return;

	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELWorkoutProgramManager* Mgr = GI->GetSubsystem<UFELWorkoutProgramManager>();
	if (!Mgr) return;

	Mgr->StartWorkoutSession(SelectedProgramID, 0, 0);
}

void UFELWorkoutCatalogueWidget::OnBackClicked()
{
	RemoveFromParent();
}
