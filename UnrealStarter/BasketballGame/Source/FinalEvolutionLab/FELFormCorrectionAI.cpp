// Copyright (c) Final Evolution Lab.
// Real-time form correction AI implementation.
// Phase 5: OpenCap Body Scanning

#include "FELFormCorrectionAI.h"

void UFELFormCorrectionAI::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	InitializeIdealFormDatabase();

	EnabledFeedback = {
		EFormFeedbackType::VisualOverlay,
		EFormFeedbackType::AudioCue,
		EFormFeedbackType::TextInstruction
	};

	UE_LOG(LogTemp, Log, TEXT("[FEL-FormAI] Form correction AI initialized with %d exercise templates."), IdealFormDB.Num());
}

void UFELFormCorrectionAI::Deinitialize()
{
	EndCorrectionSession();
	Super::Deinitialize();
}

/* ─────────────  Session Management  ─────────────────────────────── */

void UFELFormCorrectionAI::StartCorrectionSession(const FString& ExerciseID)
{
	CurrentSession = FFormCorrectionSession();
	CurrentSession.ExerciseID = ExerciseID;
	CurrentSession.SessionStart = FDateTime::UtcNow();
	CurrentSession.bIsActive = true;
	CurrentSession.OverallFormScore = 100.f;

	LoadIdealFormForExercise(ExerciseID);

	UE_LOG(LogTemp, Log, TEXT("[FEL-FormAI] Correction session started for exercise: %s"), *ExerciseID);
}

void UFELFormCorrectionAI::EndCorrectionSession()
{
	if (!CurrentSession.bIsActive) return;

	CurrentSession.bIsActive = false;
	UE_LOG(LogTemp, Log, TEXT("[FEL-FormAI] Session ended. Score: %.1f, Perfect reps: %d/%d"),
		CurrentSession.OverallFormScore, CurrentSession.PerfectReps, CurrentSession.TotalReps);
}

/* ─────────────  Real-time Analysis  ─────────────────────────────── */

TArray<FFormCorrection> UFELFormCorrectionAI::AnalyzeFrame(const FOpenCapSkeletonFrame& Frame)
{
	TArray<FFormCorrection> Corrections;
	if (!CurrentSession.bIsActive) return Corrections;

	for (const auto& Pair : CurrentIdealForm.IdealJointAngles)
	{
		const FString& JointName = Pair.Key;
		float IdealAngle = Pair.Value;

		// Find the joint in the current frame
		for (const FOpenCapJointData& Joint : Frame.Joints)
		{
			if (Joint.JointName == JointName)
			{
				float CurrentAngle = Joint.Rotation.Pitch;
				FFormCorrection Correction = EvaluateJoint(JointName, CurrentAngle, IdealAngle);
				if (Correction.Severity != ECorrectionSeverity::Info)
				{
					Corrections.Add(Correction);
					OnCorrectionIssued.Broadcast(Correction);
				}
				break;
			}
		}
	}

	// Update form score based on corrections
	if (Corrections.Num() == 0)
	{
		CurrentSession.OverallFormScore = FMath::Min(CurrentSession.OverallFormScore + 0.5f, 100.f);
	}
	else
	{
		float Penalty = 0.f;
		for (const FFormCorrection& C : Corrections)
		{
			switch (C.Severity)
			{
			case ECorrectionSeverity::Minor:    Penalty += 1.f; break;
			case ECorrectionSeverity::Moderate:  Penalty += 3.f; break;
			case ECorrectionSeverity::Critical:  Penalty += 5.f; break;
			default: break;
			}
		}
		CurrentSession.OverallFormScore = FMath::Max(CurrentSession.OverallFormScore - Penalty, 0.f);
	}

	CurrentSession.ActiveCorrections = Corrections;
	OnFormScoreUpdated.Broadcast(CurrentSession.OverallFormScore);

	return Corrections;
}

void UFELFormCorrectionAI::ProcessRepCompletion()
{
	if (!CurrentSession.bIsActive) return;

	CurrentSession.TotalReps++;

	if (CurrentSession.ActiveCorrections.Num() == 0)
	{
		CurrentSession.PerfectReps++;
		OnPerfectRep.Broadcast();
		UE_LOG(LogTemp, Log, TEXT("[FEL-FormAI] Perfect rep! (%d/%d)"),
			CurrentSession.PerfectReps, CurrentSession.TotalReps);
	}
}

/* ─────────────  Feedback Control  ───────────────────────────────── */

void UFELFormCorrectionAI::SetEnabledFeedbackTypes(const TArray<EFormFeedbackType>& Types)
{
	EnabledFeedback = Types;
}

void UFELFormCorrectionAI::SetSensitivity(float Sensitivity)
{
	CorrectionSensitivity = FMath::Clamp(Sensitivity, 0.f, 1.f);
}

void UFELFormCorrectionAI::LoadIdealFormForExercise(const FString& ExerciseID)
{
	if (const FIdealFormData* Data = IdealFormDB.Find(ExerciseID))
	{
		CurrentIdealForm = *Data;
	}
	else
	{
		// Default ideal form
		CurrentIdealForm = FIdealFormData();
		CurrentIdealForm.ExerciseID = ExerciseID;
		CurrentIdealForm.AngleToleranceDegrees = 15.f;
	}
}

/* ─────────────  Internal  ───────────────────────────────────────── */

