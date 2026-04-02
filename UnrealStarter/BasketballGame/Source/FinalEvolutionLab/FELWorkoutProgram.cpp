// Copyright (c) Final Evolution Lab.
// Workout program manager implementation.

#include "FELWorkoutProgram.h"
#include "FELExerciseManager.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Misc/Guid.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"

DEFINE_LOG_CATEGORY_STATIC(LogFELWorkout, Log, All);

/* ─────────────────────────  helpers  ─────────────────────────────── */

static EWorkoutGoal ParseGoal(const FString& S)
{
	if (S == TEXT("strength"))       return EWorkoutGoal::Strength;
	if (S == TEXT("hypertrophy"))    return EWorkoutGoal::Hypertrophy;
	if (S == TEXT("endurance"))      return EWorkoutGoal::Endurance;
	if (S == TEXT("athletic"))       return EWorkoutGoal::Athletic;
	if (S == TEXT("mobility"))       return EWorkoutGoal::Mobility;
	if (S == TEXT("vertical_jump"))  return EWorkoutGoal::VerticalJump;
	return EWorkoutGoal::Athletic;
}

static EExerciseDifficulty ParseLevel(const FString& S)
{
	if (S == TEXT("beginner"))       return EExerciseDifficulty::Beginner;
	if (S == TEXT("intermediate"))   return EExerciseDifficulty::Intermediate;
	if (S == TEXT("advanced"))       return EExerciseDifficulty::Advanced;
	if (S == TEXT("elite"))          return EExerciseDifficulty::Elite;
	return EExerciseDifficulty::Intermediate;
}

static EPeriodization ParsePeriodization(const FString& S)
{
	if (S == TEXT("linear"))     return EPeriodization::Linear;
	if (S == TEXT("undulating")) return EPeriodization::Undulating;
	if (S == TEXT("block"))      return EPeriodization::Block;
	return EPeriodization::Linear;
}

/* ─────────────────────────  lifecycle  ───────────────────────────── */

void UFELWorkoutProgramManager::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	LoadCatalogues();
	UE_LOG(LogFELWorkout, Log, TEXT("WorkoutProgramManager: loaded %d programs."), ProgramDB.Num());
}

void UFELWorkoutProgramManager::Deinitialize()
{
	SaveUserPrograms();
	Super::Deinitialize();
}

/* ─────────────────────────  catalogue load  ──────────────────────── */

void UFELWorkoutProgramManager::LoadCatalogues()
{
	FString JsonPath = FPaths::ProjectContentDir() / TEXT("FEL/Data/WorkoutCatalogues.json");
	FString JsonStr;
	if (!FFileHelper::LoadFileToString(JsonStr, *JsonPath))
	{
		UE_LOG(LogFELWorkout, Warning, TEXT("WorkoutProgramManager: cannot read %s"), *JsonPath);
		return;
	}

	TSharedPtr<FJsonObject> Root;
	if (!FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(JsonStr), Root) || !Root.IsValid()) return;

	const TArray<TSharedPtr<FJsonValue>>* Programs;
	if (!Root->TryGetArrayField(TEXT("programs"), Programs)) return;

	for (auto& PVal : *Programs)
	{
		const TSharedPtr<FJsonObject>& PObj = PVal->AsObject();
		FWorkoutProgram Prog;
		PObj->TryGetStringField(TEXT("id"), Prog.ProgramID);
		PObj->TryGetStringField(TEXT("name"), Prog.ProgramName);
		PObj->TryGetStringField(TEXT("description"), Prog.Description);

		double D;
		if (PObj->TryGetNumberField(TEXT("durationWeeks"), D)) Prog.DurationWeeks = (int32)D;
		if (PObj->TryGetNumberField(TEXT("daysPerWeek"), D)) Prog.DaysPerWeek = (int32)D;

		FString GoalStr, LevelStr, PeriodStr;
		PObj->TryGetStringField(TEXT("goal"), GoalStr);
		PObj->TryGetStringField(TEXT("level"), LevelStr);
		PObj->TryGetStringField(TEXT("periodization"), PeriodStr);
		Prog.Goal = ParseGoal(GoalStr);
		Prog.Level = ParseLevel(LevelStr);
		Prog.Periodization = ParsePeriodization(PeriodStr);

		// parse weeks -> days -> exercises
		const TArray<TSharedPtr<FJsonValue>>* Weeks;
		if (PObj->TryGetArrayField(TEXT("weeks"), Weeks))
		{
			for (auto& WVal : *Weeks)
			{
				const TSharedPtr<FJsonObject>& WObj = WVal->AsObject();
				FWorkoutWeek Week;
				if (WObj->TryGetNumberField(TEXT("weekNumber"), D)) Week.WeekNumber = (int32)D;
				WObj->TryGetBoolField(TEXT("isDeload"), Week.bIsDeloadWeek);
				if (WObj->TryGetNumberField(TEXT("intensityModifier"), D)) Week.IntensityModifier = (float)D;

				const TArray<TSharedPtr<FJsonValue>>* Days;
				if (WObj->TryGetArrayField(TEXT("days"), Days))
				{
					for (auto& DVal : *Days)
					{
						const TSharedPtr<FJsonObject>& DObj = DVal->AsObject();
						FWorkoutDay Day;
						DObj->TryGetStringField(TEXT("dayName"), Day.DayName);
						if (DObj->TryGetNumberField(TEXT("estimatedDuration"), D)) Day.EstimatedDuration = (int32)D;

						const TArray<TSharedPtr<FJsonValue>>* Exs;
						if (DObj->TryGetArrayField(TEXT("exercises"), Exs))
						{
							for (auto& EVal : *Exs)
							{
								const TSharedPtr<FJsonObject>& EObj = EVal->AsObject();
								FExerciseSet ES;
								EObj->TryGetStringField(TEXT("exerciseID"), ES.ExerciseID);
								if (EObj->TryGetNumberField(TEXT("sets"), D)) ES.Sets = (int32)D;
								if (EObj->TryGetNumberField(TEXT("reps"), D)) ES.Reps = (int32)D;
								if (EObj->TryGetNumberField(TEXT("restTime"), D)) ES.RestTime = (float)D;
								if (EObj->TryGetNumberField(TEXT("weight"), D)) ES.Weight = (float)D;
								EObj->TryGetStringField(TEXT("notes"), ES.Notes);
								Day.Exercises.Add(ES);
							}
						}
						Week.Days.Add(Day);
					}
				}
				Prog.Weeks.Add(Week);
			}
		}

		ProgramDB.Add(Prog.ProgramID, Prog);
	}
}

