// Copyright (c) Final Evolution Lab.

#ifndef PLATFORM_PS5
#define PLATFORM_PS5 0
#endif

#include "FELBasketballCharacter.h"
#include "UFELSaveGame.h"

DEFINE_LOG_CATEGORY_STATIC(LogFEL, Log, All);
#include "FELNativeBridge.h"
#include "FELHoopTargetActor.h"
#include "UFELInputComponent.h"
#include "FELBiometricTypes.h"
#include "FELArenaDifficultyScaling.h"
#include "FELArenaModeDefinitions.h"
#include "FELDojoNeuralTempest.h"
#include "FELSwitchSportsGameplay.h"
#include "FELArenaRulesTypes.h"
#include "FELBasketballGameState.h"
#include "FELBasketballGameMode.h"
#include "UFELDunkContestSessionSubsystem.h"
#include "UFELStreetJamSessionSubsystem.h"
#include "UFELNeuroFlowShareCaptureSubsystem.h"
#include "FELBasketballPlayerController.h"
#include "FELKineticLeakage.h"
#include "FELPRQInfluence.h"
#include "FELMotionWarpingLibrary.h"
#include "FELNeuroAnimLayerBlend.h"
#include "FELNeuroAnimLayerInterface.h"
#include "FELNeuroMechanicBridgeSubsystem.h"
#include "FELNeuroMechanicPhysics.h"
#include "FinalEvolutionLab.h"
#include "UFELLandingIKComponent.h"
#include "FELCinematicCameraComponent.h"
#include "FELConsoleHapticBridge.h"
#if PLATFORM_SWITCH
#include "GameFramework/ForceFeedbackParameters.h"
#endif
#include "Animation/AnimInstance.h"
#include "Animation/AnimMontage.h"
#include "Animation/AnimSequence.h"
#include "Animation/AnimSequenceBase.h"
#include "Engine/SkeletalMesh.h"
#include "MotionWarpingComponent.h"
#include "Camera/CameraComponent.h"
#include "GameFramework/PlayerController.h"
#include "Components/CapsuleComponent.h"
#include "Components/PointLightComponent.h"
#include "Engine/Engine.h"
#include "Engine/GameInstance.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/Controller.h"
#include "GameFramework/SpringArmComponent.h"
#include "Engine/TextureDefines.h"
#include "Kismet/GameplayStatics.h"
#include "Math/RotationMatrix.h"
#include "Math/UnrealMathUtility.h"
#include "NiagaraFunctionLibrary.h"
#include "NiagaraSystem.h"
#include "Materials/MaterialInterface.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Engine/Texture2D.h"
#include "HAL/IConsoleManager.h"
#include "HAL/PlatformMisc.h"
#include "Misc/PackageName.h"
#include "UObject/UObjectGlobals.h"
#include "Sound/SoundAttenuation.h"
#include "Sound/SoundBase.h"
#include "Sound/SoundMix.h"

namespace
{
FLinearColor FEL_NeuroFlowAuraColorForTier(const FString& Tier)
{
	if (Tier.Contains(TEXT("diamond"), ESearchCase::IgnoreCase))
	{
		return FLinearColor(0.88f, 0.95f, 1.f);
	}
	if (Tier.Contains(TEXT("gold"), ESearchCase::IgnoreCase))
	{
		return FLinearColor(1.f, 0.82f, 0.28f);
	}
	return FLinearColor(0.12f, 0.96f, 1.f);
}

FLinearColor FEL_SignatureAuraColorForTrait(const EFELSignatureTrait T)
{
	switch (T)
	{
	case EFELSignatureTrait::Bonds_Apex_Ignition:
		return FLinearColor(1.f, 0.85f, 0.12f, 1.f);
	case EFELSignatureTrait::Dojo_Ghost_Strike:
		return FLinearColor(0.72f, 0.22f, 1.f, 1.f);
	case EFELSignatureTrait::Neuro_Flow_Teleport:
		return FLinearColor(0.12f, 0.96f, 1.f, 1.f);
	default:
		return FLinearColor(0.15f, 1.f, 0.95f, 1.f);
	}
}

#if PLATFORM_PS5
static bool FEL_IsPS5ProHardware_ForVenice()
{
	if (FPlatformMisc::GetEnvironmentVariable(TEXT("FEL_FORCE_PS5_PRO")) == TEXT("1"))
	{
		return true;
	}
	const FString Brand = FPlatformMisc::GetCPUBrand();
	return Brand.Contains(TEXT("Pro"), ESearchCase::IgnoreCase);
}
#endif
}

AFELBasketballCharacter::AFELBasketballCharacter(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer.SetDefaultSubobjectClass<UFELInputComponent>(TEXT("InputComponent0")))
{
	PrimaryActorTick.bCanEverTick = true;

	bUseControllerRotationPitch = false;
	bUseControllerRotationYaw = false;
	bUseControllerRotationRoll = false;

	if (UCharacterMovementComponent* Move = GetCharacterMovement())
	{
		Move->bOrientRotationToMovement = true;
		CachedAirControlBeforeBondsApexJump = Move->AirControl;
		// Street / arcade polish: snappier accel–decel and readable yaw without fighting neuro walk caps.
		Move->MaxAcceleration = 3000.f;
		Move->BrakingDecelerationWalking = 2800.f;
		Move->GroundFriction = 8.5f;
		Move->RotationRate = FRotator(0.f, 680.f, 0.f);
		Move->bUseSeparateBrakingFriction = true;
		Move->BrakingFriction = 5.5f;
	}

	GetMesh()->SetupAttachment(GetCapsuleComponent());
	GetMesh()->SetRelativeLocation(FVector(0.f, 0.f, -96.f));
	GetMesh()->SetRelativeRotation(FRotator(0.f, -90.f, 0.f));

	{
		USkeletalMesh* Sk = nullptr;
		if (FPackageName::DoesPackageExist(TEXT("/Game/FEL/Characters/ElijahBonds/SKM_ElijahBonds_Walking")))
		{
			Sk = LoadObject<USkeletalMesh>(
				nullptr,
				TEXT("/Game/FEL/Characters/ElijahBonds/SKM_ElijahBonds_Walking.SKM_ElijahBonds_Walking"),
				nullptr,
				LOAD_None,
				nullptr);
		}
		if (!Sk)
		{
			Sk = LoadObject<USkeletalMesh>(
				nullptr,
				TEXT("/Engine/EngineMeshes/SkeletalCube.SkeletalCube"),
				nullptr,
				LOAD_None,
				nullptr);
		}
		if (Sk)
		{
			GetMesh()->SetSkeletalMesh(Sk);
			if (Sk->GetPathName().Contains(TEXT("SkeletalCube")))
			{
				GetMesh()->SetRelativeScale3D(FVector(0.85f));
			}
		}
	}

	CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
	CameraBoom->SetupAttachment(RootComponent);
	CameraBoom->TargetArmLength = 400.f;
	CameraBoom->bUsePawnControlRotation = true;
	CameraBoom->bEnableCameraLag = true;
	CameraBoom->CameraLagSpeed = 14.f;
	CameraBoom->bEnableCameraRotationLag = true;
	CameraBoom->CameraRotationLagSpeed = 12.f;
	CameraBoom->CameraLagMaxDistance = 28.f;

	FollowCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FollowCamera"));
	FollowCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
	FollowCamera->bUsePawnControlRotation = false;

	NeuroDriveFootGlow = CreateDefaultSubobject<UPointLightComponent>(TEXT("NeuroDriveFootGlow"));
	NeuroDriveFootGlow->SetupAttachment(GetCapsuleComponent());
	NeuroDriveFootGlow->SetRelativeLocation(FVector(0.f, -28.f, -92.f));
	NeuroDriveFootGlow->SetIntensity(0.f);
	NeuroDriveFootGlow->SetLightColor(FLinearColor(0.15f, 1.f, 0.25f));
	NeuroDriveFootGlow->SetAttenuationRadius(180.f);
	NeuroDriveFootGlow->SetVisibility(false);

	NeuroDriveHandGlow = CreateDefaultSubobject<UPointLightComponent>(TEXT("NeuroDriveHandGlow"));
	NeuroDriveHandGlow->SetupAttachment(GetCapsuleComponent());
	NeuroDriveHandGlow->SetRelativeLocation(FVector(48.f, 0.f, 96.f));
	NeuroDriveHandGlow->SetIntensity(0.f);
	NeuroDriveHandGlow->SetLightColor(FLinearColor(0.15f, 1.f, 0.25f));
	NeuroDriveHandGlow->SetAttenuationRadius(160.f);
	NeuroDriveHandGlow->SetVisibility(false);

	MotionWarping = CreateDefaultSubobject<UMotionWarpingComponent>(TEXT("MotionWarping"));

	LandingIK = CreateDefaultSubobject<UFELLandingIKComponent>(TEXT("LandingIK"));

	CinematicCamera = CreateDefaultSubobject<UFELCinematicCameraComponent>(TEXT("CinematicCamera"));
}

bool AFELBasketballCharacter::CanJump() const
{
	if (const UWorld* W = GetWorld())
	{
		if (const AFELBasketballGameState* GS = W->GetGameState<AFELBasketballGameState>())
		{
			if (GS->HasMatchEnded())
			{
				return false;
			}
		}
	}
	if (CoyoteTimeRemaining > 0.f)
	{
		const UCharacterMovementComponent* M = GetCharacterMovement();
		if (M && !M->IsMovingOnGround())
		{
			return true;
		}
	}
	return Super::CanJump();
}

float AFELBasketballCharacter::GetSprintGauge01() const
{
	const UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M)
	{
		return 0.f;
	}
	const float Denom = FMath::Max(1.f, CachedNeuroMaxWalkSpeed);
	return FMath::Clamp(M->Velocity.Size2D() / Denom, 0.f, 1.f);
}

float AFELBasketballCharacter::GetGatherNeuralDrive01() const
{
	return FMath::Clamp(CachedNeuralDrive / 100.f, 0.f, 1.f);
}

