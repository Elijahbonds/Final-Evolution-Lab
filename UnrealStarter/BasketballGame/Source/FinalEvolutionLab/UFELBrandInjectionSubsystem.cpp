// Copyright (c) Final Evolution Lab.

#include "UFELBrandInjectionSubsystem.h"
#include "AFELVaultHologramTerminalActor.h"
#include "FELNeuroMechanicBridgeSubsystem.h"
#include "Components/MeshComponent.h"
#include "Engine/Texture2D.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "Materials/MaterialInstanceDynamic.h"

namespace FELLabBrandTags
{
	const FName BannerNeuroMechanic(TEXT("FEL_Lab_Banner_NM"));
	const FName BannerBondsBounce(TEXT("FEL_Lab_Banner_BB"));
	const FName CourtFloor(TEXT("FEL_Lab_CourtFloor"));
}

void UFELBrandInjectionSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			Br->OnReadinessApplied.AddDynamic(this, &UFELBrandInjectionSubsystem::HandleReadinessApplied);
		}
	}
}

void UFELBrandInjectionSubsystem::Deinitialize()
{
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			Br->OnReadinessApplied.RemoveDynamic(this, &UFELBrandInjectionSubsystem::HandleReadinessApplied);
		}
	}
	Super::Deinitialize();
}

void UFELBrandInjectionSubsystem::HandleReadinessApplied(const FFELReadinessSnapshot& Snapshot)
{
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* W = GI->GetWorld())
		{
			ApplyLabBrandingFromSnapshot(W, Snapshot);
			for (TActorIterator<AFELVaultHologramTerminalActor> It(W); It; ++It)
			{
				It->RefreshCreatorCardsFromSnapshot(Snapshot);
			}
		}
	}
}

UTexture2D* UFELBrandInjectionSubsystem::LoadTextureFromContentPath(const FString& Path)
{
	if (Path.IsEmpty() || !Path.StartsWith(TEXT("/")))
	{
		return nullptr;
	}
	return Cast<UTexture2D>(StaticLoadObject(UTexture2D::StaticClass(), nullptr, *Path));
}

void UFELBrandInjectionSubsystem::ApplyTextureToActorsWithTag(UWorld* World, const FName Tag, UTexture2D* Texture)
{
	if (!World || !Texture)
	{
		return;
	}
	for (TActorIterator<AActor> It(World); It; ++It)
	{
		AActor* A = *It;
		if (!A || !A->ActorHasTag(Tag))
		{
			continue;
		}
		TArray<UMeshComponent*> Meshes;
		A->GetComponents<UMeshComponent>(Meshes);
		for (UMeshComponent* M : Meshes)
		{
			if (!M)
			{
				continue;
			}
			const int32 Num = M->GetNumMaterials();
			for (int32 i = 0; i < Num; ++i)
			{
				UMaterialInterface* BaseMat = M->GetMaterial(i);
				if (!BaseMat)
				{
					continue;
				}
				UMaterialInstanceDynamic* MID = Cast<UMaterialInstanceDynamic>(BaseMat);
				if (!MID)
				{
					MID = UMaterialInstanceDynamic::Create(BaseMat, nullptr);
					M->SetMaterial(i, MID);
				}
				MID->SetTextureParameterValue(BrandTextureParameterName, Texture);
			}
		}
	}
}

void UFELBrandInjectionSubsystem::ApplyLabBrandingFromSnapshot(UWorld* World, const FFELReadinessSnapshot& Snap)
{
	if (!World)
	{
		return;
	}
	if (UTexture2D* T = LoadTextureFromContentPath(Snap.NeuroMechanicLogoTexturePath))
	{
		ApplyTextureToActorsWithTag(World, FELLabBrandTags::BannerNeuroMechanic, T);
	}
	if (UTexture2D* T = LoadTextureFromContentPath(Snap.BondsBounceLogoTexturePath))
	{
		ApplyTextureToActorsWithTag(World, FELLabBrandTags::BannerBondsBounce, T);
		ApplyTextureToActorsWithTag(World, FELLabBrandTags::CourtFloor, T);
	}
}
