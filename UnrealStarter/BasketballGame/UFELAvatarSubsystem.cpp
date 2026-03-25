// Copyright (c) Final Evolution Lab.

#include "UFELAvatarSubsystem.h"

void UFELAvatarSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
}

void UFELAvatarSubsystem::ApplySystemScanOutput(const FFELSystemScanOutput& Scan)
{
	StartingTrack = Scan.StartingTrack;
	LastVerticalInches = Scan.VerticalEstimateInches;
	NeuroVerticalPotentialJumpZ = Scan.NeuroVerticalPotentialJumpZ;
	LastPRQ0to100 = Scan.PRQ0to100;
}

void UFELAvatarSubsystem::SetKineticHeatFromReadiness(float Ankle01, float Knee01, float Hip01, float InLeakageMultiplier)
{
	KineticHeatAnkle01 = FMath::Clamp(Ankle01, 0.f, 1.f);
	KineticHeatKnee01 = FMath::Clamp(Knee01, 0.f, 1.f);
	KineticHeatHip01 = FMath::Clamp(Hip01, 0.f, 1.f);
	KineticLeakageMultiplier = FMath::Clamp(InLeakageMultiplier, 0.35f, 1.f);
}
