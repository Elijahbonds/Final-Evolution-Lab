// Copyright (c) Final Evolution Lab.

#include "FELExerciseDemonstrator.h"
#include "FinalEvolutionLab.h"
#include "Engine/World.h"
#include "TimerManager.h"
#include "Animation/AnimInstance.h"
#include "Animation/AnimMontage.h"
#include "Components/SkeletalMeshComponent.h"
#include "Engine/SkeletalMesh.h"

AFELExerciseDemonstrator::AFELExerciseDemonstrator()
{
	PrimaryActorTick.bCanEverTick = false;

	MeshComponent = CreateDefaultSubobject<USkeletalMeshComponent>(TEXT("DemonstratorMesh"));
	SetRootComponent(MeshComponent);
	MeshComponent->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	MeshComponent->SetGenerateOverlapEvents(false);
	MeshComponent->CastShadow = true;
}

void AFELExerciseDemonstrator::BeginPlay()
{
	Super::BeginPlay();
}

void AFELExerciseDemonstrator::ConfigureDemonstrator(
	USkeletalMesh* Mesh,
	const TSubclassOf<UAnimInstance> AnimClass,
	const float InitialGlobalPlayRate)
{
	if (Mesh)
	{
		MeshComponent->SetSkeletalMesh(Mesh);
	}
	if (AnimClass)
	{
		MeshComponent->SetAnimInstanceClass(AnimClass);
	}
	auto ApplyRate = [this, InitialGlobalPlayRate]()
	{
		if (MeshComponent)
		{
			MeshComponent->GlobalAnimRateScale = InitialGlobalPlayRate;
		}
	};
	ApplyRate();
	if (!MeshComponent->GetAnimInstance() && AnimClass && GetWorld())
	{
		FTimerHandle H;
		GetWorldTimerManager().SetTimer(H, ApplyRate, 0.05f, false);
	}
}

void AFELExerciseDemonstrator::PlayDemonstrationMontage(UAnimMontage* Montage)
{
	if (!Montage || !MeshComponent)
	{
		return;
	}
	const auto TryPlay = [this, Montage]()
	{
		if (UAnimInstance* const AI = MeshComponent->GetAnimInstance())
		{
			const float Len = AI->Montage_Play(Montage);
#if !UE_BUILD_SHIPPING
			if (Len <= 0.f)
			{
				UE_LOG(LogFinalEvolutionLab, Warning,
					TEXT("PlayDemonstrationMontage: Montage_Play returned 0 for '%s' (slot/skeleton mismatch vs AnimBP)."),
					*GetNameSafe(Montage));
			}
#endif
			return true;
		}
		return false;
	};
	if (TryPlay())
	{
		return;
	}
	if (UWorld* const W = GetWorld())
	{
		FTimerHandle H;
		W->GetTimerManager().SetTimer(
			H,
			[this, Montage, TryPlay]()
			{
				if (!TryPlay())
				{
#if !UE_BUILD_SHIPPING
					UE_LOG(LogFinalEvolutionLab, Warning,
						TEXT("PlayDemonstrationMontage: AnimInstance still null on '%s' after defer (mesh/AnimBP)."),
						MeshComponent ? *GetNameSafe(MeshComponent) : TEXT("Mesh"));
#endif
				}
			},
			0.05f,
			false);
	}
}

void AFELExerciseDemonstrator::ApplyDemonstrationPlayRateFromNeuro(const float PRQ0to100, const float KineticLeakageMultiplier01)
{
	const float PRQ = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	const float Leak = FMath::Clamp(KineticLeakageMultiplier01, 0.45f, 1.f);
	// Elite: faster + crisp; leaks: slower + "energy bleed" feel; scan leakage tightens further.
	const float Base = FMath::Lerp(0.68f, 1.15f, PRQ / 100.f);
	const float Rate = Base * FMath::Lerp(0.82f, 1.f, Leak);
	auto Apply = [this, Rate]()
	{
		if (MeshComponent)
		{
			MeshComponent->GlobalAnimRateScale = Rate;
		}
	};
	Apply();
	if (!MeshComponent->GetAnimInstance() && GetWorld())
	{
		FTimerHandle H;
		GetWorldTimerManager().SetTimer(H, Apply, 0.05f, false);
	}
}