float AFELBasketballCharacter::GetNeuroFlowVisualBlend01() const
{
	return FMath::Clamp(NeuroFlowVisualBlend, 0.f, 1.f);
}

void AFELBasketballCharacter::BeginPlay()
{
	Super::BeginPlay();
	if (FollowCamera)
	{
		DefaultFollowCameraFOV = FollowCamera->FieldOfView;
		const FVector CamLoc = FollowCamera->GetComponentLocation();
		UE_LOG(LogTemp, Warning, TEXT("GOLD MASTER: Camera Active at Loc: %s"), *CamLoc.ToString());
		if (CamLoc.IsNearlyZero())
		{
			UE_LOG(LogTemp, Error, TEXT("GOLD MASTER: CRITICAL - Camera stuck at Origin (0,0,0). Possession failed?"));
		}
	}
	else
	{
		UE_LOG(LogTemp, Error, TEXT("GOLD MASTER: FollowCamera Component is NULL."));
	}
	if (USkeletalMeshComponent* Sk = GetMesh())
	{
		Sk->SetHiddenInGame(false);
		Sk->SetVisibility(true, true);
	}
	EnsureNeuroFlowMaterialDynamics();
}

#if WITH_EDITOR
void AFELBasketballCharacter::PostEditChangeProperty(FPropertyChangedEvent& PropertyChangedEvent)
{
	Super::PostEditChangeProperty(PropertyChangedEvent);
	if (PropertyChangedEvent.Property
		&& PropertyChangedEvent.Property->GetFName() == GET_MEMBER_NAME_CHECKED(AFELBasketballCharacter, SovereignGearTextures))
	{
		ApplySovereignTexturePlatformDefaults();
	}
}

void AFELBasketballCharacter::ApplySovereignTexturePlatformDefaults()
{
	for (UTexture2D* Tex : SovereignGearTextures)
	{
		if (!Tex)
		{
			continue;
		}
		Tex->CompressionSettings = TextureCompressionSettings::TC_Default;
		Tex->MaxTextureSize = 1024;
		Tex->Modify();
		Tex->PostEditChange();
		Tex->MarkPackageDirty();
	}
}
#endif

void AFELBasketballCharacter::ApplyTouchDriveInput(
	const float MoveForward,
	const float MoveRight,
	const float TurnDelta,
	const float Sprint01,
	const float Gather01,
	const float DeltaSeconds)
{
	TouchSprintBlend01 = FMath::FInterpTo(TouchSprintBlend01, FMath::Clamp(Sprint01, 0.f, 1.f), DeltaSeconds, 22.f);
	TouchGatherBlend01 = FMath::FInterpTo(TouchGatherBlend01, FMath::Clamp(Gather01, 0.f, 1.f), DeltaSeconds, 18.f);
	if (Controller && !FMath::IsNearlyZero(TurnDelta))
	{
		AddControllerYawInput(TurnDelta);
	}
	const float Yaw = Controller ? Controller->GetControlRotation().Yaw : GetActorRotation().Yaw;
	const FRotator YawRot(0.f, Yaw, 0.f);
	if (!FMath::IsNearlyZero(MoveForward) || !FMath::IsNearlyZero(MoveRight))
	{
		AddMovementInput(FRotationMatrix(YawRot).GetUnitAxis(EAxis::X), MoveForward);
		AddMovementInput(FRotationMatrix(YawRot).GetUnitAxis(EAxis::Y), MoveRight);
	}
}

void AFELBasketballCharacter::TriggerSignatureMove()
{
	ExecuteSignatureMove();
}

void AFELBasketballCharacter::ApplyPersistedGearState(UFELSaveGame* Save)
{
	if (!Save)
	{
		return;
	}
	if (Save->CachedGearJumpMult > 0.f)
	{
		CachedGearJumpMult = FMath::Clamp(Save->CachedGearJumpMult, 1.f, 1.06f);
	}
	for (const FString& Id : Save->UnlockedSovereignSkins)
	{
		if (Id.Equals(TEXT("Bonds_Apex_Ignition"), ESearchCase::IgnoreCase))
		{
			CachedSignatureTrait = EFELSignatureTrait::Bonds_Apex_Ignition;
			break;
		}
	}
}

void AFELBasketballCharacter::FELHandshakeJump()
{
	FEL_OnJumpPressed();
}

bool AFELBasketballCharacter::IsSignatureMoveWindowActive() const
{
	if (SignatureAuraBlend01 > 0.08f)
	{
		return true;
	}
	if (bPendingSignatureApexIgnition || bBondsApexIgnitionSeekApex)
	{
		return true;
	}
	if (const UWorld* W = GetWorld())
	{
		if (W->GetTimeSeconds() < SignatureGhostStrikeUntilTime)
		{
			return true;
		}
	}
	return false;
}

void AFELBasketballCharacter::ExecuteSignatureMove()
{
	if (CachedSignatureTrait == EFELSignatureTrait::None || SignatureMoveCooldownRemaining > 0.f)
	{
		return;
	}
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	const float Now = W->GetTimeSeconds();
	SignatureMoveCooldownRemaining = 3.5f;
	SignatureAuraBlend01 = 1.f;

	switch (CachedSignatureTrait)
	{
	case EFELSignatureTrait::Bonds_Apex_Ignition:
		bPendingSignatureApexIgnition = true;
		// Kinetic energy transfer (gather pole-vault): 15% of forward horizontal speed → next jump Z boost.
		PendingKineticGatherJumpBoost = 0.f;
		if (UCharacterMovementComponent* Move = GetCharacterMovement())
		{
			FVector Vel = Move->Velocity;
			Vel.Z = 0.f;
			FVector Fwd(GetActorForwardVector().X, GetActorForwardVector().Y, 0.f);
			if (Fwd.Normalize())
			{
				const float ForwardSpeed = FVector::DotProduct(Vel, Fwd);
				PendingKineticGatherJumpBoost = 0.15f * FMath::Max(0.f, ForwardSpeed);
			}
		}
		break;
	case EFELSignatureTrait::Dojo_Ghost_Strike:
		SignatureGhostStrikeUntilTime = static_cast<double>(Now) + 0.55;
		break;
	case EFELSignatureTrait::Neuro_Flow_Teleport:
		TryNeuroFlowTeleportTowardRim();
		break;
	default:
		break;
	}
}

void AFELBasketballCharacter::TryNeuroFlowTeleportTowardRim()
{
	if (TouchGatherBlend01 < 0.25f && ApproachRunSeconds < 0.06f)
	{
		return;
	}
	FVector ToHoop = GetNearestHoopLocationForVFX() - GetActorLocation();
	ToHoop.Z = 0.f;
	const float Len = ToHoop.Size();
	if (Len < 50.f)
	{
		return;
	}
	ToHoop /= Len;
	const FVector Delta = ToHoop * 200.f;
	FHitResult Hit;
	AddActorWorldOffset(Delta, true, &Hit);
}

void AFELBasketballCharacter::SpawnSignatureSonicFlareAtApex()
{
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	UNiagaraSystem* const Flare = SignatureSonicFlareVFX ? SignatureSonicFlareVFX : NeuroFlowSonicBoomVFX;
	if (!Flare)
	{
		return;
	}
	USkeletalMeshComponent* const Sk = GetMesh();
	const FVector Loc = Sk ? Sk->GetComponentLocation() + FVector(0.f, 0.f, 140.f) : GetActorLocation() + FVector(0.f, 0.f, 140.f);
	const FRotator Rot = GetActorRotation();
	const float Scale = FMath::Lerp(1.f, 1.55f, FMath::Clamp(CachedPRQScore / 100.f, 0.f, 1.f));
	UNiagaraFunctionLibrary::SpawnSystemAtLocation(W, Flare, Loc, Rot, FVector(Scale), true, true);

	static constexpr float GravityCmPerSecSqForApexIn = 980.f;
	const float PeakVzForApex = FMath::Max(LastJumpPeakZVelocityForStats, 0.f);
	const float ApexHeightCmForApex = (PeakVzForApex * PeakVzForApex) / (2.f * GravityCmPerSecSqForApexIn);
	const float ApexHeightInForApex = ApexHeightCmForApex / 2.54f;
#if PLATFORM_SWITCH
	{
		const float Bloom01 = FMath::Clamp(CachedPRQScore / 100.f, 0.f, 1.f);
		TriggerSwitchHaptics(Bloom01, ApexHeightInForApex >= 40.f);
	}
#endif

#if PLATFORM_IOS
	FELNativeBridge::NotifySonicFlareApexHaptics();
#elif PLATFORM_PS5
	if (APlayerController* PC = Cast<APlayerController>(GetController()))
	{
		FELConsoleHapticBridge::ApplySonicFlareApexImpulse(PC);
	}
#endif

	const FString ShortMap = UGameplayStatics::GetCurrentLevelName(W, true);
	if (ShortMap.Contains(TEXT("Luma_Venice")))
	{
#if PLATFORM_PS5
		PopVeniceMirrorFinishRt();
		PushVeniceMirrorFinishRtIfPS5Pro();
#endif
		bSonicFlareBroadcastHangActive = true;
		bSonicFlareBroadcastBloomActive = true;
		// Bonds Apex auto-replay: estimated apex height from peak upward Z velocity (cm/s) vs gravity (cm/s²).
		// ≥40" (~101.6 cm) → 3s slo-mo broadcast (Sonic Flare + mirror floor); else short TV moment.
		static constexpr float GravityCmPerSecSq = 980.f;
		static constexpr float DemoReplayHeightInches = 40.f;
		static constexpr float ShortBroadcastSec = 0.2f;
		static constexpr float DemoReplayBroadcastSec = 3.f;
		const float PeakVz = FMath::Max(LastJumpPeakZVelocityForStats, 0.f);
		const float ApexHeightCm = (PeakVz * PeakVz) / (2.f * GravityCmPerSecSq);
		const float ApexHeightIn = ApexHeightCm / 2.54f;
		const float BroadcastWindowSec =
			(ApexHeightIn >= DemoReplayHeightInches) ? DemoReplayBroadcastSec : ShortBroadcastSec;
#if PLATFORM_IOS
		if (BroadcastWindowSec >= DemoReplayBroadcastSec - KINDA_SMALL_NUMBER)
		{
			FELNativeBridge::NotifyHeroMomentExportReady(ApexHeightIn);
		}
#endif
		W->GetTimerManager().ClearTimer(SonicFlareBroadcastTimerHandle);
		W->GetTimerManager().SetTimer(
			SonicFlareBroadcastTimerHandle,
			this,
			&AFELBasketballCharacter::OnSonicFlareBroadcastWindowEnd,
			BroadcastWindowSec,
			false);
	}
}