void UFELWorkoutProgramManager::SaveUserPrograms()
{
	// Save custom programs created by user to Saved/FEL/
	TSharedPtr<FJsonObject> Root = MakeShared<FJsonObject>();
	TArray<TSharedPtr<FJsonValue>> Arr;
	for (auto& Pair : ProgramDB)
	{
		if (Pair.Key.StartsWith(TEXT("custom_")))
		{
			TSharedPtr<FJsonObject> Obj = MakeShared<FJsonObject>();
			Obj->SetStringField(TEXT("id"), Pair.Value.ProgramID);
			Obj->SetStringField(TEXT("name"), Pair.Value.ProgramName);
			Arr.Add(MakeShared<FJsonValueObject>(Obj));
		}
	}
	Root->SetArrayField(TEXT("customPrograms"), Arr);

	FString Out;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&Out);
	FJsonSerializer::Serialize(Root.ToSharedRef(), Writer);

	FString Path = FPaths::ProjectSavedDir() / TEXT("FEL/custom_programs.json");
	FFileHelper::SaveStringToFile(Out, *Path);
}

/* ─────────────────────────  catalogue queries  ───────────────────── */

TArray<FWorkoutProgram> UFELWorkoutProgramManager::GetAllPrograms() const
{
	TArray<FWorkoutProgram> Result;
	ProgramDB.GenerateValueArray(Result);
	return Result;
}

bool UFELWorkoutProgramManager::GetProgramByID(const FString& ProgramID, FWorkoutProgram& OutProgram) const
{
	const FWorkoutProgram* P = ProgramDB.Find(ProgramID);
	if (P) { OutProgram = *P; return true; }
	return false;
}

TArray<FWorkoutProgram> UFELWorkoutProgramManager::GetProgramsByGoal(EWorkoutGoal Goal) const
{
	TArray<FWorkoutProgram> Result;
	for (auto& Pair : ProgramDB)
		if (Pair.Value.Goal == Goal)
			Result.Add(Pair.Value);
	return Result;
}

/* ─────────────────────────  active session  ──────────────────────── */

