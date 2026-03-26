// Copyright (c) Final Evolution Lab.
// Lab aesthetic: inject Neuro-Mechanic + Bonds Bounce textures onto tagged meshes from readiness/profile parity.

#pragma once

#include "CoreMinimal.h"
#include "FELReadinessTypes.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELBrandInjectionSubsystem.generated.h"

class UTexture2D;

/** Actor tags (place on Lab banner meshes / court floor static meshes). */
namespace FELLabBrandTags
{
	extern const FName BannerNeuroMechanic;
	extern const FName BannerBondsBounce;
	extern const FName CourtFloor;
}

UCLASS()
class FINALEVOLUTIONLAB_API UFELBrandInjectionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** Material texture parameter expected on Lab materials (create MIDs in construction script or at runtime). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Brand")
	FName BrandTextureParameterName = TEXT("BrandingTexture");

	/** Apply logos from snapshot to all actors tagged FEL_Lab_Banner_NM / FEL_Lab_Banner_BB / FEL_Lab_CourtFloor. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Lab|Brand")
	void ApplyLabBrandingFromSnapshot(UWorld* World, const FFELReadinessSnapshot& Snap);

	/** Load `/Game/...` UTexture2D soft path (returns nullptr if missing). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Lab|Brand")
	static UTexture2D* LoadTextureFromContentPath(const FString& Path);

protected:
	UFUNCTION()
	void HandleReadinessApplied(const FFELReadinessSnapshot& Snapshot);

	void ApplyTextureToActorsWithTag(UWorld* World, FName Tag, UTexture2D* Texture);
};
