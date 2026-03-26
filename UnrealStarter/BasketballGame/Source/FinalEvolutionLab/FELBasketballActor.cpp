// Copyright (c) Final Evolution Lab.

#include "FELBasketballActor.h"
#include "FELArenaModeDefinitions.h"
#include "FELBiometricTypes.h"
#include "FELHoopTargetActor.h"
#include "IFELInteractable.h"
#include "FinalEvolutionLab.h"
#include "Components/SphereComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"
#include "Misc/PackageName.h"
#include "UObject/UObjectGlobals.h"

namespace
{
	static UStaticMesh* FELResolveBallStaticMesh()
	{
		if (FPackageName::DoesPackageExist(TEXT("/Game/FEL/Props/SM_HoopBusBasketball")))
		{
			if (UStaticMesh* Fel = LoadObject<UStaticMesh>(
					nullptr,
					TEXT("/Game/FEL/Props/SM_HoopBusBasketball.SM_HoopBusBasketball"),
					nullptr,
					LOAD_None,
					nullptr))
			{
				return Fel;
			}
		}
		return LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/EngineMeshes/Sphere.Sphere"), nullptr, LOAD_None, nullptr);
	}

	static UStaticMesh* FELResolveSoccerBallStaticMesh()
	{
		static const TCHAR* Paths[] = {
			TEXT("/Game/FEL/Environment/Soccer/Meshy_AI_Soccer_Ball_FIFA_st_0323202119_texture.Meshy_AI_Soccer_Ball_FIFA_st_0323202119_texture"),
			TEXT("/Game/FEL/StreamingAssets/Meshy/Meshy_AI_Soccer_Ball_FIFA_st_0323202119_texture.Meshy_AI_Soccer_Ball_FIFA_st_0323202119_texture"),
			TEXT("/Game/FEL/Props/SM_MeshySoccerBall.SM_MeshySoccerBall"),
		};
		for (const TCHAR* P : Paths)
		{
			if (UStaticMesh* M = LoadObject<UStaticMesh>(nullptr, P, nullptr, LOAD_None, nullptr))
			{
				return M;
			}
		}
		return nullptr;
	}
} // namespace

void AFELBasketballActor::ApplyArenaBallVisual(const EFELArenaMode Mode)
{
	if (Mode != EFELArenaMode::Soccer || !CollisionSphere || !BallMesh)
	{
		return;
	}
	if (UStaticMesh* SoccerMesh = FELResolveSoccerBallStaticMesh())
	{
		BallMesh->SetStaticMesh(SoccerMesh);
		BallRadiusUU = 11.f;
		CollisionSphere->SetSphereRadius(BallRadiusUU);
		BallMesh->SetRelativeScale3D(FVector(1.f));
	}
}

AFELBasketballActor::AFELBasketballActor()
{
	PrimaryActorTick.bCanEverTick = true;

	CollisionSphere = CreateDefaultSubobject<USphereComponent>(TEXT("CollisionSphere"));
	SetRootComponent(CollisionSphere);
	CollisionSphere->InitSphereRadius(12.f);
	CollisionSphere->SetCollisionProfileName(TEXT("PhysicsActor"));
	CollisionSphere->SetSimulatePhysics(true);
	CollisionSphere->SetLinearDamping(0.35f);
	CollisionSphere->SetAngularDamping(0.2f);

	BallMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("BallMesh"));
	BallMesh->SetupAttachment(CollisionSphere);
	BallMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);

	if (UStaticMesh* Mesh = FELResolveBallStaticMesh())
	{
		BallMesh->SetStaticMesh(Mesh);
		if (Mesh->GetPathName().Contains(TEXT("EngineMeshes/Sphere")))
		{
			BallMesh->SetRelativeScale3D(FVector(0.22f));
		}
	}
}

FVector AFELBasketballActor::GetMagnetTargetLocation_Implementation() const
{
	return GetActorLocation();
}

float AFELBasketballActor::GetPredictiveMagnetStrength_Implementation(const float NeuralDrive0to100) const
{
	(void)NeuralDrive0to100;
	return 0.f;
}

void AFELBasketballActor::Tick(const float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	ApplyPredictiveMagnetTowardTargets(DeltaSeconds);
}

void AFELBasketballActor::ApplyPredictiveMagnetTowardTargets(const float DeltaSeconds)
{
	if (!CollisionSphere || !GetWorld() || CachedNeuralDriveForMagnet < 75.f)
	{
		return;
	}
	if (!CachedMagnetTargetActor.IsValid())
	{
		TArray<AActor*> Found;
		UGameplayStatics::GetAllActorsOfClass(GetWorld(), AFELHoopTargetActor::StaticClass(), Found);
		if (Found.Num() > 0)
		{
			CachedMagnetTargetActor = Found[0];
		}
	}
	AActor* Target = CachedMagnetTargetActor.Get();
	if (!Target)
	{
		return;
	}
	const float Assist = IFELInteractable::Execute_GetPredictiveMagnetStrength(Target, CachedNeuralDriveForMagnet);
	if (Assist <= 0.f)
	{
		return;
	}
	const FVector ToTarget = IFELInteractable::Execute_GetMagnetTargetLocation(Target) - GetActorLocation();
	const float Dist = ToTarget.Size();
	if (Dist > 1.f && Dist < 4200.f)
	{
		const FVector Dir = ToTarget / Dist;
		const float Mass = CollisionSphere->GetMass();
		CollisionSphere->AddForce(Dir * Assist * Mass * 140.f * DeltaSeconds, NAME_None, true);
	}
}

void AFELBasketballActor::ApplyBiometricContext_Implementation(const FFELBiometricContext& Context)
{
	CachedNeuralDriveForMagnet = FMath::Clamp(static_cast<float>(Context.NeuralDrive), 0.f, 100.f);
	FFELReadinessSnapshot Snap;
	Snap.PopForce = Context.PopForce;
	Snap.PRQScore = Context.PRQScore;
	Snap.KineticLeakageMultiplier = Context.KineticLeakageMultiplier;
	Snap.NeuralDrive = Context.NeuralDrive;
	ApplyReadiness(Snap);
	if (CollisionSphere)
	{
		const float Leak = FMath::Clamp(static_cast<float>(Context.KineticLeakageMultiplier), 0.45f, 1.f);
		CollisionSphere->SetLinearDamping(FMath::Lerp(0.52f, 0.22f, Leak));
		CollisionSphere->SetAngularDamping(FMath::Lerp(0.32f, 0.14f, Leak));
	}
}

void AFELBasketballActor::ApplyReadiness(const FFELReadinessSnapshot& Snap)
{
	if (!CollisionSphere)
	{
		return;
	}
	CachedNeuralDriveForMagnet = FMath::Clamp(static_cast<float>(Snap.NeuralDrive), 0.f, 100.f);
	const float Pop = FMath::Clamp(static_cast<float>(Snap.PopForce), 0.f, 100.f);
	const float Prq = FMath::Clamp(static_cast<float>(Snap.PRQScore), 0.f, 100.f);
	const float MassScale = 1.f + Pop * 0.0035f + Prq * 0.0015f;
	CollisionSphere->SetMassScale(NAME_None, MassScale);
}

void AFELBasketballActor::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	if (CollisionSphere)
	{
		CollisionSphere->SetSphereRadius(BallRadiusUU);
	}
	if (BallMesh)
	{
		BallMesh->SetRelativeScale3D(BallMeshScale);
	}
}