void AFELBasketballCharacter::TriggerSwitchHaptics(const float BloomIntensity01, const bool bBondsApexHighJump)
{
#if PLATFORM_SWITCH
	if (APlayerController* PC = Cast<APlayerController>(GetController()))
	{
		FForceFeedbackParameters FFP;
		FFP.bLooping = false;
		FFP.Tag = NAME_None;
		if (bBondsApexHighJump)
		{
			// Bonds Apex ≥ ~40" — high-frequency snap; both Joy-Cons (large + small motors on each side).
			PC->PlayDynamicForceFeedback(1.f, 0.085f, true, true, true, true, FFP);
		}
		// Secondary pulse: Niagara Sonic Flare bloom intensity (PRQ / visual scale proxy).
		const float B = FMath::Clamp(BloomIntensity01, 0.2f, 1.f);
		PC->PlayDynamicForceFeedback(B, 0.14f + B * 0.12f, true, true, true, true, FFP);
	}
#else
	(void)BloomIntensity01;
	(void)bBondsApexHighJump;
#endif
}

void AFELBasketballCharacter::OnSonicFlareBroadcastWindowEnd()
{
	bSonicFlareBroadcastHangActive = false;
	bSonicFlareBroadcastBloomActive = false;
#if PLATFORM_PS5
	PopVeniceMirrorFinishRt();
#endif
	if (UWorld* W = GetWorld())
	{
		UGameplayStatics::SetGlobalTimeDilation(W, 1.f);
	}
}

#if PLATFORM_PS5
void AFELBasketballCharacter::PushVeniceMirrorFinishRtIfPS5Pro()
{
	if (!FEL_IsPS5ProHardware_ForVenice() || bVeniceMirrorFinishRtPushed)
	{
		return;
	}
	if (IConsoleVariable* CV = IConsoleManager::Get().FindConsoleVariable(TEXT("r.RayTracing.Reflections.MaxRoughness")))
	{
		VeniceMirrorSavedMaxRoughness = CV->GetFloat();
		bHasVeniceMirrorSavedMaxRoughness = true;
		CV->Set(0.8f, ECVF_SetByCode);
	}
	if (IConsoleVariable* CV = IConsoleManager::Get().FindConsoleVariable(TEXT("r.RayTracing.GlobalIllumination")))
	{
		VeniceMirrorSavedRTGI = CV->GetInt();
		bHasVeniceMirrorSavedRTGI = true;
		CV->Set(1, ECVF_SetByCode);
	}
	bVeniceMirrorFinishRtPushed = true;
}

void AFELBasketballCharacter::PopVeniceMirrorFinishRt()
{
	if (!bVeniceMirrorFinishRtPushed)
	{
		return;
	}
	if (bHasVeniceMirrorSavedMaxRoughness)
	{
		if (IConsoleVariable* CV = IConsoleManager::Get().FindConsoleVariable(TEXT("r.RayTracing.Reflections.MaxRoughness")))
		{
			CV->Set(VeniceMirrorSavedMaxRoughness, ECVF_SetByCode);
		}
		bHasVeniceMirrorSavedMaxRoughness = false;
	}
	if (bHasVeniceMirrorSavedRTGI)
	{
		if (IConsoleVariable* CV = IConsoleManager::Get().FindConsoleVariable(TEXT("r.RayTracing.GlobalIllumination")))
		{
			CV->Set(VeniceMirrorSavedRTGI, ECVF_SetByCode);
		}
		bHasVeniceMirrorSavedRTGI = false;
	}
	bVeniceMirrorFinishRtPushed = false;
}
#endif

void AFELBasketballCharacter::TryShootTapAscentRimSnap()
{
	if (AscentRimSnapCooldownRemaining > 0.f)
	{
		return;
	}
	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M || M->IsMovingOnGround() || M->Velocity.Z <= 80.f)
	{
		return;
	}
	if (!MotionWarping)
	{
		return;
	}
	UFELSaveGame* Save = nullptr;
	if (UGameplayStatics::DoesSaveGameExist(UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex))
	{
		Save = Cast<UFELSaveGame>(UGameplayStatics::LoadGameFromSlot(UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex));
	}
	if (!Save)
	{
		return;
	}
	const float SavePeak = UFELSaveGame::GetAllTimePeakJumpZVelocity(Save);
	if (SavePeak < 40.f)
	{
		return;
	}
	const float CurVz = FMath::Max(LastJumpPeakZVelocityForStats, M->Velocity.Z);
	const float T = FMath::GetMappedRangeValueClamped(
		FVector2D(SavePeak * 0.35f, SavePeak),
		FVector2D(0.f, 1.f),
		CurVz);
	const float ZScale = FMath::Lerp(0.82f, 1.f, T);
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	TArray<AActor*> Hoops;
	UGameplayStatics::GetAllActorsOfClass(W, AFELHoopTargetActor::StaticClass(), Hoops);
	AActor* Best = nullptr;
	float BestD = 1e30f;
	for (AActor* A : Hoops)
	{
		if (!A)
		{
			continue;
		}
		const float D = FVector::DistSquared(GetActorLocation(), A->GetActorLocation());
		if (D < BestD)
		{
			BestD = D;
			Best = A;
		}
	}
	if (!Best || BestD > FMath::Square(4500.f))
	{
		return;
	}
	const float ZOff = CachedSportNeuro.DunkJumpWarpZOffsetCM * ZScale;
	const FVector WarpLoc = FELMotionWarping::ComputeDunkWarpLocationWithPRQ(
		Best->GetActorLocation(),
		GetActorLocation(),
		ZOff,
		CachedPRQScore,
		CachedGearMotionWarpMult);
	FELMotionWarping::SetJumpWarpToTarget(MotionWarping, WarpLoc, FELMotionWarping::JumpAlignTargetName);
	W->GetTimerManager().ClearTimer(MotionWarpClearTimerHandle);
	TWeakObjectPtr<UMotionWarpingComponent> WeakMW(MotionWarping);
	W->GetTimerManager().SetTimer(
		MotionWarpClearTimerHandle,
		[WeakMW]()
		{
			if (WeakMW.IsValid())
			{
				FELMotionWarping::ClearWarpTarget(WeakMW.Get(), FELMotionWarping::JumpAlignTargetName);
			}
		},
		0.85f,
		false);
	AscentRimSnapCooldownRemaining = 0.35f;
}

void AFELBasketballCharacter::TickSignatureTrait(float DeltaSeconds)
{
	SignatureMoveCooldownRemaining = FMath::Max(0.f, SignatureMoveCooldownRemaining - DeltaSeconds);
	SignatureAuraBlend01 = FMath::Max(0.f, SignatureAuraBlend01 - DeltaSeconds * 0.55f);

	if (!bBondsApexIgnitionSeekApex)
	{
		return;
	}
	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M || M->IsMovingOnGround())
	{
		bBondsApexIgnitionSeekApex = false;
		bBondsApexWasRising = false;
		return;
	}
	const float Vz = M->Velocity.Z;
	if (bBondsApexWasRising && Vz <= 40.f)
	{
		SpawnSignatureSonicFlareAtApex();
		bBondsApexIgnitionSeekApex = false;
		bBondsApexWasRising = false;
		return;
	}
	if (Vz > 180.f)
	{
		bBondsApexWasRising = true;
	}
}

void AFELBasketballCharacter::BroadcastPerfectStrikeImpact()
{
	OnPerfectStrike.Broadcast();
	FELNativeBridge::NotifyPerfectImpactHaptics(true);
	UWorld* const W = GetWorld();
	if (!W || !NeuroFlowSonicBoomVFX)
	{
		return;
	}
	const FVector Loc =
		GetMesh() ? GetMesh()->GetComponentLocation() + GetActorForwardVector() * 95.f : GetActorLocation() + FVector(0.f, 0.f, 96.f);
	UNiagaraFunctionLibrary::SpawnSystemAtLocation(W, NeuroFlowSonicBoomVFX, Loc, GetActorRotation(), FVector(1.05f), true, true);
}

FVector AFELBasketballCharacter::GetNearestHoopLocationForVFX() const
{
	UWorld* const W = GetWorld();
	if (!W)
	{
		return GetActorLocation();
	}
	TArray<AActor*> Hoops;
	UGameplayStatics::GetAllActorsOfClass(W, AFELHoopTargetActor::StaticClass(), Hoops);
	AActor* Best = nullptr;
	float BestD = 1e30f;
	for (AActor* A : Hoops)
	{
		if (!A)
		{
			continue;
		}
		const float D = FVector::DistSquared(GetActorLocation(), A->GetActorLocation());
		if (D < BestD)
		{
			BestD = D;
			Best = A;
		}
	}
	if (Best && BestD < FMath::Square(6500.f))
	{
		return Best->GetActorLocation();
	}
	return GetMesh() ? GetMesh()->GetComponentLocation() + FVector(0.f, 0.f, 140.f) : GetActorLocation();
}

void AFELBasketballCharacter::EnsureNeuroFlowMaterialDynamics()
{
	if (bNeuroFlowMIDsEnsured)
	{
		return;
	}
	USkeletalMeshComponent* const Sk = GetMesh();
	if (!Sk)
	{
		return;
	}
	bNeuroFlowMIDsEnsured = true;
	NeuroFlowMaterialDynamics.Empty();
	const int32 Num = Sk->GetNumMaterials();
	for (int32 i = 0; i < Num; ++i)
	{
		if (UMaterialInterface* Base = Sk->GetMaterial(i))
		{
			UMaterialInstanceDynamic* Mid = UMaterialInstanceDynamic::Create(Base, this);
			Sk->SetMaterial(i, Mid);
			NeuroFlowMaterialDynamics.Add(Mid);
		}
	}
}

