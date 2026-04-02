// Copyright (c) Final Evolution Lab.
// Personalized workout recommendation implementation.
// Phase 5: OpenCap Body Scanning

#include "FELPersonalizedWorkouts.h"
#include "Misc/Guid.h"

void UFELPersonalizedWorkouts::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	UE_LOG(LogTemp, Log, TEXT("[FEL-Workouts] Personalized workout subsystem initialized."));
}

void UFELPersonalizedWorkouts::Deinitialize()
{
	ActivePlans.Empty();
	CompletedWorkouts.Empty();
	Super::Deinitialize();
}

/* ─────────────  Workout Generation  ────────────────────────────── */

FPersonalizedWorkout UFELPersonalizedWorkouts::GenerateWorkout(
	const FString& UserID, ETrainingGoal Goal,
	const FPerformanceMetrics& Metrics, const FInjuryRiskAssessment& RiskData)
{
	FPersonalizedWorkout Workout;
	Workout.WorkoutID = GenerateWorkoutID();
	Workout.PrimaryGoal = Goal;
	Workout.GeneratedDate = FDateTime::UtcNow();

	switch (Goal)
	{
	case ETrainingGoal::VerticalJump:
		Workout.WorkoutName = TEXT("Vertical Explosion");
		Workout.EstimatedDurationMin = 50;
		Workout.FocusAreas = {TEXT("Hip power"), TEXT("Ankle stiffness"), TEXT("Triple extension")};
		break;
	case ETrainingGoal::Speed:
		Workout.WorkoutName = TEXT("Speed Machine");
		Workout.EstimatedDurationMin = 45;
		Workout.FocusAreas = {TEXT("Sprint mechanics"), TEXT("Acceleration"), TEXT("Stride frequency")};
		break;
	case ETrainingGoal::Agility:
		Workout.WorkoutName = TEXT("Quick Change");
		Workout.EstimatedDurationMin = 40;
		Workout.FocusAreas = {TEXT("Lateral movement"), TEXT("Deceleration"), TEXT("Reactive agility")};
		break;
	case ETrainingGoal::Strength:
		Workout.WorkoutName = TEXT("Iron Foundation");
		Workout.EstimatedDurationMin = 60;
		Workout.FocusAreas = {TEXT("Compound lifts"), TEXT("Core stability"), TEXT("Progressive overload")};
		break;
	case ETrainingGoal::Flexibility:
		Workout.WorkoutName = TEXT("Mobility Master");
		Workout.EstimatedDurationMin = 35;
		Workout.FocusAreas = {TEXT("Joint ROM"), TEXT("Dynamic flexibility"), TEXT("Tissue quality")};
		break;
	default:
		Workout.WorkoutName = TEXT("Complete Athlete");
		Workout.EstimatedDurationMin = 45;
		Workout.FocusAreas = {TEXT("Balanced development"), TEXT("Movement quality")};
		break;
	}

	// Add limitations from risk assessment
	for (const FInjuryRiskFactor& Factor : RiskData.RiskFactors)
	{
		if (Factor.RiskLevel >= EInjuryRiskLevel::High)
		{
			Workout.Limitations.Add(FString::Printf(TEXT("Avoid heavy loading on %s"),
				*UEnum::GetValueAsString(Factor.Region)));
		}
	}

	Workout.WarmUp = GenerateWarmUpBlock(RiskData);
	Workout.MainExercises = GenerateMainBlock(Goal, Metrics, RiskData);
	Workout.CoolDown = GenerateCoolDownBlock();

	OnWorkoutGenerated.Broadcast(Workout);

	UE_LOG(LogTemp, Log, TEXT("[FEL-Workouts] Generated '%s' for %s (%d min)"),
		*Workout.WorkoutName, *UserID, Workout.EstimatedDurationMin);
	return Workout;
}

FTrainingPlan UFELPersonalizedWorkouts::GenerateTrainingPlan(
	const FString& UserID, ETrainingGoal Goal,
	int32 DurationWeeks, int32 SessionsPerWeek,
	const FPerformanceMetrics& Metrics, const FInjuryRiskAssessment& RiskData)
{
	FTrainingPlan Plan;
	Plan.PlanID = FString::Printf(TEXT("PLAN-%s"), *FGuid::NewGuid().ToString(EGuidFormats::Short));
	Plan.Goal = Goal;
	Plan.DurationWeeks = DurationWeeks;
	Plan.SessionsPerWeek = SessionsPerWeek;
	Plan.CurrentWeek = 1;

	switch (Goal)
	{
	case ETrainingGoal::VerticalJump: Plan.PlanName = TEXT("Vertical Jump Program"); break;
	case ETrainingGoal::Speed:        Plan.PlanName = TEXT("Speed Development"); break;
	case ETrainingGoal::Strength:     Plan.PlanName = TEXT("Strength Builder"); break;
	default:                           Plan.PlanName = TEXT("Athlete Development"); break;
	}

	// Generate workouts for the plan
	for (int32 i = 0; i < SessionsPerWeek; ++i)
	{
		FPersonalizedWorkout W = GenerateWorkout(UserID, Goal, Metrics, RiskData);
		Plan.WeeklyWorkouts.Add(W);
	}

	ActivePlans.Add(UserID, Plan);
	OnPlanCreated.Broadcast(Plan);

	UE_LOG(LogTemp, Log, TEXT("[FEL-Workouts] Generated %d-week plan '%s' for %s"),
		DurationWeeks, *Plan.PlanName, *UserID);
	return Plan;
}

