// Copyright (c) Final Evolution Lab.
// Injury prevention system implementation.
// Phase 5: OpenCap Body Scanning

#include "FELInjuryPrevention.h"

void UFELInjuryPrevention::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	UE_LOG(LogTemp, Log, TEXT("[FEL-Injury] Injury prevention subsystem initialized."));
}

void UFELInjuryPrevention::Deinitialize()
{
	LatestAssessments.Empty();
	FatigueLevels.Empty();
	InjuryHistories.Empty();
	Super::Deinitialize();
}

/* ─────────────  Risk Assessment  ───────────────────────────────── */

FInjuryRiskAssessment UFELInjuryPrevention::PerformRiskAssessment(
	const FString& UserID,
	const TArray<FMovementAnalysisResult>& MovementResults,
	const FPerformanceMetrics& Metrics)
{
	FInjuryRiskAssessment Assessment;
	Assessment.UserID = UserID;
	Assessment.AssessmentDate = FDateTime::UtcNow();

	// Get injury history
	TArray<FInjuryHistoryEntry> History;
	if (const auto* H = InjuryHistories.Find(UserID))
	{
		History = *H;
	}

	// Assess each body region
	const TArray<EBodyRegion> Regions = {
		EBodyRegion::LeftKnee, EBodyRegion::RightKnee,
		EBodyRegion::LeftAnkle, EBodyRegion::RightAnkle,
		EBodyRegion::LeftHip, EBodyRegion::RightHip,
		EBodyRegion::LeftShoulder, EBodyRegion::RightShoulder,
		EBodyRegion::LowerBack, EBodyRegion::UpperBack
	};

	float TotalRisk = 0.f;
	for (EBodyRegion Region : Regions)
	{
		FInjuryRiskFactor Factor = AssessRegionRisk(Region, MovementResults, History);
		Assessment.RiskFactors.Add(Factor);
		TotalRisk += Factor.RiskScore;
	}

	Assessment.OverallRiskScore = TotalRisk / Regions.Num();
	Assessment.OverallRiskLevel = ScoreToRiskLevel(Assessment.OverallRiskScore);

	// Get current fatigue
	if (const EFatigueLevel* F = FatigueLevels.Find(UserID))
	{
		Assessment.CurrentFatigue = *F;
	}

	// Generate recommendations
	Assessment.WarmUpRecommendations = GenerateWarmUp(Assessment);
	Assessment.MobilityRecommendations = GenerateMobilityWork(Assessment);
	Assessment.CorrectiveExercises = GenerateCorrectiveExercises(Assessment);

	// Cache
	LatestAssessments.Add(UserID, Assessment);
	OnAssessmentComplete.Broadcast(Assessment);

	UE_LOG(LogTemp, Log, TEXT("[FEL-Injury] Risk assessment for %s: %.1f (%s)"),
		*UserID, Assessment.OverallRiskScore,
		*UEnum::GetValueAsString(Assessment.OverallRiskLevel));

	return Assessment;
}

FInjuryRiskAssessment UFELInjuryPrevention::GetLatestAssessment(const FString& UserID) const
{
	if (const auto* A = LatestAssessments.Find(UserID)) return *A;
	return FInjuryRiskAssessment();
}

EInjuryRiskLevel UFELInjuryPrevention::GetCurrentRiskLevel(const FString& UserID) const
{
	if (const auto* A = LatestAssessments.Find(UserID)) return A->OverallRiskLevel;
	return EInjuryRiskLevel::Low;
}

/* ─────────────  Fatigue Tracking  ───────────────────────────────── */

void UFELInjuryPrevention::UpdateFatigueLevel(
	const FString& UserID, float WorkoutDurationMin, float Intensity)
{
	float& Cumulative = CumulativeFatigue.FindOrAdd(UserID, 0.f);
	Cumulative += WorkoutDurationMin * Intensity * 0.01f;
	Cumulative = FMath::Clamp(Cumulative, 0.f, 100.f);

	EFatigueLevel Level;
	if (Cumulative < 20.f)       Level = EFatigueLevel::Fresh;
	else if (Cumulative < 40.f)  Level = EFatigueLevel::Mild;
	else if (Cumulative < 60.f)  Level = EFatigueLevel::Moderate;
	else if (Cumulative < 80.f)  Level = EFatigueLevel::High;
	else                          Level = EFatigueLevel::Exhausted;

	EFatigueLevel PrevLevel = FatigueLevels.FindOrAdd(UserID, EFatigueLevel::Fresh);
	FatigueLevels[UserID] = Level;

	if (Level != PrevLevel)
	{
		OnFatigueChanged.Broadcast(Level);

		// Trigger alert if exhausted
		if (Level == EFatigueLevel::Exhausted)
		{
			FInjuryPreventionAlert Alert;
			Alert.AlertLevel = EInjuryRiskLevel::High;
			Alert.Title = TEXT("Fatigue Threshold Reached");
			Alert.Message = TEXT("You are showing signs of exhaustion. Continuing increases injury risk.");
			Alert.RecommendedAction = TEXT("Take a 15-minute rest or end your session.");
			Alert.bShouldStopWorkout = true;
			OnAlertTriggered.Broadcast(Alert);
		}
	}
}

