// UFELAIAssetManagerSubsystem.h — Runtime loader for AI-generated assets
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELGeneratedAssetPaths.h"
#include "UFELAIAssetManagerSubsystem.generated.h"

class UAnimMontage;
class USkeletalMesh;
class UStaticMesh;

/**
 * Manages runtime loading and caching of AI-generated assets
 * (DeepMotion animations, Meshy 3D models, Luma AI environments).
 *
 * Reads the asset manifest (GeneratedAssets/asset_manifest.json)
 * and provides soft-reference loading with fallback to placeholder assets.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELAIAssetManagerSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	// --- Lifecycle ---
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// --- Animation loading (DeepMotion) ---
	UFUNCTION(BlueprintCallable, Category = "FEL|AIAssets")
	UAnimMontage* LoadExerciseAnimation(const FString& ExerciseId);

	// --- Prop loading (Meshy) ---
	UFUNCTION(BlueprintCallable, Category = "FEL|AIAssets")
	UStaticMesh* LoadExerciseProp(const FString& ExerciseId);

	// --- Environment loading (Luma + Meshy) ---
	UFUNCTION(BlueprintCallable, Category = "FEL|AIAssets")
	UStaticMesh* LoadEnvironmentMesh(const FString& VenueKey);

	// --- Manifest ---
	UFUNCTION(BlueprintCallable, Category = "FEL|AIAssets")
	int32 GetLoadedAssetCount() const;

	UFUNCTION(BlueprintCallable, Category = "FEL|AIAssets")
	FString GetAssetManifestJSON() const;

	UFUNCTION(BlueprintCallable, Category = "FEL|AIAssets")
	bool IsAssetAvailable(const FString& AssetKey) const;

private:
	void LoadManifest();

	/** Cached manifest data: key → JSON object string */
	TMap<FString, FString> ManifestEntries;

	/** Loaded animation cache */
	TMap<FString, TWeakObjectPtr<UAnimMontage>> AnimCache;

	/** Loaded mesh cache */
	TMap<FString, TWeakObjectPtr<UStaticMesh>> MeshCache;
};
