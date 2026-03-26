// Copyright (c) Final Evolution Lab.

#include "FELSoccerStadiumPresentation.h"
#include "Components/AudioComponent.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "GameFramework/PlayerStart.h"
#include "Kismet/GameplayStatics.h"
#include "Sound/SoundBase.h"
#include "UObject/UObjectGlobals.h"

namespace
{
	UStaticMesh* LoadMeshFirstPath(const TCHAR* const* Paths, int32 NumPaths)
	{
		for (int32 i = 0; i < NumPaths; ++i)
		{
			if (UStaticMesh* M = LoadObject<UStaticMesh>(nullptr, Paths[i], nullptr, LOAD_NoWarn, nullptr))
			{
				return M;
			}
		}
		return nullptr;
	}
}

UStaticMesh* AFELSoccerStadiumPresentation::ResolveSoccerGoalMesh()
{
	static const TCHAR* GoalPaths[] = {
		TEXT("/Game/FEL/Environment/Soccer/Meshy_AI_Goal_Posts_Professi_0323202113_texture.Meshy_AI_Goal_Posts_Professi_0323202113_texture"),
		TEXT("/Game/FEL/StreamingAssets/Meshy/Meshy_AI_Goal_Posts_Professi_0323202113_texture.Meshy_AI_Goal_Posts_Professi_0323202113_texture"),
		TEXT("/Game/FEL/Props/SM_MeshySoccerGoal.SM_MeshySoccerGoal"),
	};
	return LoadMeshFirstPath(GoalPaths, sizeof(GoalPaths) / sizeof(GoalPaths[0]));
}

AFELSoccerStadiumPresentation::AFELSoccerStadiumPresentation()
{
	PrimaryActorTick.bCanEverTick = false;

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	SetRootComponent(SceneRoot);

	CrowdInstances = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("CrowdInstances"));
	CrowdInstances->SetupAttachment(SceneRoot);
	CrowdInstances->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	CrowdInstances->SetCastShadow(false);

	GoalNorth = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("GoalNorth"));
	GoalNorth->SetupAttachment(SceneRoot);
	GoalNorth->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
	GoalNorth->SetMobility(EComponentMobility::Movable);

	GoalSouth = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("GoalSouth"));
	GoalSouth->SetupAttachment(SceneRoot);
	GoalSouth->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
	GoalSouth->SetMobility(EComponentMobility::Movable);

	CrowdAudio = CreateDefaultSubobject<UAudioComponent>(TEXT("CrowdAudio"));
	CrowdAudio->SetupAttachment(SceneRoot);
	CrowdAudio->bAutoActivate = false;
}

void AFELSoccerStadiumPresentation::BeginPlay()
{
	Super::BeginPlay();

	FVector FieldCenter = FVector::ZeroVector;
	FRotator FieldFacing = FRotator::ZeroRotator;
	TArray<AActor*> Starts;
	UGameplayStatics::GetAllActorsOfClass(GetWorld(), APlayerStart::StaticClass(), Starts);
	if (Starts.Num() > 0)
	{
		FieldCenter = Starts[0]->GetActorLocation();
		FieldFacing = Starts[0]->GetActorRotation();
	}
	SetActorLocation(FieldCenter);

	if (UStaticMesh* CrowdMesh = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cube.Cube"), nullptr, LOAD_None, nullptr))
	{
		CrowdInstances->SetStaticMesh(CrowdMesh);
		BuildCrowdRing(FieldCenter);
	}

	if (UStaticMesh* GoalMesh = ResolveSoccerGoalMesh())
	{
		GoalNorth->SetStaticMesh(GoalMesh);
		GoalSouth->SetStaticMesh(GoalMesh);
		PlaceGoals(FieldCenter, FieldFacing);
	}

	TryStartCrowdAudio();
}

void AFELSoccerStadiumPresentation::BuildCrowdRing(const FVector& FieldCenter)
{
	CrowdInstances->ClearInstances();

	const int32 N = FMath::Clamp(CrowdInstanceCount, 32, 1200);
	const float Golden = 2.399963229728653f;

	for (int32 i = 0; i < N; ++i)
	{
		const float T = static_cast<float>(i) * Golden;
		const float Angle = FMath::Fmod(T, 2.f * PI);
		const float RadiusJitter = CrowdRadiusUU * FMath::FRandRange(0.88f, 1.08f);
		const FVector Offset(FMath::Cos(Angle) * RadiusJitter, FMath::Sin(Angle) * RadiusJitter, CrowdHeightAboveFieldUU);
		const FVector Flat(-Offset.X, -Offset.Y, 0.f);
		const FRotator Face = Flat.IsNearlyZero() ? FRotator::ZeroRotator : Flat.Rotation();
		const float H = FMath::FRandRange(0.35f, 0.95f);
		const FTransform InstanceXform(Face, Offset, FVector(0.12f, 0.12f, H));
		CrowdInstances->AddInstance(InstanceXform);
	}
}

void AFELSoccerStadiumPresentation::PlaceGoals(const FVector& FieldCenter, const FRotator& FieldFacing)
{
	const FVector F = FieldFacing.Vector().GetSafeNormal2D();
	if (F.IsNearlyZero())
	{
		return;
	}
	const FVector NorthPos = FieldCenter + F * GoalDistanceUU + FVector(0.f, 0.f, 40.f);
	const FVector SouthPos = FieldCenter - F * GoalDistanceUU + FVector(0.f, 0.f, 40.f);

	GoalNorth->SetWorldLocation(NorthPos);
	GoalNorth->SetWorldRotation(F.Rotation() + FRotator(0.f, 90.f, 0.f));

	GoalSouth->SetWorldLocation(SouthPos);
	GoalSouth->SetWorldRotation((-F).Rotation() + FRotator(0.f, 90.f, 0.f));
}

void AFELSoccerStadiumPresentation::TryStartCrowdAudio()
{
	USoundBase* Sound = CrowdAmbienceSound.Get();
	if (!Sound)
	{
		Sound = CrowdAmbienceSound.LoadSynchronous();
	}
	if (!Sound)
	{
		Sound = LoadObject<USoundBase>(
			nullptr,
			TEXT("/Game/FEL/Audio/Ambience/SC_Crowd_Stadium_Loop.SC_Crowd_Stadium_Loop"),
			nullptr,
			LOAD_None,
			nullptr);
	}
	if (!Sound)
	{
		UE_LOG(LogTemp, Verbose, TEXT("FEL Soccer: no crowd ambience asset — add SC_Crowd_Stadium_Loop under /Game/FEL/Audio/Ambience/ (looping cue)."));
		return;
	}

	CrowdAudio->SetSound(Sound);
	CrowdAudio->SetVolumeMultiplier(0.42f);
	CrowdAudio->bAllowSpatialization = false;
	CrowdAudio->bOverridePriority = true;
	CrowdAudio->Priority = 0.35f;
	CrowdAudio->Play();
}