EFatigueLevel UFELInjuryPrevention::GetFatigueLevel(const FString& UserID) const
{
	if (const auto* F = FatigueLevels.Find(UserID)) return *F;
	return EFatigueLevel::Fresh;
}

void UFELInjuryPrevention::ResetFatigue(const FString& UserID)
{
	CumulativeFatigue.Add(UserID, 0.f);
	FatigueLevels.Add(UserID, EFatigueLevel::Fresh);
	OnFatigueChanged.Broadcast(EFatigueLevel::Fresh);
}

/* ─────────────  Injury History  ─────────────────────────────────── */

void UFELInjuryPrevention::RecordInjury(const FString& UserID, const FInjuryHistoryEntry& Entry)
{
	if (!InjuryHistories.Contains(UserID))
	{
		InjuryHistories.Add(UserID, TArray<FInjuryHistoryEntry>());
	}
	InjuryHistories[UserID].Add(Entry);

	UE_LOG(LogTemp, Log, TEXT("[FEL-Injury] Injury recorded for %s: %s"), *UserID, *Entry.Description);
}

TArray<FInjuryHistoryEntry> UFELInjuryPrevention::GetInjuryHistory(const FString& UserID) const
{
	if (const auto* H = InjuryHistories.Find(UserID)) return *H;
	return TArray<FInjuryHistoryEntry>();
}

void UFELInjuryPrevention::UpdateRecoveryProgress(const FString& UserID, EBodyRegion Region, float Progress)
{
	if (auto* History = InjuryHistories.Find(UserID))
	{
		for (FInjuryHistoryEntry& Entry : *History)
		{
			if (Entry.Region == Region && !Entry.bFullyRecovered)
			{
				Entry.RecoveryProgress = FMath::Clamp(Progress, 0.f, 100.f);
				if (Entry.RecoveryProgress >= 100.f)
				{
					Entry.bFullyRecovered = true;
					Entry.RecoveryDate = FDateTime::UtcNow();
				}
				break;
			}
		}
	}
}

/* ─────────────  Recommendations  ───────────────────────────────── */

TArray<FString> UFELInjuryPrevention::GetWarmUpRoutine(const FString& UserID) const
{
	if (const auto* A = LatestAssessments.Find(UserID)) return A->WarmUpRecommendations;
	return {TEXT("5-minute light jog"), TEXT("Dynamic stretching"), TEXT("Joint circles")};
}

TArray<FString> UFELInjuryPrevention::GetMobilityRecommendations(const FString& UserID) const
{
	if (const auto* A = LatestAssessments.Find(UserID)) return A->MobilityRecommendations;
	return {TEXT("Hip flexor stretch"), TEXT("Thoracic spine rotation"), TEXT("Ankle dorsiflexion work")};
}

TArray<FString> UFELInjuryPrevention::GetCorrectiveExercises(const FString& UserID) const
{
	if (const auto* A = LatestAssessments.Find(UserID)) return A->CorrectiveExercises;
	return TArray<FString>();
}

bool UFELInjuryPrevention::ShouldTakeRestDay(const FString& UserID) const
{
	if (const auto* F = FatigueLevels.Find(UserID))
	{
		if (*F >= EFatigueLevel::High) return true;
	}
	if (const auto* A = LatestAssessments.Find(UserID))
	{
		if (A->OverallRiskLevel >= EInjuryRiskLevel::High) return true;
	}
	return false;
}

void UFELInjuryPrevention::CheckAndTriggerAlerts(const FString& UserID)
{
	const auto* Assessment = LatestAssessments.Find(UserID);
	if (!Assessment) return;

	// High injury risk warning
	if (Assessment->OverallRiskLevel >= EInjuryRiskLevel::High)
	{
		FInjuryPreventionAlert Alert;
		Alert.AlertLevel = EInjuryRiskLevel::High;
		Alert.Title = TEXT("High Injury Risk");
		Alert.Message = TEXT("Biomechanical analysis indicates elevated injury risk. Modify your workout.");
		Alert.RecommendedAction = TEXT("Reduce intensity and focus on mobility work.");
		OnAlertTriggered.Broadcast(Alert);
	}

	// Overtraining indicator
	if (const auto* F = FatigueLevels.Find(UserID))
	{
		if (*F >= EFatigueLevel::High)
		{
			FInjuryPreventionAlert Alert;
			Alert.AlertLevel = EInjuryRiskLevel::Moderate;
			Alert.Title = TEXT("Overtraining Warning");
			Alert.Message = TEXT("Signs of overtraining detected. Consider a rest or recovery day.");
			Alert.RecommendedAction = TEXT("Schedule a rest day within 48 hours.");
			OnAlertTriggered.Broadcast(Alert);
		}
	}
}