void AFELBasketballCharacter::UpdateNeuroFlowCharacterMaterials(float DeltaSeconds)
{
	(void)DeltaSeconds;
	if (NeuroFlowMaterialDynamics.Num() == 0 || !GetWorld())
	{
		return;
	}
	const float Prq01 = FMath::Clamp(CachedPRQScore / 100.f, 0.f, 1.f);
	const bool bPrimed = CachedPRQScore > 85.f;
	const float Pulse = bPrimed ? FMath::Sin(GetWorld()->GetTimeSeconds() * 5.75f) * 0.5f + 0.5f : 0.f;
	const float Sync = PrimedPostProcessBlend;
	const FLinearColor CyanSignal(0.12f, 0.96f, 1.f, 1.f);
	const int32 JerseyIdx = NeuroFlowJerseyMaterialIndex;
	for (int32 i = 0; i < NeuroFlowMaterialDynamics.Num(); ++i)
	{
		UMaterialInstanceDynamic* Mid = NeuroFlowMaterialDynamics[i];
		if (!Mid)
		{
			continue;
		}
		const bool bJersey = (i == JerseyIdx);
		const float PulseScale = bJersey && bPrimed ? 1.38f : 1.f;
		Mid->SetScalarParameterValue(TEXT("FEL_NeuroFlowPulse"), Sync * Pulse * PulseScale);
		const float VelScalar = FMath::Max(Prq01 * 0.22f, Sync * Prq01);
		const float NeuroFlowIntensity =
			bPrimed ? FMath::Lerp(0.55f, 1.f, Prq01) * (0.65f + 0.35f * Pulse) * Sync : FMath::Lerp(0.08f, 0.42f, Prq01);
		Mid->SetScalarParameterValue(TEXT("FEL_NeuroFlowIntensity"), NeuroFlowIntensity);
		Mid->SetScalarParameterValue(TEXT("FEL_SignalVelocity"), VelScalar * (bJersey ? 1.12f : 1.f));
		Mid->SetVectorParameterValue(TEXT("FEL_NeuroFlowAccent"), CyanSignal * VelScalar);
		Mid->SetScalarParameterValue(TEXT("FEL_PostProcessNeuroSync"), Sync);
		if (bJersey)
		{
			const float JerseyBreath = bPrimed ? Pulse : 0.f;
			Mid->SetScalarParameterValue(TEXT("FEL_JerseyNeuroPulse"), JerseyBreath);
			const float EmissiveScale = FMath::Lerp(0.12f, 0.95f, JerseyBreath) * (0.35f + 0.65f * Sync);
			Mid->SetVectorParameterValue(TEXT("FEL_JerseyEmissiveCyan"), CyanSignal * EmissiveScale);
		}
		const float SigBlend = SignatureAuraBlend01;
		if (SigBlend > 0.002f && CachedSignatureTrait != EFELSignatureTrait::None)
		{
			const FLinearColor SigCol = FEL_SignatureAuraColorForTrait(CachedSignatureTrait);
			Mid->SetVectorParameterValue(TEXT("FEL_SignatureAuraColor"), SigCol * SigBlend);
			Mid->SetScalarParameterValue(TEXT("FEL_SignatureAuraIntensity"), SigBlend);
		}
	}
}

void AFELBasketballCharacter::SpawnPerfectDunkRimNiagara()
{
	UWorld* const W = GetWorld();
	if (!W || !NeuroFlowSonicBoomVFX)
	{
		return;
	}
	const FVector Loc = GetNearestHoopLocationForVFX();
	const float Scale = FMath::Lerp(0.95f, 1.45f, FMath::Clamp(CachedPRQScore / 100.f, 0.f, 1.f));
	UNiagaraFunctionLibrary::SpawnSystemAtLocation(W, NeuroFlowSonicBoomVFX, Loc, FRotator::ZeroRotator, FVector(Scale), true, true);
}

void AFELBasketballCharacter::ApplyBiometricContext_Implementation(const FFELBiometricContext& Context)
{
	FFELReadinessSnapshot Snap;
	Snap.EfficiencyScore = Context.EfficiencyScore;
	Snap.PRQScore = Context.PRQScore;
	Snap.NeuralDrive = Context.NeuralDrive;
	Snap.PopForce = Context.PopForce;
	Snap.VerticalEstimateInches = Context.VerticalEstimateInches;
	Snap.HangTimeScale = Context.HangTimeScale;
	Snap.KineticLeakageMultiplier = Context.KineticLeakageMultiplier;
	ApplyReadiness(Snap);
	ApplyPRQNeuralDriveToMovement(static_cast<float>(Snap.PRQScore));
}

void AFELBasketballCharacter::ApplyReadiness(const FFELReadinessSnapshot& Snap)
{
	CachedNeuralDrive = FMath::Clamp(static_cast<float>(Snap.NeuralDrive), 0.f, 100.f);
	CachedPRQScore = FMath::Clamp(static_cast<float>(Snap.PRQScore), 0.f, 100.f);
	CachedAnkleHeat01 = FMath::Clamp(static_cast<float>(Snap.KineticHeatAnkle), 0.f, 1.f);
	CachedKneeHeat01 = FMath::Clamp(static_cast<float>(Snap.KineticHeatKnee), 0.f, 1.f);
	CachedKineticLeakageMult = FMath::Clamp(static_cast<float>(Snap.KineticLeakageMultiplier), 0.35f, 1.f);
	CachedActiveArenaMode = Snap.ActiveArenaMode;
	CachedGearMotionWarpMult = FMath::Clamp(static_cast<float>(Snap.GearMotionWarpMultiplier), 1.f, 1.06f);
	CachedGearJumpMult = FMath::Clamp(static_cast<float>(Snap.GearJumpVelocityMultiplier), 1.f, 1.06f);
	CachedNeuroFlowIntensityScale = FMath::Clamp(static_cast<float>(Snap.NeuroFlowIntensityScale), 1.f, 1.2f);
	CachedStoodCardJumpScale = FMath::Clamp(static_cast<float>(Snap.StoodCardJumpScale), 1.f, 1.12f);
	CachedStoodCardNeuralAlpha = FMath::Clamp(static_cast<float>(Snap.StoodCardNeuralDriveAlpha), 1.f, 1.15f);
	CachedStoodCardTier = Snap.StoodCardTier.IsEmpty() ? TEXT("standard") : Snap.StoodCardTier;
	CachedSignatureTrait = Snap.SignatureTrait;
	CachedNeuroFlowAuraColor = FEL_NeuroFlowAuraColorForTier(CachedStoodCardTier);
	if (NeuroDriveFootGlow)
	{
		NeuroDriveFootGlow->SetLightColor(CachedNeuroFlowAuraColor);
	}
	if (NeuroDriveHandGlow)
	{
		NeuroDriveHandGlow->SetLightColor(CachedNeuroFlowAuraColor);
	}
	if (LandingIK)
	{
		LandingIK->SetKineticHeats(CachedAnkleHeat01, CachedKneeHeat01);
	}

	if (USkeletalMeshComponent* Sk = GetMesh())
	{
		const float HS = FMath::Clamp(static_cast<float>(Snap.AvatarHeightScale), 0.65f, 1.35f);
		const float WS = FMath::Clamp(static_cast<float>(Snap.AvatarWeightScale), 0.65f, 1.35f);
		Sk->SetRelativeScale3D(FVector(WS, WS, HS));
	}

	if (UCharacterMovementComponent* M = GetCharacterMovement())
	{
		const float V = FMath::Clamp(static_cast<float>(Snap.VerticalPotential), 0.f, 100.f);
		const float VIn = FMath::Clamp(static_cast<float>(Snap.VerticalEstimateInches), 0.f, 72.f);
		const float N = CachedNeuralDrive;
		const float P = FMath::Clamp(static_cast<float>(Snap.PRQScore), 0.f, 100.f);
		const float Eff = FMath::Clamp(static_cast<float>(Snap.EfficiencyScore), 0.f, 100.f);

		const float Potential = FELNeuroMechanicPhysics::PotentialJumpZFromVerticalInches(VIn);
		const float Drive = FELNeuroMechanicPhysics::NeuralDriveRealizationFactor(N);
		const float EffScale = FELNeuroMechanicPhysics::EfficiencyHeightScale(Eff);
		const float Train = FELNeuroMechanicPhysics::VerticalTrainingBonus(V);
		const float BaseJump = Potential * Drive * EffScale + P * 0.14f + Train;

		M->JumpZVelocity = FELKineticLeakage::ApplyNeuroMechanicJump(BaseJump, Snap) * CachedGearJumpMult * CachedStoodCardJumpScale;
		// Sovereign / MyTeam gear: FELArenaDifficultyScaling::CalculateGearBoost (jersey/shoe paths including "Sovereign") replaces the
		// Swift GearJumpVelocityMultiplier for physics via multiply-then-divide — no double-stack with PRQ export aggregates.
		float CppGearJump = 1.f;
		const bool bHasGearPaths = !Snap.JerseyTexturePath.IsEmpty() || !Snap.ShoeTexturePath.IsEmpty();
		if (bHasGearPaths)
		{
			if (!Snap.JerseyTexturePath.IsEmpty())
			{
				CppGearJump *= FELArenaDifficultyScaling::CalculateGearBoost(Snap.JerseyTexturePath).JumpVelocityScaleMult;
			}
			if (!Snap.ShoeTexturePath.IsEmpty())
			{
				CppGearJump *= FELArenaDifficultyScaling::CalculateGearBoost(Snap.ShoeTexturePath).JumpVelocityScaleMult;
			}
			CppGearJump = FMath::Clamp(CppGearJump, 1.f, 1.08f);
			M->JumpZVelocity *= CppGearJump / FMath::Max(1.f, CachedGearJumpMult);
		}
		const float NetGearScaleApplied =
			bHasGearPaths ? (CppGearJump / FMath::Max(1.f, CachedGearJumpMult)) : CachedGearJumpMult;
		if (bHasGearPaths)
		{
			UE_LOG(LogFEL, Display,
				TEXT("Gold Master: Jump Scale Applied: %f | JumpZ=%.1f SwiftGearMult=%.4f CppPathMult=%.4f"),
				NetGearScaleApplied,
				M->JumpZVelocity,
				CachedGearJumpMult,
				CppGearJump);
		}
		const float BaseSpeed = 380.f + N * 1.8f + P * 0.25f;
		M->MaxWalkSpeed = FELKineticLeakage::ApplyNeuroMechanicWalkSpeed(BaseSpeed, Snap);
		CachedJumpZAfterNeuroPipeline = M->JumpZVelocity;
		CachedNeuroMaxWalkSpeed = M->MaxWalkSpeed;
	}
}