bool UFELWorkoutProgramManager::StartWorkoutSession(const FString& ProgramID, int32 WeekIndex, int32 DayIndex)
{
	const FWorkoutProgram* Prog = ProgramDB.Find(ProgramID);
	if (!Prog) return false;
	if (!Prog->Weeks.IsValidIndex(WeekIndex)) return false;
	if (!Prog->Weeks[WeekIndex].Days.IsValidIndex(DayIndex)) return false;

	ActiveSession = FActiveWorkoutSession();
	ActiveSession.SessionID = FGuid::NewGuid().ToString();
	ActiveSession.ProgramID = ProgramID;
	ActiveSession.CurrentWeek = WeekIndex;
	ActiveSession.CurrentDay = DayIndex;
	ActiveSession.CurrentExerciseIndex = 0;
	ActiveSession.bIsActive = true;

	UE_LOG(LogFELWorkout, Log, TEXT("Started workout session %s (program=%s, week=%d, day=%d)"),
		*ActiveSession.SessionID, *ProgramID, WeekIndex, DayIndex);

	return true;
}

void UFELWorkoutProgramManager::CompleteCurrentExercise(int32 ActualReps, float ActualWeight)
{
	if (!ActiveSession.bIsActive) return;

	const FWorkoutProgram* Prog = ProgramDB.Find(ActiveSession.ProgramID);
	if (!Prog) return;

	const FWorkoutDay& Day = Prog->Weeks[ActiveSession.CurrentWeek].Days[ActiveSession.CurrentDay];
	if (ActiveSession.CurrentExerciseIndex >= Day.Exercises.Num()) return;

	const FExerciseSet& Ex = Day.Exercises[ActiveSession.CurrentExerciseIndex];

	// Record through exercise manager
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELExerciseManager* ExMgr = GI->GetSubsystem<UFELExerciseManager>())
		{
			ExMgr->RecordExerciseCompletion(Ex.ExerciseID, ActualReps, ActualWeight, Ex.RestTime / 60.f);
		}
	}

	ActiveSession.ExercisesCompleted++;
	ActiveSession.CurrentExerciseIndex++;

	UE_LOG(LogFELWorkout, Log, TEXT("Completed exercise %d/%d in session %s"),
		ActiveSession.ExercisesCompleted, Day.Exercises.Num(), *ActiveSession.SessionID);
}

void UFELWorkoutProgramManager::EndWorkoutSession()
{
	if (!ActiveSession.bIsActive) return;

	UE_LOG(LogFELWorkout, Log, TEXT("Ended workout session %s — %d exercises, %.1f cal"),
		*ActiveSession.SessionID, ActiveSession.ExercisesCompleted, ActiveSession.TotalCaloriesBurned);

	ActiveSession.bIsActive = false;
}

/* ─────────────────────────  progressive overload  ────────────────── */

FExerciseSet UFELWorkoutProgramManager::CalculateProgressiveOverload(const FExerciseSet& Previous, EPeriodization Scheme) const
{
	FExerciseSet Next = Previous;

	switch (Scheme)
	{
	case EPeriodization::Linear:
		// Add 2.5-5% weight each week
		if (Previous.Weight > 0.f)
			Next.Weight = Previous.Weight * 1.025f;
		else
			Next.Reps = FMath::Min(Previous.Reps + 1, 20);
		break;

	case EPeriodization::Undulating:
		// Alternate heavy/light/moderate within the week
		if (Previous.Reps <= 6)
		{
			Next.Reps = 12;
			Next.Weight = Previous.Weight * 0.7f;
		}
		else if (Previous.Reps <= 12)
		{
			Next.Reps = 8;
			Next.Weight = Previous.Weight * 1.1f;
		}
		else
		{
			Next.Reps = 5;
			Next.Weight = Previous.Weight * 1.2f;
		}
		break;

	case EPeriodization::Block:
		// Add volume (sets) rather than weight
		Next.Sets = FMath::Min(Previous.Sets + 1, 6);
		break;
	}

	return Next;
}

/* ─────────────────────────  custom builder  ──────────────────────── */

FWorkoutProgram UFELWorkoutProgramManager::CreateCustomProgram(const FString& Name, EWorkoutGoal Goal, const TArray<FWorkoutDay>& Days)
{
	FWorkoutProgram Prog;
	Prog.ProgramID = FString::Printf(TEXT("custom_%s"), *FGuid::NewGuid().ToString());
	Prog.ProgramName = Name;
	Prog.Goal = Goal;
	Prog.DurationWeeks = 1;
	Prog.DaysPerWeek = Days.Num();

	FWorkoutWeek Week;
	Week.WeekNumber = 1;
	Week.Days = Days;
	Prog.Weeks.Add(Week);

	ProgramDB.Add(Prog.ProgramID, Prog);
	SaveUserPrograms();

	return Prog;
}