/* ─────────────  Internal  ───────────────────────────────────────── */

FInjuryRiskFactor UFELInjuryPrevention::AssessRegionRisk(
	EBodyRegion Region,
	const TArray<FMovementAnalysisResult>& Results,
	const TArray<FInjuryHistoryEntry>& History) const
{
	FInjuryRiskFactor Factor;
	Factor.Region = Region;
	Factor.RiskScore = 15.f; // Baseline risk

	// Increase risk if there are compensations in related joints
	for (const FMovementAnalysisResult& MR : Results)
	{
		Factor.RiskScore += MR.Compensations.Num() * 5.f;
	}

	// Increase risk for previous injuries
	for (const FInjuryHistoryEntry& IH : History)
	{
		if (IH.Region == Region)
		{
			Factor.RiskScore += IH.bFullyRecovered ? 10.f : 25.f;
			Factor.ContributingFactors.Add(TEXT("Previous injury in this region"));
		}
	}

	Factor.RiskScore = FMath::Clamp(Factor.RiskScore, 0.f, 100.f);
	Factor.RiskLevel = ScoreToRiskLevel(Factor.RiskScore);

	// Add preventive measures
	if (Factor.RiskScore > 50.f)
	{
		Factor.PreventiveMeasures.Add(TEXT("Targeted mobility work"));
		Factor.PreventiveMeasures.Add(TEXT("Strengthening exercises for supporting muscles"));
	}
	if (Factor.RiskScore > 30.f)
	{
		Factor.PreventiveMeasures.Add(TEXT("Extended warm-up for this region"));
	}

	return Factor;
}

EInjuryRiskLevel UFELInjuryPrevention::ScoreToRiskLevel(float Score) const
{
	if (Score < 25.f) return EInjuryRiskLevel::Low;
	if (Score < 50.f) return EInjuryRiskLevel::Moderate;
	if (Score < 75.f) return EInjuryRiskLevel::High;
	return EInjuryRiskLevel::Critical;
}

TArray<FString> UFELInjuryPrevention::GenerateWarmUp(const FInjuryRiskAssessment& Assessment) const
{
	TArray<FString> WarmUp = {
		TEXT("5-minute light cardio (jog or jump rope)"),
		TEXT("Arm circles (20 each direction)"),
		TEXT("Leg swings (15 each leg)"),
		TEXT("Hip circles (10 each direction)")
	};

	// Add targeted warm-up for high-risk areas
	for (const FInjuryRiskFactor& Factor : Assessment.RiskFactors)
	{
		if (Factor.RiskLevel >= EInjuryRiskLevel::Moderate)
		{
			WarmUp.Add(FString::Printf(TEXT("Extra attention: %s region warm-up"),
				*UEnum::GetValueAsString(Factor.Region)));
		}
	}

	return WarmUp;
}

TArray<FString> UFELInjuryPrevention::GenerateMobilityWork(const FInjuryRiskAssessment& Assessment) const
{
	TArray<FString> Mobility = {
		TEXT("Cat-cow stretch (10 reps)"),
		TEXT("World's greatest stretch (5 each side)"),
		TEXT("90/90 hip stretch (30 seconds each side)"),
		TEXT("Thoracic spine rotation (10 each side)")
	};
	return Mobility;
}

TArray<FString> UFELInjuryPrevention::GenerateCorrectiveExercises(const FInjuryRiskAssessment& Assessment) const
{
	TArray<FString> Exercises;

	for (const FInjuryRiskFactor& Factor : Assessment.RiskFactors)
	{
		if (Factor.RiskLevel >= EInjuryRiskLevel::Moderate)
		{
			switch (Factor.Region)
			{
			case EBodyRegion::LeftKnee:
			case EBodyRegion::RightKnee:
				Exercises.Add(TEXT("Terminal knee extensions (3x15)"));
				Exercises.Add(TEXT("Single-leg wall sit (3x30s)"));
				break;
			case EBodyRegion::LowerBack:
				Exercises.Add(TEXT("Bird-dogs (3x10 each side)"));
				Exercises.Add(TEXT("Dead bugs (3x10 each side)"));
				break;
			case EBodyRegion::LeftShoulder:
			case EBodyRegion::RightShoulder:
				Exercises.Add(TEXT("Band pull-aparts (3x20)"));
				Exercises.Add(TEXT("External rotations (3x15)"));
				break;
			default:
				Exercises.Add(TEXT("General mobility work for affected area"));
				break;
			}
		}
	}

	return Exercises;
}
