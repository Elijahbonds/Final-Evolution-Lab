// Copyright (c) Final Evolution Lab.
// Biomechanical analysis system implementation.
// Phase 5: OpenCap Body Scanning

#include "FELBiomechanicsAnalyzer.h"

void UFELBiomechanicsAnalyzer::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	InitializeIdealAngles();
	UE_LOG(LogTemp, Log, TEXT("[FEL-Biomechanics] Analyzer subsystem initialized."));
}

void UFELBiomechanicsAnalyzer::Deinitialize()
{
	PerformanceCache.Empty();
	Super::Deinitialize();
}

/* ─────────────  Joint Analysis  ─────────────────────────────────── */

TArray<FJointAnalysisResult> UFELBiomechanicsAnalyzer::AnalyzeJointROM(const TArray<FOpenCapSkeletonFrame>& Frames)
{
	TArray<FJointAnalysisResult> Results;

	const TArray<FString> MajorJoints = {
		TEXT("LeftShoulder"), TEXT("RightShoulder"),
		TEXT("LeftElbow"), TEXT("RightElbow"),
		TEXT("LeftHip"), TEXT("RightHip"),
		TEXT("LeftKnee"), TEXT("RightKnee"),
		TEXT("LeftAnkle"), TEXT("RightAnkle"),
		TEXT("Spine"), TEXT("Neck")
	};

	for (const FString& JointName : MajorJoints)
	{
		FJointAnalysisResult Result = AnalyzeSingleJoint(JointName, Frames);
		Results.Add(Result);
	}

	UE_LOG(LogTemp, Log, TEXT("[FEL-Biomechanics] Analyzed ROM for %d joints across %d frames."),
		MajorJoints.Num(), Frames.Num());
	return Results;
}

FJointAnalysisResult UFELBiomechanicsAnalyzer::AnalyzeSingleJoint(
	const FString& JointName, const TArray<FOpenCapSkeletonFrame>& Frames)
{
	FJointAnalysisResult Result;
	Result.JointName = JointName;

	if (Frames.Num() == 0)
	{
		Result.Grade = EROMGrade::Poor;
		Result.LimitationNote = TEXT("No frame data available.");
		return Result;
	}

	// Track min/max angles across all frames
	float MinAngle = 360.f;
	float MaxAngle = -360.f;

	for (const FOpenCapSkeletonFrame& Frame : Frames)
	{
		for (const FOpenCapJointData& Joint : Frame.Joints)
		{
			if (Joint.JointName == JointName)
			{
				float Angle = Joint.Rotation.Pitch; // Use pitch as primary angle
				MinAngle = FMath::Min(MinAngle, Angle);
				MaxAngle = FMath::Max(MaxAngle, Angle);
			}
		}
	}

	Result.MinAngle = MinAngle;
	Result.MaxAngle = MaxAngle;
	Result.ROM = MaxAngle - MinAngle;
	Result.Grade = GradeROM(JointName, Result.ROM);

	return Result;
}

TArray<FString> UFELBiomechanicsAnalyzer::DetectAsymmetries(
	const TArray<FOpenCapSkeletonFrame>& Frames, float ThresholdPercent)
{
	TArray<FString> Asymmetries;

	// Compare left vs right joints
	const TArray<TPair<FString, FString>> PairedJoints = {
		{TEXT("LeftShoulder"), TEXT("RightShoulder")},
		{TEXT("LeftElbow"), TEXT("RightElbow")},
		{TEXT("LeftHip"), TEXT("RightHip")},
		{TEXT("LeftKnee"), TEXT("RightKnee")},
		{TEXT("LeftAnkle"), TEXT("RightAnkle")}
	};

	for (const auto& Pair : PairedJoints)
	{
		FJointAnalysisResult Left = AnalyzeSingleJoint(Pair.Key, Frames);
		FJointAnalysisResult Right = AnalyzeSingleJoint(Pair.Value, Frames);

		if (Left.ROM > 0.f)
		{
			float AsymPercent = FMath::Abs(Left.ROM - Right.ROM) / Left.ROM * 100.f;
			if (AsymPercent > ThresholdPercent)
			{
				Asymmetries.Add(FString::Printf(TEXT("%s vs %s: %.1f%% asymmetry"),
					*Pair.Key, *Pair.Value, AsymPercent));
			}
		}
	}

	return Asymmetries;
}

