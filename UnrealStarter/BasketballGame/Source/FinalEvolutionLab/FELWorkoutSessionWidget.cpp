// Copyright (c) Final Evolution Lab.

#include "FELWorkoutSessionWidget.h"
#include "FELExerciseManager.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/ProgressBar.h"

void UFELWorkoutSessionWidget::NativeConstruct()
{
	Super::NativeConstruct();

	if (CompleteButton)
		CompleteButton->OnClicked.AddDynamic(this, &UFELWorkoutSessionWidget::OnCompleteExercise);
	if (EndSessionButton)
		EndSessionButton->OnClicked.AddDynamic(this, &UFELWorkoutSessionWidget::OnEndSession);

	UpdateSessionDisplay();
}

void UFELWorkoutSessionWidget::NativeTick(const FGeometry& MyGeometry, float InDeltaTime)
{
	Super::NativeTick(MyGeometry, InDeltaTime);

	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELWorkoutProgramManager* Mgr = GI->GetSubsystem<UFELWorkoutProgramManager>();
	if (!Mgr || !Mgr->IsWorkoutActive()) return;

	FActiveWorkoutSession Session = Mgr->GetActiveSession();

	if (TimerText)
	{
		int32 Mins = (int32)(Session.ElapsedSeconds / 60.f);
		int32 Secs = (int32)FMath::Fmod(Session.ElapsedSeconds, 60.f);
		TimerText->SetText(FText::FromString(
			FString::Printf(TEXT("%02d:%02d"), Mins, Secs)));
	}

	if (CaloriesText)
		CaloriesText->SetText(FText::FromString(
			FString::Printf(TEXT("%.0f cal"), Session.TotalCaloriesBurned)));
}

void UFELWorkoutSessionWidget::UpdateSessionDisplay()
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELWorkoutProgramManager* WMgr = GI->GetSubsystem<UFELWorkoutProgramManager>();
	if (!WMgr || !WMgr->IsWorkoutActive()) return;

	FActiveWorkoutSession Session = WMgr->GetActiveSession();

	FWorkoutProgram Prog;
	if (!WMgr->GetProgramByID(Session.ProgramID, Prog)) return;

	if (SessionTitleText)
		SessionTitleText->SetText(FText::FromString(Prog.ProgramName));

	const FWorkoutDay& Day = Prog.Weeks[Session.CurrentWeek].Days[Session.CurrentDay];

	if (Session.CurrentExerciseIndex < Day.Exercises.Num())
	{
		const FExerciseSet& CurEx = Day.Exercises[Session.CurrentExerciseIndex];

		UFELExerciseManager* ExMgr = GI->GetSubsystem<UFELExerciseManager>();
		FExerciseData ExData;
		FString DisplayName = CurEx.ExerciseID;
		if (ExMgr && ExMgr->GetExerciseByID(CurEx.ExerciseID, ExData))
			DisplayName = ExData.DisplayName;

		if (CurrentExerciseText)
			CurrentExerciseText->SetText(FText::FromString(DisplayName));
		if (SetsRepsText)
			SetsRepsText->SetText(FText::FromString(
				FString::Printf(TEXT("%d sets x %d reps"), CurEx.Sets, CurEx.Reps)));
	}

	if (ProgressCountText)
		ProgressCountText->SetText(FText::FromString(
			FString::Printf(TEXT("%d / %d exercises"),
				Session.ExercisesCompleted, Day.Exercises.Num())));

	if (SessionProgressBar && Day.Exercises.Num() > 0)
		SessionProgressBar->SetPercent(
			(float)Session.ExercisesCompleted / (float)Day.Exercises.Num());
}

void UFELWorkoutSessionWidget::OnCompleteExercise()
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELWorkoutProgramManager* Mgr = GI->GetSubsystem<UFELWorkoutProgramManager>();
	if (!Mgr) return;

	Mgr->CompleteCurrentExercise(0, 0.f);
	UpdateSessionDisplay();
}

void UFELWorkoutSessionWidget::OnEndSession()
{
	UGameInstance* GI = GetGameInstance();
	if (!GI) return;
	UFELWorkoutProgramManager* Mgr = GI->GetSubsystem<UFELWorkoutProgramManager>();
	if (!Mgr) return;

	Mgr->EndWorkoutSession();
	RemoveFromParent();
}