void UFELFormCorrectionAI::InitializeIdealFormDatabase()
{
	// Squat
	{
		FIdealFormData Data;
		Data.ExerciseID = TEXT("squat");
		Data.IdealTempoBPM = 30.f;
		Data.AngleToleranceDegrees = 15.f;
		Data.IdealJointAngles.Add(TEXT("LeftHip"), 90.f);
		Data.IdealJointAngles.Add(TEXT("RightHip"), 90.f);
		Data.IdealJointAngles.Add(TEXT("LeftKnee"), 90.f);
		Data.IdealJointAngles.Add(TEXT("RightKnee"), 90.f);
		Data.IdealJointAngles.Add(TEXT("Spine"), 170.f);
		IdealFormDB.Add(Data.ExerciseID, Data);
	}

	// Push-up
	{
		FIdealFormData Data;
		Data.ExerciseID = TEXT("pushup");
		Data.IdealTempoBPM = 40.f;
		Data.AngleToleranceDegrees = 12.f;
		Data.IdealJointAngles.Add(TEXT("LeftElbow"), 90.f);
		Data.IdealJointAngles.Add(TEXT("RightElbow"), 90.f);
		Data.IdealJointAngles.Add(TEXT("Spine"), 180.f);
		Data.IdealJointAngles.Add(TEXT("LeftHip"), 180.f);
		Data.IdealJointAngles.Add(TEXT("RightHip"), 180.f);
		IdealFormDB.Add(Data.ExerciseID, Data);
	}

	// Lunge
	{
		FIdealFormData Data;
		Data.ExerciseID = TEXT("lunge");
		Data.IdealTempoBPM = 25.f;
		Data.AngleToleranceDegrees = 15.f;
		Data.IdealJointAngles.Add(TEXT("LeftKnee"), 90.f);
		Data.IdealJointAngles.Add(TEXT("RightKnee"), 90.f);
		Data.IdealJointAngles.Add(TEXT("Spine"), 180.f);
		IdealFormDB.Add(Data.ExerciseID, Data);
	}

	// Deadlift
	{
		FIdealFormData Data;
		Data.ExerciseID = TEXT("deadlift");
		Data.IdealTempoBPM = 20.f;
		Data.AngleToleranceDegrees = 10.f;
		Data.IdealJointAngles.Add(TEXT("LeftHip"), 90.f);
		Data.IdealJointAngles.Add(TEXT("RightHip"), 90.f);
		Data.IdealJointAngles.Add(TEXT("LeftKnee"), 160.f);
		Data.IdealJointAngles.Add(TEXT("RightKnee"), 160.f);
		Data.IdealJointAngles.Add(TEXT("Spine"), 175.f);
		IdealFormDB.Add(Data.ExerciseID, Data);
	}

	// Basketball shooting
	{
		FIdealFormData Data;
		Data.ExerciseID = TEXT("basketball_shooting");
		Data.AngleToleranceDegrees = 12.f;
		Data.IdealJointAngles.Add(TEXT("RightElbow"), 90.f);
		Data.IdealJointAngles.Add(TEXT("RightShoulder"), 90.f);
		Data.IdealJointAngles.Add(TEXT("LeftKnee"), 160.f);
		Data.IdealJointAngles.Add(TEXT("RightKnee"), 160.f);
		IdealFormDB.Add(Data.ExerciseID, Data);
	}

	// Vertical jump
	{
		FIdealFormData Data;
		Data.ExerciseID = TEXT("vertical_jump");
		Data.AngleToleranceDegrees = 20.f;
		Data.IdealJointAngles.Add(TEXT("LeftHip"), 70.f);
		Data.IdealJointAngles.Add(TEXT("RightHip"), 70.f);
		Data.IdealJointAngles.Add(TEXT("LeftKnee"), 80.f);
		Data.IdealJointAngles.Add(TEXT("RightKnee"), 80.f);
		Data.IdealJointAngles.Add(TEXT("LeftAnkle"), 50.f);
		Data.IdealJointAngles.Add(TEXT("RightAnkle"), 50.f);
		IdealFormDB.Add(Data.ExerciseID, Data);
	}
}

FFormCorrection UFELFormCorrectionAI::EvaluateJoint(
	const FString& JointName, float CurrentAngle, float IdealAngle) const
{
	FFormCorrection Correction;
	Correction.JointName = JointName;
	Correction.Category = ECorrectionCategory::JointAngle;
	Correction.DeviationDegrees = FMath::Abs(CurrentAngle - IdealAngle);
	Correction.Confidence = 0.9f;

	// Adjust tolerance based on sensitivity
	float Tolerance = CurrentIdealForm.AngleToleranceDegrees * (1.f - CorrectionSensitivity * 0.5f);

	if (Correction.DeviationDegrees <= Tolerance)
	{
		Correction.Severity = ECorrectionSeverity::Info;
	}
	else if (Correction.DeviationDegrees <= Tolerance * 2.f)
	{
		Correction.Severity = ECorrectionSeverity::Minor;
		Correction.Message = FString::Printf(TEXT("Slight adjustment needed at %s"), *JointName);
		Correction.AudioCueID = TEXT("audio_minor_correction");
	}
	else if (Correction.DeviationDegrees <= Tolerance * 3.f)
	{
		Correction.Severity = ECorrectionSeverity::Moderate;
		if (CurrentAngle < IdealAngle)
		{
			Correction.Message = FString::Printf(TEXT("Increase angle at %s"), *JointName);
		}
		else
		{
			Correction.Message = FString::Printf(TEXT("Decrease angle at %s"), *JointName);
		}
		Correction.AudioCueID = TEXT("audio_moderate_correction");
	}
	else
	{
		Correction.Severity = ECorrectionSeverity::Critical;
		Correction.Message = FString::Printf(TEXT("Major form issue at %s — stop and reset"), *JointName);
		Correction.AudioCueID = TEXT("audio_critical_correction");
	}

	return Correction;
}