/* ─────────────  Movement Pattern Analysis  ──────────────────────── */

FMovementAnalysisResult UFELBiomechanicsAnalyzer::AnalyzeMovementPattern(
	EMovementPattern Pattern, const TArray<FOpenCapSkeletonFrame>& Frames)
{
	switch (Pattern)
	{
	case EMovementPattern::Squat:        return AnalyzeSquat(Frames);
	case EMovementPattern::Jump:         return AnalyzeJumpMechanics(Frames);
	case EMovementPattern::ShootingForm: return AnalyzeShootingForm(Frames);
	case EMovementPattern::Sprint:       return AnalyzeRunningGait(Frames);
	default:
		{
			FMovementAnalysisResult Result;
			Result.Pattern = Pattern;
			Result.JointResults = AnalyzeJointROM(Frames);
			return Result;
		}
	}
}

FMovementAnalysisResult UFELBiomechanicsAnalyzer::AnalyzeSquat(const TArray<FOpenCapSkeletonFrame>& Frames)
{
	FMovementAnalysisResult Result;
	Result.Pattern = EMovementPattern::Squat;
	Result.JointResults = AnalyzeJointROM(Frames);

	// Check knee-over-toe, hip hinge depth, torso angle
	Result.OverallScore = 75.f; // Placeholder scoring

	// Detect common compensations
	TArray<FString> Asymmetries = DetectAsymmetries(Frames, 10.f);
	Result.Compensations = Asymmetries;

	Result.Strengths.Add(TEXT("Good hip hinge initiation"));
	Result.Recommendations.Add(TEXT("Work on ankle dorsiflexion for deeper squat depth"));
	Result.Recommendations.Add(TEXT("Focus on maintaining neutral spine throughout"));

	OnAnalysisComplete.Broadcast(Result);
	return Result;
}

FMovementAnalysisResult UFELBiomechanicsAnalyzer::AnalyzeJumpMechanics(const TArray<FOpenCapSkeletonFrame>& Frames)
{
	FMovementAnalysisResult Result;
	Result.Pattern = EMovementPattern::Jump;
	Result.JointResults = AnalyzeJointROM(Frames);

	Result.OverallScore = 80.f;
	Result.Strengths.Add(TEXT("Explosive triple extension"));
	Result.Strengths.Add(TEXT("Arm swing synchronization"));
	Result.Recommendations.Add(TEXT("Increase countermovement depth for more power"));

	OnAnalysisComplete.Broadcast(Result);
	return Result;
}

FMovementAnalysisResult UFELBiomechanicsAnalyzer::AnalyzeShootingForm(const TArray<FOpenCapSkeletonFrame>& Frames)
{
	FMovementAnalysisResult Result;
	Result.Pattern = EMovementPattern::ShootingForm;
	Result.JointResults = AnalyzeJointROM(Frames);

	Result.OverallScore = 70.f;
	Result.Strengths.Add(TEXT("Consistent release point"));
	Result.Compensations.Add(TEXT("Elbow flare on shooting side"));
	Result.Recommendations.Add(TEXT("Keep shooting elbow under the ball at set point"));
	Result.Recommendations.Add(TEXT("Follow through with full wrist snap"));

	OnAnalysisComplete.Broadcast(Result);
	return Result;
}

FMovementAnalysisResult UFELBiomechanicsAnalyzer::AnalyzeRunningGait(const TArray<FOpenCapSkeletonFrame>& Frames)
{
	FMovementAnalysisResult Result;
	Result.Pattern = EMovementPattern::Sprint;
	Result.JointResults = AnalyzeJointROM(Frames);

	Result.OverallScore = 72.f;
	Result.Strengths.Add(TEXT("Good knee drive"));
	Result.Compensations.Add(TEXT("Slight heel strike pattern"));
	Result.Recommendations.Add(TEXT("Transition to midfoot strike for efficiency"));
	Result.Recommendations.Add(TEXT("Increase cadence to 180+ steps per minute"));

	OnAnalysisComplete.Broadcast(Result);
	return Result;
}