void AFELBasketballCharacter::ApplyPRQNeuralDriveToMovement(const float PRQ0to100)
{
	if (UCharacterMovementComponent* M = GetCharacterMovement())
	{
		const FFELPRQInfluenceMultipliers Mults = FELPRQInfluence::ComputeMultipliersFromPRQ(PRQ0to100);
		M->JumpZVelocity *= Mults.JumpHeightMultiplier;
		M->MaxWalkSpeed *= Mults.SprintSpeedMultiplier;
		CachedJumpZAfterNeuroPipeline = M->JumpZVelocity;
		CachedNeuroMaxWalkSpeed = M->MaxWalkSpeed;
	}
}

void AFELBasketballCharacter::ApplyArenaPhysicsLayer(const FFELArenaRules& Rules)
{
	CachedSportNeuro = Rules.SportNeuro;
	if (UCharacterMovementComponent* M = GetCharacterMovement())
	{
		M->JumpZVelocity *= Rules.PhysicsJumpScale;
		M->MaxWalkSpeed *= Rules.PhysicsWalkScale;
		CachedJumpZAfterNeuroPipeline = M->JumpZVelocity;
		CachedNeuroMaxWalkSpeed = M->MaxWalkSpeed;
	}
}

void AFELBasketballCharacter::PlayTwinBirthIntro(const float DurationSeconds)
{
	if (CinematicCamera)
	{
		CinematicCamera->BeginTwinBirthCinematic(DurationSeconds);
	}
	TriggerNeuroFlow();
}

void AFELBasketballCharacter::ApplyNeuroArenaGameplay(const FFELReadinessSnapshot& Snap, const FFELArenaRules& Rules)
{
	bIsDunkContestContext = Rules.bIsDunkContest;
	bIsStreetJamContext = Rules.bStreetJamArcade && !Rules.bIsDunkContest;
	NeuroHangTimeScaleCached = static_cast<float>(FMath::Clamp(Snap.HangTimeScale, 0.65, 1.35));
	CachedNeuralDrive = FMath::Clamp(static_cast<float>(Snap.NeuralDrive), 0.f, 100.f);

	if (UCharacterMovementComponent* M = GetCharacterMovement())
	{
		DefaultMovementGravityScale = M->GravityScale;
		if (!bIsDunkContestContext)
		{
			M->GravityScale = DefaultMovementGravityScale;
		}
		// Academy → Arena: Plyos mastery (+2% default) scales realized jump neuro in Dunk Contest only.
		if (bIsDunkContestContext && Snap.AcademyPlyosMasteryBonus > 0.0)
		{
			const float Mult = 1.f + static_cast<float>(FMath::Clamp(Snap.AcademyPlyosMasteryBonus, 0.0, 0.25));
			M->JumpZVelocity *= Mult;
			CachedJumpZAfterNeuroPipeline = M->JumpZVelocity;
		}

		const EFELArenaMode CourtMode = FELArenaModeFromIdString(Snap.ActiveArenaMode);
		if (CourtMode == EFELArenaMode::Tennis || CourtMode == EFELArenaMode::Volleyball)
		{
			const float SwitchWalk = FELSwitchSportsGameplay::ComputeCourtWalkSpeedMultiplier(Snap, Rules.SportNeuro, nullptr);
			M->MaxWalkSpeed *= SwitchWalk;
			CachedNeuroMaxWalkSpeed = M->MaxWalkSpeed;
		}

		if (bIsStreetJamContext)
		{
			UFELCreatorCard* Card = nullptr;
			if (UWorld* W = GetWorld())
			{
				if (UGameInstance* GI = W->GetGameInstance())
				{
					if (UFELStreetJamSessionSubsystem* Jam = GI->GetSubsystem<UFELStreetJamSessionSubsystem>())
					{
						Card = Jam->GetBoundCreatorCard();
					}
				}
			}
			const float StreetWalk = FELSwitchSportsGameplay::ComputeCourtWalkSpeedMultiplier(Snap, Rules.SportNeuro, Card);
			M->MaxWalkSpeed *= StreetWalk;
			float CE = 1.f;
			float CS = 1.f;
			FELDojoNeuralTempest::ResolveCreatorCardComposites(Snap, Card, CE, CS);
			const float Perf = FMath::Clamp(FMath::Sqrt(CE * CS), 0.75f, 1.42f);
			const float Perf01 = FMath::Clamp((Perf - 0.75f) / (1.42f - 0.75f + KINDA_SMALL_NUMBER), 0.f, 1.f);
			M->JumpZVelocity *= FMath::Lerp(0.97f, 1.055f, Perf01);
			CachedJumpZAfterNeuroPipeline = M->JumpZVelocity;
			CachedNeuroMaxWalkSpeed = M->MaxWalkSpeed;
		}
	}

	ApplyPRQNeuralDriveToMovement(static_cast<float>(Snap.PRQScore));

	UpdateNeuroDriveVisuals(CachedNeuralDrive);
}

void AFELBasketballCharacter::UpdateNeuroDriveVisuals(const float NeuralDrivePercent)
{
	const bool bHigh = NeuralDrivePercent >= 85.f;
	bNeuroDriveGlowActive = bHigh;
	const float Intensity = bHigh ? 320.f : 0.f;
	if (NeuroDriveFootGlow)
	{
		NeuroDriveFootGlow->SetIntensity(Intensity);
		NeuroDriveFootGlow->SetVisibility(bHigh);
	}
	if (NeuroDriveHandGlow)
	{
		NeuroDriveHandGlow->SetIntensity(Intensity * 0.85f);
		NeuroDriveHandGlow->SetVisibility(bHigh);
	}
}

float AFELBasketballCharacter::ComputeLateralStrain01() const
{
	const UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M)
	{
		return 0.f;
	}
	const FVector Vel(M->Velocity.X, M->Velocity.Y, 0.f);
	if (Vel.IsNearlyZero())
	{
		return 0.f;
	}
	const FVector Right(GetActorRightVector().X, GetActorRightVector().Y, 0.f);
	const float Lateral = FMath::Abs(FVector::DotProduct(Vel, Right.GetSafeNormal()));
	const float MaxS = FMath::Max(CachedNeuroMaxWalkSpeed, 120.f);
	return FMath::Clamp(Lateral / MaxS, 0.f, 1.f);
}

void AFELBasketballCharacter::ApplyLateralWalkFromNeuro()
{
	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M)
	{
		return;
	}
	UGameInstance* const GI = GetGameInstance();
	if (!GI)
	{
		return;
	}
	UFELNeuroMechanicBridgeSubsystem* const Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>();
	float GhostMult = 1.f;
	if (UWorld* W = GetWorld())
	{
		if (W->GetTimeSeconds() < static_cast<float>(SignatureGhostStrikeUntilTime))
		{
			GhostMult = 1.28f;
		}
	}
	if (!Br || !Br->HasCachedSnapshot())
	{
		M->MaxWalkSpeed = CachedNeuroMaxWalkSpeed * FMath::Lerp(1.f, 1.14f, TouchSprintBlend01) * GhostMult;
		return;
	}
	FFELReadinessSnapshot Snap;
	Br->GetCachedSnapshot(Snap);
	FFELArenaRules Rules;
	Br->GetCurrentArenaSettings(Rules);
	const EFELArenaMode Mode = FELArenaModeFromIdString(Snap.ActiveArenaMode);
	const float Mult = FELKineticLeakage::ApplyLateralCutWalkMultiplier(
		static_cast<float>(Snap.NeuralDrive),
		static_cast<float>(Snap.KineticLeakageMultiplier),
		ComputeLateralStrain01(),
		Mode,
		Rules.SportNeuro);
	M->MaxWalkSpeed = CachedNeuroMaxWalkSpeed * Mult * FMath::Lerp(1.f, 1.14f, TouchSprintBlend01) * GhostMult;
}

void AFELBasketballCharacter::TickApproachRun(float DeltaSeconds)
{
	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M || !M->IsMovingOnGround())
	{
		return;
	}
	const float Speed2D = M->Velocity.Size2D();
	if (Speed2D >= ApproachSpeedThresholdUU)
	{
		const float GatherBoost = 1.f + 0.95f * TouchGatherBlend01;
		ApproachRunSeconds += DeltaSeconds * GatherBoost;
		ApproachRunSeconds = FMath::Min(ApproachRunSeconds, 2.5f);
	}
}

void AFELBasketballCharacter::ApplyMidAirNeuralCorrection(float DeltaSeconds)
{
	if (!bIsDunkContestContext || CachedNeuralDrive < 90.f)
	{
		return;
	}
	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M || M->IsMovingOnGround())
	{
		return;
	}
	const float Elite = FMath::Clamp((CachedNeuralDrive - 90.f) / 10.f, 0.f, 1.f);
	const FVector Wish = M->GetLastInputVector();
	if (Wish.IsNearlyZero())
	{
		return;
	}
	FVector Planar(Wish.X, Wish.Y, 0.f);
	if (Planar.IsNearlyZero())
	{
		return;
	}
	Planar.Normalize();
	const float NudgeUU = 620.f * Elite * DeltaSeconds;
	M->Velocity += Planar * NudgeUU;
}

