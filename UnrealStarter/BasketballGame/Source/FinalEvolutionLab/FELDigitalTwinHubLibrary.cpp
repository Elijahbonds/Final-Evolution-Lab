// Copyright (c) Final Evolution Lab.

#include "FELDigitalTwinHubLibrary.h"
#include "Engine/Engine.h"
#include "FELBasketballCharacter.h"
#include "FELReadinessTypes.h"
#include "UFELAcademyMocapCatalogSubsystem.h"
#include "UFELAvatarSubsystem.h"
#include "Animation/AnimInstance.h"
#include "Animation/AnimMontage.h"
#include "Components/SkeletalMeshComponent.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"

namespace
{
	FFELReadinessSnapshot FEL_BuildReadinessForDigitalTwin(const UFELAvatarSubsystem* Av)
	{
		FFELReadinessSnapshot S;
		if (!Av)
		{
			return S;
		}
		const double Prq = Av->GetLastPRQ0to100();
		S.PRQScore = Prq;
		S.NeuralDrive = FMath::Clamp(Prq * 0.92, 0.0, 100.0);
		S.VerticalEstimateInches = Av->GetLastVerticalEstimateInches();
		S.VerticalPotential = S.VerticalEstimateInches;
		S.EfficiencyScore = 85.0;
		S.PopForce = FMath::Clamp(50.0 + Prq * 0.35, 0.0, 100.0);
		S.ReadinessScore = FMath::Clamp(70.0 + Prq * 0.25, 0.0, 100.0);
		S.HangTimeScale = 1.0;
		S.KineticLeakageMultiplier = Av->GetKineticLeakageMultiplier();
		S.KineticHeatAnkle = Av->GetKineticHeatAnkle01();
		S.KineticHeatKnee = Av->GetKineticHeatKnee01();
		S.KineticHeatHip = Av->GetKineticHeatHip01();
		S.ActiveArenaMode = TEXT("basketball_h2h");
		return S;
	}
}

AFELBasketballCharacter* UFELDigitalTwinHubLibrary::SpawnCalibratedDigitalTwin(
	UObject* WorldContextObject,
	TSubclassOf<AFELBasketballCharacter> CharacterClass,
	const FTransform& SpawnTransform)
{
	if (!CharacterClass)
	{
		return nullptr;
	}
	UWorld* World = GEngine->GetWorldFromContextObject(WorldContextObject, EGetWorldErrorMode::LogAndReturnNull);
	if (!World)
	{
		return nullptr;
	}

	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;

	AFELBasketballCharacter* Twin = World->SpawnActor<AFELBasketballCharacter>(CharacterClass, SpawnTransform, Params);
	if (!Twin)
	{
		return nullptr;
	}

	if (UGameInstance* GI = World->GetGameInstance())
	{
		if (UFELAvatarSubsystem* Av = GI->GetSubsystem<UFELAvatarSubsystem>())
		{
			Twin->ApplyReadiness(FEL_BuildReadinessForDigitalTwin(Av));
		}
	}
	return Twin;
}

bool UFELDigitalTwinHubLibrary::PlayPerfectFormMocapTakeoff(AFELBasketballCharacter* Character, const EFELArenaMode Mode)
{
	if (!Character)
	{
		return false;
	}
	UGameInstance* GI = Character->GetGameInstance();
	if (!GI)
	{
		return false;
	}
	UFELAcademyMocapCatalogSubsystem* Cat = GI->GetSubsystem<UFELAcademyMocapCatalogSubsystem>();
	if (!Cat)
	{
		return false;
	}
	UAnimMontage* Montage = Cat->ResolvePerfectFormMontage(Mode, true);
	if (!Montage)
	{
		return false;
	}
	USkeletalMeshComponent* Mesh = Character->GetMesh();
	if (!Mesh)
	{
		return false;
	}
	UAnimInstance* AI = Mesh->GetAnimInstance();
	if (!AI)
	{
		return false;
	}
	return AI->Montage_Play(Montage) > 0.f;
}