/* ─────────────  Performance Metrics  ────────────────────────────── */

FPerformanceMetrics UFELBiomechanicsAnalyzer::CalculatePerformanceMetrics(
	const TArray<FOpenCapSkeletonFrame>& Frames, const FBodyMetrics& BodyMetrics)
{
	FPerformanceMetrics Metrics;

	// In production: derive these from actual biomechanical data
	Metrics.VerticalJumpCm   = 65.0f;
	Metrics.SprintSpeedMPS   = 8.5f;
	Metrics.AgilityScore     = 72.0f;
	Metrics.PowerOutput      = 2200.0f;
	Metrics.EnduranceCapacity = 68.0f;
	Metrics.FlexibilityScore  = 60.0f;
	Metrics.BalanceScore      = 75.0f;

	OnPerformanceMetricsReady.Broadcast(Metrics);
	return Metrics;
}

FPerformanceMetrics UFELBiomechanicsAnalyzer::GetLatestPerformanceMetrics(const FString& UserID) const
{
	if (const FPerformanceMetrics* M = PerformanceCache.Find(UserID))
	{
		return *M;
	}
	return FPerformanceMetrics();
}

TMap<FString, float> UFELBiomechanicsAnalyzer::CompareScansOverTime(const FString& UserID)
{
	TMap<FString, float> Changes;
	// In production: compare current vs previous scan metrics
	Changes.Add(TEXT("VerticalJump"), +2.5f);
	Changes.Add(TEXT("FlexibilityScore"), +5.0f);
	Changes.Add(TEXT("AgilityScore"), +3.0f);
	return Changes;
}

/* ─────────────  Internal  ───────────────────────────────────────── */

void UFELBiomechanicsAnalyzer::InitializeIdealAngles()
{
	IdealJointAngles.Add(TEXT("LeftShoulder"), 180.f);
	IdealJointAngles.Add(TEXT("RightShoulder"), 180.f);
	IdealJointAngles.Add(TEXT("LeftElbow"), 145.f);
	IdealJointAngles.Add(TEXT("RightElbow"), 145.f);
	IdealJointAngles.Add(TEXT("LeftHip"), 125.f);
	IdealJointAngles.Add(TEXT("RightHip"), 125.f);
	IdealJointAngles.Add(TEXT("LeftKnee"), 140.f);
	IdealJointAngles.Add(TEXT("RightKnee"), 140.f);
	IdealJointAngles.Add(TEXT("LeftAnkle"), 70.f);
	IdealJointAngles.Add(TEXT("RightAnkle"), 70.f);
	IdealJointAngles.Add(TEXT("Spine"), 180.f);
	IdealJointAngles.Add(TEXT("Neck"), 80.f);
}

EROMGrade UFELBiomechanicsAnalyzer::GradeROM(const FString& JointName, float ROM) const
{
	const float* Ideal = IdealJointAngles.Find(JointName);
	if (!Ideal) return EROMGrade::Average;

	float Ratio = ROM / (*Ideal);
	if (Ratio >= 0.95f) return EROMGrade::Excellent;
	if (Ratio >= 0.80f) return EROMGrade::Good;
	if (Ratio >= 0.65f) return EROMGrade::Average;
	if (Ratio >= 0.50f) return EROMGrade::BelowAvg;
	return EROMGrade::Poor;
}

float UFELBiomechanicsAnalyzer::CalculateJointAngle(
	const FOpenCapJointData& Parent, const FOpenCapJointData& Joint, const FOpenCapJointData& Child) const
{
	FVector V1 = (Parent.Position - Joint.Position).GetSafeNormal();
	FVector V2 = (Child.Position - Joint.Position).GetSafeNormal();
	float DotProduct = FVector::DotProduct(V1, V2);
	return FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(DotProduct, -1.f, 1.f)));
}