void AFELBasketballCharacter::TriggerNeuroFlow()
{
	NeuroFlowRemainSec = 4.5f;
	bNeuroFlowActive = true;
	PlayNeuroFlowAudioCue();

	if (NeuroFlowSonicBoomVFX)
	{
		UWorld* const W = GetWorld();
		USkeletalMeshComponent* const Sk = GetMesh();
		if (W && Sk)
		{
			static const FName HandR(TEXT("hand_r"));
			FVector Loc = Sk->DoesSocketExist(HandR) ? Sk->GetSocketLocation(HandR)
			                                        : GetActorLocation() + FVector(0.f, 0.f, 110.f);
			const float Scale = FMath::Lerp(0.75f, 1.35f, FMath::Clamp(CachedPRQScore / 100.f, 0.f, 1.f));
			const FRotator Rot = GetActorRotation();
			UNiagaraFunctionLibrary::SpawnSystemAtLocation(W, NeuroFlowSonicBoomVFX, Loc, Rot, FVector(Scale), true, true);
		}
	}
}

void AFELBasketballCharacter::PlayNeuroFlowAudioCue()
{
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	if (NeuroFlowSonicCue)
	{
		UGameplayStatics::PlaySound2D(W, NeuroFlowSonicCue);
	}
	if (NeuroFlowDuckMix)
	{
		UGameplayStatics::PushSoundMixModifier(W, NeuroFlowDuckMix);
		bNeuroFlowDuckMixPushed = true;
		GetWorldTimerManager().ClearTimer(NeuroFlowAudioMixTimerHandle);
		GetWorldTimerManager().SetTimer(NeuroFlowAudioMixTimerHandle, this, &AFELBasketballCharacter::PopNeuroFlowDuckMix, 2.5f, false);
	}
}

void AFELBasketballCharacter::PopNeuroFlowDuckMix()
{
	if (!bNeuroFlowDuckMixPushed)
	{
		return;
	}
	UWorld* const W = GetWorld();
	if (W && NeuroFlowDuckMix)
	{
		UGameplayStatics::PopSoundMixModifier(W, NeuroFlowDuckMix);
	}
	bNeuroFlowDuckMixPushed = false;
}

void AFELBasketballCharacter::ApplyNeuroLayerBlendToAnimInstance()
{
	USkeletalMeshComponent* const Sk = GetMesh();
	if (!Sk)
	{
		return;
	}
	UAnimInstance* const AI = Sk->GetAnimInstance();
	if (!AI || !AI->GetClass()->ImplementsInterface(UFELNeuroAnimLayerInterface::StaticClass()))
	{
		return;
	}
	const float BasePrim = FELNeuroAnimLayerBlend::CombinedPrimedAlpha(CachedPRQScore, CachedKineticLeakageMult);
	const float ExtraLeaky = FELArenaDifficultyScaling::LeakyAnimLayerExtraFromPRQ(CachedPRQScore);
	const float Prim = FMath::Clamp(FMath::Max(0.f, BasePrim * (1.f - ExtraLeaky)) * CachedStoodCardNeuralAlpha, 0.f, 1.f);
	const float Hip = FELNeuroAnimLayerBlend::HipExtensionScaleFromLeakage(CachedKineticLeakageMult);
	IFELNeuroAnimLayerInterface::Execute_FEL_ApplyNeuroLayerBlend(AI, CachedPRQScore, Prim, Hip);
}

void AFELBasketballCharacter::ApplyJumpTakeoffAnimWarp(const EFELJumpTimingBand Band)
{
	USkeletalMeshComponent* const Sk = GetMesh();
	if (!Sk)
	{
		return;
	}
	UAnimInstance* const AI = Sk->GetAnimInstance();
	if (!AI)
	{
		return;
	}

	const TSoftObjectPtr<UAnimSequence>* SeqPtr = CachedSportNeuro.JumpTimingTakeoffSequences.Find(Band);
	if (!SeqPtr || SeqPtr->IsNull())
	{
		SeqPtr = CachedSportNeuro.JumpTimingTakeoffSequences.Find(EFELJumpTimingBand::Good);
	}
	UAnimSequence* Seq = nullptr;
	if (SeqPtr && !SeqPtr->IsNull())
	{
		Seq = SeqPtr->Get();
		if (!Seq)
		{
			Seq = SeqPtr->LoadSynchronous();
		}
	}

	UAnimMontage* MontageToPlay = nullptr;
	if (Seq)
	{
		MontageToPlay = UAnimMontage::CreateSlotAnimationAsDynamicMontage(
			Cast<UAnimSequenceBase>(Seq),
			FName(TEXT("DefaultSlot")),
			0.25f,
			0.25f,
			1.f,
			1);
#if !UE_BUILD_SHIPPING
		if (!MontageToPlay)
		{
			UE_LOG(LogFEL, Verbose, TEXT("ApplyJumpTakeoffAnimWarp: CreateSlotAnimationAsDynamicMontage failed (sequence/skeleton vs mesh)."));
		}
#endif
	}

	if (MontageToPlay)
	{
		AI->Montage_Play(MontageToPlay);
	}

	UWorld* const W = GetWorld();
	if (W && MotionWarping)
	{
		TArray<AActor*> Hoops;
		UGameplayStatics::GetAllActorsOfClass(W, AFELHoopTargetActor::StaticClass(), Hoops);
		AActor* Best = nullptr;
		float BestD = 1e30f;
		for (AActor* A : Hoops)
		{
			if (!A)
			{
				continue;
			}
			const float D = FVector::DistSquared(GetActorLocation(), A->GetActorLocation());
			if (D < BestD)
			{
				BestD = D;
				Best = A;
			}
		}
		if (Best && BestD < FMath::Square(4500.f))
		{
			const FVector WarpLoc = FELMotionWarping::ComputeDunkWarpLocationWithPRQ(
				Best->GetActorLocation(),
				GetActorLocation(),
				CachedSportNeuro.DunkJumpWarpZOffsetCM,
				CachedPRQScore,
				CachedGearMotionWarpMult);
			FELMotionWarping::SetJumpWarpToTarget(MotionWarping, WarpLoc, FELMotionWarping::JumpAlignTargetName);
			W->GetTimerManager().ClearTimer(MotionWarpClearTimerHandle);
			TWeakObjectPtr<UMotionWarpingComponent> WeakMW(MotionWarping);
			W->GetTimerManager().SetTimer(
				MotionWarpClearTimerHandle,
				[WeakMW]()
				{
					if (WeakMW.IsValid())
					{
						FELMotionWarping::ClearWarpTarget(WeakMW.Get(), FELMotionWarping::JumpAlignTargetName);
					}
				},
				0.85f,
				false);
		}
	}

	if (!MontageToPlay)
	{
		float Rate = 1.f;
		if (Band == EFELJumpTimingBand::Perfect)
		{
			Rate = 1.1f;
		}
		else if (Band == EFELJumpTimingBand::Early || Band == EFELJumpTimingBand::Late)
		{
			Rate = 0.85f;
		}

		if (USkeletalMeshComponent* RateMesh = GetMesh())
		{
			RateMesh->GlobalAnimRateScale = Rate;
			TWeakObjectPtr<USkeletalMeshComponent> WeakSk(RateMesh);
			GetWorldTimerManager().ClearTimer(JumpWarpResetTimerHandle);
			GetWorldTimerManager().SetTimer(
				JumpWarpResetTimerHandle,
				[WeakSk]()
				{
					if (WeakSk.IsValid())
					{
						WeakSk->GlobalAnimRateScale = 1.f;
					}
				},
				0.35f,
				false);
		}
	}
}

void AFELBasketballCharacter::SpawnBondsBounceLeakVFX(const float TimingLeak)
{
	if (TimingLeak >= 0.7f || !BondsBounceLeakVFX)
	{
		return;
	}
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	const float HalfZ = GetCapsuleComponent() ? GetCapsuleComponent()->GetScaledCapsuleHalfHeight() : 88.f;
	const FVector SpawnLoc = GetActorLocation() - FVector(0.f, 0.f, HalfZ - 4.f);
	const FRotator SpawnRot(0.f, GetActorRotation().Yaw, 0.f);
	UNiagaraFunctionLibrary::SpawnSystemAtLocation(W, BondsBounceLeakVFX, SpawnLoc, SpawnRot, FVector(1.f), true, true);
}

void AFELBasketballCharacter::UpdatePrimedPostProcess(float DeltaSeconds)
{
	if (USkeletalMeshComponent* Sk = GetMesh())
	{
		const bool bPrimed = CachedPRQScore > 85.f;
		Sk->SetRenderCustomDepth(bPrimed);
		if (bPrimed)
		{
			Sk->SetCustomDepthStencilValue(1);
		}
	}

	if (!FollowCamera || !PrimedNeuroPostProcessMaterial)
	{
		PrimedPostProcessBlend = 0.f;
		return;
	}

	const float TargetW = (CachedPRQScore > 85.f) ? FMath::Clamp((CachedPRQScore - 85.f) / 15.f, 0.f, 1.f) : 0.f;
	PrimedPostProcessBlend = FMath::FInterpTo(PrimedPostProcessBlend, TargetW, DeltaSeconds, 3.5f);

	FPostProcessSettings& PP = FollowCamera->PostProcessSettings;
	if (PrimedPostProcessBlend < 0.002f)
	{
		PP.RemoveBlendable(PrimedNeuroPostProcessMaterial);
	}
	else
	{
		PP.AddBlendable(PrimedNeuroPostProcessMaterial, PrimedPostProcessBlend);
	}
}

void AFELBasketballCharacter::PlayPerfectDunkSpatialBoom()
{
	UWorld* const W = GetWorld();
	if (!W || !PerfectDunkStadiumBoomCue)
	{
		return;
	}
	const FVector Loc = GetNearestHoopLocationForVFX();
	const FRotator Rot = GetActorRotation();
	UGameplayStatics::SpawnSoundAtLocation(
		W,
		PerfectDunkStadiumBoomCue,
		Loc,
		Rot,
		1.f,
		1.f,
		0.f,
		PerfectDunkSpatialAttenuation);
}

