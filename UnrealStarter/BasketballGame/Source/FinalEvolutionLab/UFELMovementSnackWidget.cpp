// Copyright (c) Final Evolution Lab.

#include "UFELMovementSnackWidget.h"
#include "UFELAssetRegistrySubsystem.h"
#include "Animation/AnimInstance.h"
#include "Animation/AnimMontage.h"
#include "Components/SkeletalMeshComponent.h"
#include "Engine/GameInstance.h"
#include "Engine/StreamableManager.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PlayerController.h"
#include "TimerManager.h"

void UFELMovementSnackWidget::NativeConstruct()
{
	Super::NativeConstruct();
}

void UFELMovementSnackWidget::NativeDestruct()
{
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(PoseBlendTimerHandle);
		W->GetTimerManager().ClearTimer(SnackDemoTimerHandle);
		W->GetTimerManager().ClearTimer(DemonstrationLoadFallbackTimer);
	}
	if (DemonstrationMontageLoadHandle.IsValid())
	{
		DemonstrationMontageLoadHandle->CancelHandle();
		DemonstrationMontageLoadHandle.Reset();
	}
	Super::NativeDestruct();
}

void UFELMovementSnackWidget::BeginDemonstrationPoseBlend(USkeletalMeshComponent* AvatarMesh, float BlendInSeconds)
{
	PoseBlendSource = AvatarMesh;
	PoseBlendDuration = FMath::Max(0.05f, BlendInSeconds);
	PoseBlendRemaining = PoseBlendDuration;
	OnMovementSnackPoseBlendAlpha(0.f);
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(PoseBlendTimerHandle);
		W->GetTimerManager().SetTimer(
			PoseBlendTimerHandle,
			this,
			&UFELMovementSnackWidget::TickPoseBlendStep,
			1.f / 60.f,
			true);
	}
}

void UFELMovementSnackWidget::TickPoseBlendStep()
{
	UWorld* W = GetWorld();
	if (!W)
	{
		return;
	}
	const float Dt = 1.f / 60.f;
	PoseBlendRemaining -= Dt;
	const float Alpha = 1.f - FMath::Clamp(PoseBlendRemaining / PoseBlendDuration, 0.f, 1.f);
	OnMovementSnackPoseBlendAlpha(Alpha);
	if (PoseBlendRemaining <= 0.f)
	{
		W->GetTimerManager().ClearTimer(PoseBlendTimerHandle);
		OnMovementSnackPoseBlendAlpha(1.f);
	}
}

void UFELMovementSnackWidget::BindTerminalActor(AActor* TerminalActor)
{
	BoundTerminal = TerminalActor;
}

void UFELMovementSnackWidget::SetAcademyModuleKey(const FString& ModuleKey)
{
	AcademyModuleKey = ModuleKey;
}

UAnimMontage* UFELMovementSnackWidget::GetResolvedDemonstrationMontage() const
{
	UWorld* W = GetWorld();
	if (!W)
	{
		return nullptr;
	}
	UGameInstance* GI = W->GetGameInstance();
	if (!GI)
	{
		return nullptr;
	}
	if (UFELAssetRegistrySubsystem* Reg = GI->GetSubsystem<UFELAssetRegistrySubsystem>())
	{
		return Reg->ResolveModuleDemonstrationMontage(AcademyModuleKey, true);
	}
	return nullptr;
}

void UFELMovementSnackWidget::BeginAsyncDemonstrationMontagePlay(USkeletalMeshComponent* GhostMeshOverride)
{
	if (GhostMeshOverride)
	{
		GhostDemonstrationMesh = GhostMeshOverride;
	}

	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(DemonstrationLoadFallbackTimer);
	}
	if (DemonstrationMontageLoadHandle.IsValid())
	{
		DemonstrationMontageLoadHandle->CancelHandle();
		DemonstrationMontageLoadHandle.Reset();
	}

	UGameInstance* GI = GetWorld() ? GetWorld()->GetGameInstance() : nullptr;
	UFELAssetRegistrySubsystem* Reg = GI ? GI->GetSubsystem<UFELAssetRegistrySubsystem>() : nullptr;
	if (!Reg || Reg->GetModuleDemonstrationMontageSoft(AcademyModuleKey).IsNull())
	{
		ShowAthleteFallbackPoster();
		OnSnackDemoReady.Broadcast();
		return;
	}

	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().SetTimer(
			DemonstrationLoadFallbackTimer,
			this,
			&UFELMovementSnackWidget::OnDemonstrationLoadTimedOut,
			3.f,
			false);
	}

	DemonstrationMontageLoadHandle = Reg->RequestAsyncDemonstrationMontage(
		AcademyModuleKey,
		FStreamableDelegate::CreateUObject(this, &UFELMovementSnackWidget::OnDemonstrationMontageLoadedInternal));
}

