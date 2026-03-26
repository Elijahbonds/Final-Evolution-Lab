// Copyright (c) Final Evolution Lab.

#include "FELCinematicCameraComponent.h"
#include "FELBasketballCharacter.h"
#include "Camera/CameraComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "GameFramework/CharacterMovementComponent.h"

UFELCinematicCameraComponent::UFELCinematicCameraComponent()
{
	PrimaryComponentTick.bCanEverTick = false;
}

void UFELCinematicCameraComponent::BeginPlay()
{
	Super::BeginPlay();

	if (AFELBasketballCharacter* C = Cast<AFELBasketballCharacter>(GetOwner()))
	{
		CachedSpringArm = C->CameraBoom;
		CachedFollowCamera = C->FollowCamera;
	}
	if (CachedSpringArm)
	{
		DefaultArmLength = CachedSpringArm->TargetArmLength;
	}
	if (CachedFollowCamera)
	{
		DefaultFieldOfView = CachedFollowCamera->FieldOfView;
	}
}

void UFELCinematicCameraComponent::NotifyPerfectTimingBand()
{
	PerfectBoostRemainSec = PerfectBoostDurationSec;
}

void UFELCinematicCameraComponent::BeginReplayHighlight(float DurationSeconds)
{
	ReplayHighlightRemainSec = FMath::Max(0.f, DurationSeconds);
	PerfectBoostRemainSec = FMath::Max(PerfectBoostRemainSec, PerfectBoostDurationSec * 0.85f);
}

void UFELCinematicCameraComponent::BeginTwinBirthCinematic(const float DurationSeconds)
{
	TwinBirthRemainSec = FMath::Max(0.f, DurationSeconds);
	BeginReplayHighlight(DurationSeconds);
}

void UFELCinematicCameraComponent::UpdateApexCamera(float DeltaSeconds, float NeuroFlowVisualBlend01, float GatherApproachSeconds)
{
	AFELBasketballCharacter* const C = Cast<AFELBasketballCharacter>(GetOwner());
	if (!C || !CachedSpringArm || !CachedFollowCamera)
	{
		return;
	}

	if (ReplayHighlightRemainSec > 0.f)
	{
		ReplayHighlightRemainSec = FMath::Max(0.f, ReplayHighlightRemainSec - DeltaSeconds);
	}

	if (PerfectBoostRemainSec > 0.f)
	{
		PerfectBoostRemainSec = FMath::Max(0.f, PerfectBoostRemainSec - DeltaSeconds);
	}

	if (TwinBirthRemainSec > 0.f)
	{
		TwinBirthRemainSec = FMath::Max(0.f, TwinBirthRemainSec - DeltaSeconds);
		if (CachedSpringArm)
		{
			CachedSpringArm->AddRelativeRotation(FRotator(0.f, TwinBirthOrbitYawSpeed * DeltaSeconds, 0.f));
		}
	}

	UCharacterMovementComponent* const M = C->GetCharacterMovement();
	float ApexT = 0.f;
	if (M && M->IsFalling())
	{
		const float AbsVz = FMath::Abs(M->Velocity.Z);
		const float Raw = FMath::Clamp(1.f - AbsVz / FMath::Max(40.f, ApexVelocityThresholdUU), 0.f, 1.f);
		ApexT = Raw * Raw * (3.f - 2.f * Raw);
	}

	const float NF = FMath::Clamp(NeuroFlowVisualBlend01, 0.f, 1.f);
	const float PerfectT = (PerfectBoostRemainSec > 0.f) ? FMath::Clamp(PerfectBoostRemainSec / PerfectBoostDurationSec, 0.f, 1.f) : 0.f;

	float GatherWindow = 0.f;
	if (GatherApproachSeconds > 0.04f && GatherApproachSeconds < 0.58f)
	{
		const float U = FMath::Clamp(GatherApproachSeconds / 0.58f, 0.f, 1.f);
		GatherWindow = FMath::Sin(3.14159265f * U);
	}

	float TargetBlend = FMath::Clamp(FMath::Max(ApexT * 0.85f, NF * 0.95f) + PerfectT * 0.45f + GatherWindow * 0.48f, 0.f, 1.f);
	if (TwinBirthRemainSec > 0.f)
	{
		TargetBlend = FMath::Max(TargetBlend, 0.94f);
	}
	if (ReplayHighlightRemainSec > 0.f)
	{
		TargetBlend = FMath::Max(TargetBlend, 0.98f);
	}
	CurrentApexBlend = FMath::FInterpTo(CurrentApexBlend, TargetBlend, DeltaSeconds, BlendInterpSpeed);

	const float ArmLen = FMath::Lerp(DefaultArmLength, DefaultArmLength * ApexArmLengthScale, CurrentApexBlend);
	CachedSpringArm->TargetArmLength = ArmLen;

	const float GatherFovPunch = GatherWindow * DefaultFieldOfView * GatherFovPunchFraction;
	const float Fov = FMath::Lerp(DefaultFieldOfView, ApexFieldOfView, CurrentApexBlend) - GatherFovPunch;
	CachedFollowCamera->SetFieldOfView(Fov);
}