void AFELBasketballCharacter::UpdateNeuroFlowVisuals(float DeltaSeconds)
{
	if (NeuroFlowRemainSec > 0.f)
	{
		NeuroFlowRemainSec -= DeltaSeconds;
		if (NeuroFlowRemainSec <= 0.f)
		{
			NeuroFlowRemainSec = 0.f;
			bNeuroFlowActive = false;
		}
	}

	const float TargetBlend = (NeuroFlowRemainSec > 0.f) ? FMath::Clamp(NeuroFlowRemainSec / 4.5f, 0.f, 1.f) : 0.f;
	NeuroFlowVisualBlend = FMath::FInterpTo(NeuroFlowVisualBlend, TargetBlend, DeltaSeconds, 2.8f);

	if (UWorld* W = GetWorld())
	{
		// Bonds Apex broadcast (Luma Venice): fixed 0.5 global dilation — overrides Neuro-Flow for ~0.2s game-time window.
		if (bSonicFlareBroadcastHangActive)
		{
			UGameplayStatics::SetGlobalTimeDilation(W, 0.5f);
		}
		// Cinematic replay highlight overrides Neuro-Flow dilation for a few seconds.
		else if (CinematicCamera && CinematicCamera->IsReplayHighlightActive())
		{
			UGameplayStatics::SetGlobalTimeDilation(W, 0.48f);
		}
		else
		{
			// Cinematic apex: global dilation (character CustomTimeDilation stays 1 so we don’t double-stack with world).
			UGameplayStatics::SetGlobalTimeDilation(W, FMath::Lerp(1.f, 0.93f, NeuroFlowVisualBlend));
		}
	}

	if (FollowCamera)
	{
		FPostProcessSettings& PP = FollowCamera->PostProcessSettings;
		if (NeuroFlowVisualBlend > 0.02f)
		{
			// Bloom + vignette + subtle time dilation = "Neuro-Flow"; add Scene Color Fringe / CA material on camera in BP for extra edge separation.
			PP.bOverride_BloomIntensity = true;
			PP.BloomIntensity = FMath::Lerp(1.f, 1.85f, NeuroFlowVisualBlend);
			PP.bOverride_BloomThreshold = true;
			PP.BloomThreshold = FMath::Lerp(-1.f, 0.85f, NeuroFlowVisualBlend);
			PP.bOverride_VignetteIntensity = true;
			PP.VignetteIntensity = FMath::Lerp(0.f, 0.48f, NeuroFlowVisualBlend);
			PP.bOverride_Bloom1Tint = true;
			PP.Bloom1Tint = CachedNeuroFlowAuraColor;
		}
		else
		{
			PP.bOverride_BloomIntensity = false;
			PP.bOverride_BloomThreshold = false;
			PP.bOverride_VignetteIntensity = false;
			PP.bOverride_Bloom1Tint = false;
		}

		if (bSonicFlareBroadcastBloomActive)
		{
			const float BaseBloom = (NeuroFlowVisualBlend > 0.02f)
				? FMath::Lerp(1.f, 1.85f, NeuroFlowVisualBlend)
				: 1.f;
			PP.bOverride_BloomIntensity = true;
			PP.BloomIntensity = BaseBloom * 2.0f;
		}
	}

	UpdateHeroBroadcastCameraFeedback();
}

void AFELBasketballCharacter::UpdateHeroBroadcastCameraFeedback()
{
	if (!FollowCamera)
	{
		return;
	}
	const bool bHang = bSonicFlareBroadcastHangActive;
	if (bHang && !bWasSonicFlareBroadcastHangActive)
	{
		FollowCamera->SetFieldOfView(105.f);
		if (APlayerController* PC = Cast<APlayerController>(GetController()))
		{
			if (SignatureHeroBroadcastCameraShake)
			{
				PC->ClientStartCameraShake(
					SignatureHeroBroadcastCameraShake,
					1.f,
					ECameraShakePlaySpace::CameraLocal,
					FRotator::ZeroRotator);
			}
		}
	}
	else if (!bHang && bWasSonicFlareBroadcastHangActive)
	{
		FollowCamera->SetFieldOfView(DefaultFollowCameraFOV);
	}
	bWasSonicFlareBroadcastHangActive = bHang;
}

void AFELBasketballCharacter::Tick(float DeltaSeconds)
{
	if (UCharacterMovementComponent* MoveCoyote = GetCharacterMovement())
	{
		if (MoveCoyote->IsFalling() && CoyoteTimeRemaining > 0.f)
		{
			CoyoteTimeRemaining = FMath::Max(0.f, CoyoteTimeRemaining - DeltaSeconds);
		}
	}

	Super::Tick(DeltaSeconds);

	TickApproachRun(DeltaSeconds);
	ApplyLateralWalkFromNeuro();
	ApplyMidAirNeuralCorrection(DeltaSeconds);

	AscentRimSnapCooldownRemaining = FMath::Max(0.f, AscentRimSnapCooldownRemaining - DeltaSeconds);

	// Bonds Apex Sonic Flare / broadcast flags before Neuro-Flow post so same-frame global dilation + bloom apply.
	TickSignatureTrait(DeltaSeconds);

	{
		UCharacterMovementComponent* MoveAir = GetCharacterMovement();
		if (MoveAir)
		{
			if (bBondsApexIgnitionSeekApex && MoveAir->IsFalling())
			{
				MoveAir->AirControl = FMath::Min(1.f, CachedAirControlBeforeBondsApexJump * 1.25f);
			}
			else if (bBondsApexSeekingApexPrevFrame && !bBondsApexIgnitionSeekApex)
			{
				MoveAir->AirControl = CachedAirControlBeforeBondsApexJump;
			}
		}
		bBondsApexSeekingApexPrevFrame = bBondsApexIgnitionSeekApex;
	}
	UpdateNeuroFlowVisuals(DeltaSeconds);
	UpdatePrimedPostProcess(DeltaSeconds);
	UpdateNeuroFlowCharacterMaterials(DeltaSeconds);
	if (CinematicCamera)
	{
		CinematicCamera->UpdateApexCamera(DeltaSeconds, NeuroFlowVisualBlend * CachedNeuroFlowIntensityScale, ApproachRunSeconds);
	}
	ApplyNeuroLayerBlendToAnimInstance();

	if (UFELInputComponent* FEL = Cast<UFELInputComponent>(InputComponent))
	{
		FEL->TickInputBuffers(this);
	}

	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M)
	{
		return;
	}

	if (bTrackJumpPeakForStats)
	{
		LastJumpPeakZVelocityForStats = FMath::Max(LastJumpPeakZVelocityForStats, M->Velocity.Z);
	}

	if (!bIsDunkContestContext)
	{
		M->GravityScale = DefaultMovementGravityScale;
		return;
	}

	if (M->IsMovingOnGround())
	{
		M->GravityScale = DefaultMovementGravityScale;
		return;
	}

	const float Vz = M->Velocity.Z;
	const float HT = NeuroHangTimeScaleCached;
	const float Band = FMath::Max(80.f, DunkApexVelocityBand);
	const float ApexT = FMath::Clamp(1.f - FMath::Abs(Vz) / Band, 0.f, 1.f);
	const float Smooth = ApexT * ApexT * (3.f - 2.f * ApexT);
	const float TargetScale = DefaultMovementGravityScale * FMath::Lerp(1.f, 1.f / FMath::Max(0.5f, HT), Smooth);
	M->GravityScale = TargetScale;
}

void AFELBasketballCharacter::Jump()
{
	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M || !CanJump())
	{
		return;
	}
#if PLATFORM_PS5
	const bool bBondsApexCommitSnap = bPendingSignatureApexIgnition && CachedSignatureTrait == EFELSignatureTrait::Bonds_Apex_Ignition;
#endif
	if (AFELBasketballPlayerController* PC = Cast<AFELBasketballPlayerController>(GetController()))
	{
		PC->InputLatencyMonitor_OnCharacterLaunch();
	}
#if PLATFORM_PS5
	if (bBondsApexCommitSnap)
	{
		if (APlayerController* HapPC = Cast<APlayerController>(GetController()))
		{
			FELConsoleHapticBridge::ApplyBondsApexTriggerSnap(HapPC);
		}
	}