/* ─────────────  Plan Management  ────────────────────────────────── */

FTrainingPlan UFELPersonalizedWorkouts::GetActivePlan(const FString& UserID) const
{
	if (const auto* P = ActivePlans.Find(UserID)) return *P;
	return FTrainingPlan();
}

void UFELPersonalizedWorkouts::AdvanceToNextWeek(const FString& UserID)
{
	if (auto* Plan = ActivePlans.Find(UserID))
	{
		if (Plan->CurrentWeek < Plan->DurationWeeks)
		{
			Plan->CurrentWeek++;
			Plan->ProgressPercent = (float)Plan->CurrentWeek / Plan->DurationWeeks * 100.f;
			UE_LOG(LogTemp, Log, TEXT("[FEL-Workouts] %s advanced to week %d/%d"),
				*UserID, Plan->CurrentWeek, Plan->DurationWeeks);
		}
	}
}

FPersonalizedWorkout UFELPersonalizedWorkouts::GetTodaysWorkout(const FString& UserID) const
{
	if (const auto* Plan = ActivePlans.Find(UserID))
	{
		if (Plan->WeeklyWorkouts.Num() > 0)
		{
			// Simple rotation based on day of week
			int32 DayIndex = (int32)FDateTime::Now().GetDayOfWeek() % Plan->WeeklyWorkouts.Num();
			return Plan->WeeklyWorkouts[DayIndex];
		}
	}
	return FPersonalizedWorkout();
}

void UFELPersonalizedWorkouts::RecordWorkoutCompletion(const FString& UserID, const FString& WorkoutID)
{
	if (!CompletedWorkouts.Contains(UserID))
	{
		CompletedWorkouts.Add(UserID, TArray<FString>());
	}
	CompletedWorkouts[UserID].Add(WorkoutID);
}

void UFELPersonalizedWorkouts::AdjustIntensityBasedOnRecovery(const FString& UserID, EFatigueLevel Fatigue)
{
	if (auto* Plan = ActivePlans.Find(UserID))
	{
		float Multiplier = 1.0f;
		switch (Fatigue)
		{
		case EFatigueLevel::Fresh:    Multiplier = 1.0f;  break;
		case EFatigueLevel::Mild:     Multiplier = 0.9f;  break;
		case EFatigueLevel::Moderate:  Multiplier = 0.75f; break;
		case EFatigueLevel::High:     Multiplier = 0.6f;  break;
		case EFatigueLevel::Exhausted: Multiplier = 0.4f;  break;
		}

		for (FPersonalizedWorkout& W : Plan->WeeklyWorkouts)
		{
			for (FExercisePrescription& E : W.MainExercises)
			{
				E.IntensityPercent = FMath::Clamp(E.IntensityPercent * Multiplier, 30.f, 100.f);
			}
		}
	}
}

/* ─────────────  Internal Generators  ────────────────────────────── */

TArray<FExercisePrescription> UFELPersonalizedWorkouts::GenerateWarmUpBlock(
	const FInjuryRiskAssessment& RiskData) const
{
	TArray<FExercisePrescription> WarmUp;

	{ FExercisePrescription E; E.ExerciseID = TEXT("warmup_jog"); E.ExerciseName = TEXT("Light Jog"); E.Sets = 1; E.Reps = 1; E.RestSeconds = 0; E.IntensityPercent = 40.f; E.Rationale = TEXT("Increase core temperature"); WarmUp.Add(E); }
	{ FExercisePrescription E; E.ExerciseID = TEXT("warmup_dynamic_stretch"); E.ExerciseName = TEXT("Dynamic Stretching"); E.Sets = 1; E.Reps = 10; E.RestSeconds = 0; E.IntensityPercent = 30.f; E.Rationale = TEXT("Prepare joints for movement"); WarmUp.Add(E); }
	{ FExercisePrescription E; E.ExerciseID = TEXT("warmup_activation"); E.ExerciseName = TEXT("Glute & Core Activation"); E.Sets = 2; E.Reps = 10; E.RestSeconds = 30; E.IntensityPercent = 50.f; E.Rationale = TEXT("Activate key stabilizers"); WarmUp.Add(E); }

	return WarmUp;
}