void UFELMovementSnackWidget::OnDemonstrationMontageLoadedInternal()
{
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(DemonstrationLoadFallbackTimer);
	}
	DemonstrationMontageLoadHandle.Reset();

	UGameInstance* GI = GetWorld() ? GetWorld()->GetGameInstance() : nullptr;
	UFELAssetRegistrySubsystem* Reg = GI ? GI->GetSubsystem<UFELAssetRegistrySubsystem>() : nullptr;
	UAnimMontage* Montage = Reg ? Reg->ResolveModuleDemonstrationMontage(AcademyModuleKey, false) : nullptr;

	if (USkeletalMeshComponent* Ghost = GhostDemonstrationMesh.Get())
	{
		if (Montage && Ghost->GetAnimInstance())
		{
			Ghost->GetAnimInstance()->Montage_Play(Montage);
		}
		else
		{
			ShowAthleteFallbackPoster();
		}
	}
	else
	{
		ShowAthleteFallbackPoster();
	}

	PlaySnackDemonstration3D();
	OnSnackDemoReady.Broadcast();
}

void UFELMovementSnackWidget::OnDemonstrationLoadTimedOut()
{
	if (DemonstrationMontageLoadHandle.IsValid())
	{
		DemonstrationMontageLoadHandle->CancelHandle();
		DemonstrationMontageLoadHandle.Reset();
	}
	ShowAthleteFallbackPoster();
	OnSnackDemoReady.Broadcast();
}

void UFELMovementSnackWidget::RunDemoWithCameraTransition(
	APlayerController* PlayerController,
	AActor* DemoViewTarget,
	float BlendInSeconds,
	float DelaySecondsAfterBlendBeforeSnack)
{
	DemoPlayerController = PlayerController;
	if (!PlayerController || !GetWorld())
	{
		TriggerSnackDemo();
		return;
	}
	if (!DemoViewTarget)
	{
		TriggerSnackDemo();
		return;
	}
	PlayerController->SetViewTargetWithBlend(DemoViewTarget, BlendInSeconds, EViewTargetBlendFunction::VTBlend_Cubic);
	const float Wait = FMath::Max(0.05f, BlendInSeconds + DelaySecondsAfterBlendBeforeSnack);
	GetWorld()->GetTimerManager().SetTimer(SnackDemoTimerHandle, this, &UFELMovementSnackWidget::FireSnackDemoAfterDelay, Wait, false);
}

void UFELMovementSnackWidget::FireSnackDemoAfterDelay()
{
	TriggerSnackDemo();
	OnSnackDemoReady.Broadcast();
}

void UFELMovementSnackWidget::FinishSnackDemoAndRestoreCamera(float BlendOutSeconds)
{
	if (APlayerController* PC = DemoPlayerController.Get())
	{
		if (APawn* Pawn = PC->GetPawn())
		{
			PC->SetViewTargetWithBlend(Pawn, BlendOutSeconds, EViewTargetBlendFunction::VTBlend_Cubic);
		}
	}
	DemoPlayerController = nullptr;
	if (GetWorld())
	{
		GetWorld()->GetTimerManager().ClearTimer(SnackDemoTimerHandle);
	}
}

void UFELMovementSnackWidget::TriggerSnackDemo()
{
	if (bUseAsyncDemonstrationLoad)
	{
		BeginAsyncDemonstrationMontagePlay(nullptr);
	}
	else
	{
		PlaySnackDemonstration3D();
		OnSnackDemoReady.Broadcast();
	}
}

void UFELMovementSnackWidget::QuickLogGrantShards()
{
	OnQuickLogForShards.Broadcast();
}