#endif

	CachedAirControlBeforeBondsApexJump = M->AirControl;

	bLeftGroundByJump = true;
	bTrackJumpPeakForStats = true;
	LastJumpPeakZVelocityForStats = 0.f;

	const bool bGrounded = M->IsMovingOnGround();
	if (!bGrounded)
	{
		CoyoteTimeRemaining = 0.f;
	}

	// Gear + neuro pipeline (ApplyReadiness); Bonds Apex +20% applies here — before timing leakage — so signature scales the full stack.
	float PostGearJumpZ = CachedJumpZAfterNeuroPipeline;
	if (bPendingSignatureApexIgnition && CachedSignatureTrait == EFELSignatureTrait::Bonds_Apex_Ignition)
	{
		PostGearJumpZ += PendingKineticGatherJumpBoost;
		PendingKineticGatherJumpBoost = 0.f;
		// SM6 vs ES3.1 parity: signature tier maps to fixed multiplier (not frame dt — identical apex height across render feature levels).
		constexpr float SignatureChargeT = 1.f;
		const float BondsApexMult = FMath::GetMappedRangeValueClamped(
			FVector2D(0.f, 1.f),
			FVector2D(1.f, 1.2f),
			SignatureChargeT);
		PostGearJumpZ *= BondsApexMult;
		bBondsApexIgnitionSeekApex = true;
		bBondsApexWasRising = false;
		bPendingSignatureApexIgnition = false;
	}

	EFELJumpTimingBand Band = EFELJumpTimingBand::Good;
	const float TimingLeak = FELKineticLeakage::ComputeBondsBounceTimingLeakage(ApproachRunSeconds, Band);
	LastJumpTimingBand = Band;

	if (bIsDunkContestContext)
	{
		if (UWorld* W = GetWorld())
		{
			if (AFELBasketballGameMode* FelGM = W->GetAuthGameMode<AFELBasketballGameMode>())
			{
				if (AFELBasketballGameState* FelGS = W->GetGameState<AFELBasketballGameState>())
				{
					if (UGameInstance* GI = GetGameInstance())
					{
						if (UFELDunkContestSessionSubsystem* DunkSub = GI->GetSubsystem<UFELDunkContestSessionSubsystem>())
						{
							DunkSub->NotifyJumpApproach(FelGM, FelGS, Band);
						}
					}
				}
			}
		}
	}
	else if (bIsStreetJamContext)
	{
		if (UWorld* W = GetWorld())
		{
			if (AFELBasketballGameMode* FelGM = W->GetAuthGameMode<AFELBasketballGameMode>())
			{
				if (AFELBasketballGameState* FelGS = W->GetGameState<AFELBasketballGameState>())
				{
					if (UGameInstance* GI = GetGameInstance())
					{
						if (UFELStreetJamSessionSubsystem* Jam = GI->GetSubsystem<UFELStreetJamSessionSubsystem>())
						{
							Jam->NotifyJumpGather(FelGM, FelGS, Band);
						}
					}
				}
			}
		}
	}

	float EffectiveLeak = TimingLeak;
	if (bIsDunkContestContext)
	{
		LastJumpTimingLeakFactor = TimingLeak;
		EffectiveLeak = TimingLeak;
		if (Band == EFELJumpTimingBand::Perfect)
		{
			ConsecutivePerfectJumps++;
			if (ConsecutivePerfectJumps >= 3)
			{
				TriggerNeuroFlow();
				ConsecutivePerfectJumps = 0;
			}
		}
		else
		{
			ConsecutivePerfectJumps = 0;
		}
		M->JumpZVelocity = PostGearJumpZ * TimingLeak;
	}
	else
	{
		const float Soft = FMath::Lerp(0.90f, 1.f, FMath::GetRangePct(0.48f, 1.f, TimingLeak));
		LastJumpTimingLeakFactor = Soft;
		EffectiveLeak = Soft;
		M->JumpZVelocity = PostGearJumpZ * Soft;
	}

	if (Band == EFELJumpTimingBand::Perfect)
	{
		ApplyBondsBounceHitStop();
		OnPerfectDunk.Broadcast();
		if (bIsDunkContestContext)
		{
			FELNativeBridge::NotifyPerfectImpactHaptics(false);
		}
		if (UWorld* W = GetWorld())
		{
			W->GetTimerManager().SetTimer(
				PerfectDunkWarpHapticTimerHandle,
				this,
				&AFELBasketballCharacter::OnPerfectDunkWarpHapticTimerFired,
				0.11f,
				false);
		}
		SpawnPerfectDunkRimNiagara();
		PlayPerfectDunkSpatialBoom();
		if (UGameInstance* GI = GetGameInstance())
		{
			if (UFELNeuroFlowShareCaptureSubsystem* Share = GI->GetSubsystem<UFELNeuroFlowShareCaptureSubsystem>())
			{
				Share->RequestNeuroFlowMomentCapture(5.f);
			}
		}
		if (CinematicCamera)
		{
			CinematicCamera->NotifyPerfectTimingBand();
		}
		if (UWorld* W = GetWorld())
		{
			if (AFELBasketballGameState* GS = W->GetGameState<AFELBasketballGameState>())
			{
				GS->AddPerfectTimingHit();
			}
		}
	}

	ApplyJumpTakeoffAnimWarp(Band);
	if (AFELBasketballPlayerController* PC = Cast<AFELBasketballPlayerController>(GetController()))
	{
		PC->PlayBondsBounceHaptics(Band, EffectiveLeak);
	}
	SpawnBondsBounceLeakVFX(EffectiveLeak);

	if (bGrounded)
	{
		Super::Jump();
	}
	else
	{
		M->Velocity.Z = FMath::Max(M->Velocity.Z, M->JumpZVelocity);
	}
	ApproachRunSeconds = 0.f;
}

void AFELBasketballCharacter::Landed(const FHitResult& Hit)
{
	float ImpactZ = 0.f;
	if (UCharacterMovementComponent* MovePre = GetCharacterMovement())
	{
		ImpactZ = FMath::Abs(MovePre->Velocity.Z);
	}

	Super::Landed(Hit);
	CoyoteTimeRemaining = 0.f;
	bLeftGroundByJump = false;
	bTrackJumpPeakForStats = false;
	bBondsApexIgnitionSeekApex = false;
	bBondsApexWasRising = false;
	if (UCharacterMovementComponent* Move = GetCharacterMovement())
	{
		Move->JumpZVelocity = CachedJumpZAfterNeuroPipeline;
	}
	if (LandingIK)
	{
		const bool bStickLanding = bIsDunkContestContext || CachedActiveArenaMode.Contains(TEXT("gymnastics"));
		LandingIK->ApplyLandingFromScan(bStickLanding, CachedAnkleHeat01, CachedKneeHeat01);
	}

	if (HeavyLandingCameraShake)
	{
		if (APlayerController* PC = Cast<APlayerController>(GetController()))
		{
			const float Heat = CachedAnkleHeat01;
			const float Impact01 = FMath::Clamp(ImpactZ / 1100.f, 0.f, 1.f);
			const float Mag = FMath::Clamp(
				FMath::Lerp(0.12f, 1.05f, Heat) * FMath::Lerp(0.25f, 1.f, Impact01),
				0.f,
				1.85f);
			if (Mag > 0.08f && (ImpactZ > 220.f || Heat > 0.35f))
			{
				PC->ClientStartCameraShake(HeavyLandingCameraShake, Mag, ECameraShakePlaySpace::CameraLocal);
			}
		}
	}
}

void AFELBasketballCharacter::OnMovementModeChanged(EMovementMode PrevMovementMode, uint8 PreviousCustomMode)
{
	Super::OnMovementModeChanged(PrevMovementMode, PreviousCustomMode);
	if (UCharacterMovementComponent* M = GetCharacterMovement())
	{
		if (PrevMovementMode == MOVE_Walking && M->IsFalling())
		{
			if (!bLeftGroundByJump)
			{
				CoyoteTimeRemaining = CoyoteTimeSeconds;
			}
			bLeftGroundByJump = false;
		}
		if (M->IsMovingOnGround())
		{
			ApproachRunSeconds = 0.f;
			CoyoteTimeRemaining = 0.f;
		}
	}
}

void AFELBasketballCharacter::OnPerfectDunkWarpHapticTimerFired()
{
	FELNativeBridge::NotifyPerfectDunkWarpThud();
}

void AFELBasketballCharacter::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	GetWorldTimerManager().ClearTimer(JumpWarpResetTimerHandle);
	GetWorldTimerManager().ClearTimer(NeuroFlowAudioMixTimerHandle);
	GetWorldTimerManager().ClearTimer(HitStopResetTimerHandle);
	GetWorldTimerManager().ClearTimer(PerfectDunkWarpHapticTimerHandle);
	GetWorldTimerManager().ClearTimer(SonicFlareBroadcastTimerHandle);
	bSonicFlareBroadcastHangActive = false;
	bSonicFlareBroadcastBloomActive = false;
#if PLATFORM_PS5
	PopVeniceMirrorFinishRt();
#endif
	if (UWorld* W = GetWorld())
	{
		UGameplayStatics::SetGlobalTimeDilation(W, 1.f);
	}
	PopNeuroFlowDuckMix();
	Super::EndPlay(EndPlayReason);
}

void AFELBasketballCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);

	PlayerInputComponent->BindAxis("MoveForward", this, &AFELBasketballCharacter::MoveForward);
	PlayerInputComponent->BindAxis("MoveRight", this, &AFELBasketballCharacter::MoveRight);
	PlayerInputComponent->BindAxis("Turn", this, &AFELBasketballCharacter::Turn);
	PlayerInputComponent->BindAxis("LookUp", this, &AFELBasketballCharacter::LookUp);
	PlayerInputComponent->BindAction("Jump", IE_Pressed, this, &AFELBasketballCharacter::FEL_OnJumpPressed);
	PlayerInputComponent->BindAction("Jump", IE_Released, this, &AFELBasketballCharacter::FEL_OnJumpReleased);
}

void AFELBasketballCharacter::FEL_OnJumpPressed()
{
	if (AFELBasketballPlayerController* PC = Cast<AFELBasketballPlayerController>(GetController()))
	{
		PC->InputLatencyMonitor_MarkPress();
		if (PC->TryHandleBaseballJumpAsSwing())
		{
			return;
		}
	}
	if (CanJump())
	{
		Jump();
	}
	else if (UFELInputComponent* FEL = Cast<UFELInputComponent>(InputComponent))
	{
		FEL->BufferJump();
	}
}

void AFELBasketballCharacter::FEL_OnJumpReleased()
{
	StopJumping();
}

void AFELBasketballCharacter::ApplyBondsBounceHitStop()
{
	CustomTimeDilation = 0.05f;
	if (GetWorld())
	{
		GetWorldTimerManager().SetTimer(
			HitStopResetTimerHandle,
			this,
			&AFELBasketballCharacter::ClearBondsBounceHitStop,
			2.f / 60.f,
			false);
	}
}

void AFELBasketballCharacter::ClearBondsBounceHitStop()
{
	CustomTimeDilation = 1.f;
}

void AFELBasketballCharacter::MoveForward(float Value)
{
	if (Controller && !FMath::IsNearlyZero(Value))
	{
		const FRotator YawRot(0.f, Controller->GetControlRotation().Yaw, 0.f);
		AddMovementInput(FRotationMatrix(YawRot).GetUnitAxis(EAxis::X), Value);
	}
}

void AFELBasketballCharacter::MoveRight(float Value)
{
	if (Controller && !FMath::IsNearlyZero(Value))
	{
		const FRotator YawRot(0.f, Controller->GetControlRotation().Yaw, 0.f);
		AddMovementInput(FRotationMatrix(YawRot).GetUnitAxis(EAxis::Y), Value);
	}
}

void AFELBasketballCharacter::Turn(float Value)
{
	AddControllerYawInput(Value);
}

void AFELBasketballCharacter::LookUp(float Value)
{
	AddControllerPitchInput(Value);
}