TArray<FExercisePrescription> UFELPersonalizedWorkouts::GenerateMainBlock(
	ETrainingGoal Goal, const FPerformanceMetrics& Metrics,
	const FInjuryRiskAssessment& RiskData) const
{
	TArray<FExercisePrescription> Main;

	switch (Goal)
	{
	case ETrainingGoal::VerticalJump:
	{
		{ FExercisePrescription E; E.ExerciseID = TEXT("depth_jump"); E.ExerciseName = TEXT("Depth Jumps"); E.Sets = 4; E.Reps = 5; E.RestSeconds = 120; E.IntensityPercent = 90.f; E.Rationale = TEXT("Develop reactive strength"); E.AlternativeExerciseID = TEXT("box_jump"); Main.Add(E); }
		{ FExercisePrescription E; E.ExerciseID = TEXT("squat_jump"); E.ExerciseName = TEXT("Squat Jumps"); E.Sets = 3; E.Reps = 8; E.RestSeconds = 90; E.IntensityPercent = 85.f; E.Rationale = TEXT("Build explosive hip power"); Main.Add(E); }
		{ FExercisePrescription E; E.ExerciseID = TEXT("calf_raise_explosive"); E.ExerciseName = TEXT("Explosive Calf Raises"); E.Sets = 3; E.Reps = 12; E.RestSeconds = 60; E.IntensityPercent = 75.f; E.Rationale = TEXT("Ankle stiffness for takeoff"); Main.Add(E); }
		{ FExercisePrescription E; E.ExerciseID = TEXT("single_leg_hip_thrust"); E.ExerciseName = TEXT("Single-Leg Hip Thrusts"); E.Sets = 3; E.Reps = 10; E.RestSeconds = 60; E.IntensityPercent = 70.f; E.Rationale = TEXT("Posterior chain power"); Main.Add(E); }
		break;
	}
	case ETrainingGoal::Speed:
	{
		{ FExercisePrescription E; E.ExerciseID = TEXT("sprint_20m"); E.ExerciseName = TEXT("20m Sprints"); E.Sets = 6; E.Reps = 1; E.RestSeconds = 180; E.IntensityPercent = 95.f; E.Rationale = TEXT("Develop acceleration"); Main.Add(E); }
		{ FExercisePrescription E; E.ExerciseID = TEXT("a_skip"); E.ExerciseName = TEXT("A-Skips"); E.Sets = 3; E.Reps = 20; E.RestSeconds = 60; E.IntensityPercent = 70.f; E.Rationale = TEXT("Improve stride mechanics"); Main.Add(E); }
		{ FExercisePrescription E; E.ExerciseID = TEXT("sled_push"); E.ExerciseName = TEXT("Sled Pushes"); E.Sets = 4; E.Reps = 1; E.RestSeconds = 120; E.IntensityPercent = 80.f; E.Rationale = TEXT("Horizontal force production"); E.AlternativeExerciseID = TEXT("hill_sprint"); Main.Add(E); }
		break;
	}
	default:
	{
		{ FExercisePrescription E; E.ExerciseID = TEXT("goblet_squat"); E.ExerciseName = TEXT("Goblet Squats"); E.Sets = 3; E.Reps = 12; E.RestSeconds = 60; E.IntensityPercent = 65.f; E.Rationale = TEXT("Lower body foundation"); Main.Add(E); }
		{ FExercisePrescription E; E.ExerciseID = TEXT("pushup"); E.ExerciseName = TEXT("Push-Ups"); E.Sets = 3; E.Reps = 15; E.RestSeconds = 45; E.IntensityPercent = 60.f; E.Rationale = TEXT("Upper body pushing"); Main.Add(E); }
		{ FExercisePrescription E; E.ExerciseID = TEXT("plank"); E.ExerciseName = TEXT("Plank Hold"); E.Sets = 3; E.Reps = 1; E.RestSeconds = 30; E.IntensityPercent = 50.f; E.Rationale = TEXT("Core stability"); Main.Add(E); }
		break;
	}
	}

	return Main;
}

TArray<FExercisePrescription> UFELPersonalizedWorkouts::GenerateCoolDownBlock() const
{
	TArray<FExercisePrescription> CoolDown;
	{ FExercisePrescription E; E.ExerciseID = TEXT("cooldown_walk"); E.ExerciseName = TEXT("Light Walk"); E.Sets = 1; E.Reps = 1; E.RestSeconds = 0; E.IntensityPercent = 25.f; E.Rationale = TEXT("Gradually lower heart rate"); CoolDown.Add(E); }
	{ FExercisePrescription E; E.ExerciseID = TEXT("cooldown_static_stretch"); E.ExerciseName = TEXT("Static Stretching"); E.Sets = 1; E.Reps = 8; E.RestSeconds = 0; E.IntensityPercent = 20.f; E.Rationale = TEXT("Improve flexibility and recovery"); CoolDown.Add(E); }
	{ FExercisePrescription E; E.ExerciseID = TEXT("cooldown_breathing"); E.ExerciseName = TEXT("Diaphragmatic Breathing"); E.Sets = 1; E.Reps = 10; E.RestSeconds = 0; E.IntensityPercent = 10.f; E.Rationale = TEXT("Activate parasympathetic recovery"); CoolDown.Add(E); }
	return CoolDown;
}

FString UFELPersonalizedWorkouts::GenerateWorkoutID() const
{
	return FString::Printf(TEXT("WKT-%s"), *FGuid::NewGuid().ToString(EGuidFormats::Short));
}
