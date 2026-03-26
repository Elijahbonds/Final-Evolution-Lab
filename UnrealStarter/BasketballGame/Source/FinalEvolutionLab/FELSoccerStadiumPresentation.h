// Copyright (c) Final Evolution Lab.
// Procedural crowd cards + optional stadium ambience loop; places Meshy goal meshes when imported.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FELSoccerStadiumPresentation.generated.h"

class UAudioComponent;
class UInstancedStaticMeshComponent;
class USceneComponent;
class UStaticMeshComponent;
class USoundBase;

UCLASS()
class FINALEVOLUTIONLAB_API AFELSoccerStadiumPresentation : public AActor
{
	GENERATED_BODY()

public:
	AFELSoccerStadiumPresentation();

	virtual void BeginPlay() override;

protected:
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Soccer")
	TObjectPtr<USceneComponent> SceneRoot;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Soccer")
	TObjectPtr<UInstancedStaticMeshComponent> CrowdInstances;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Soccer")
	TObjectPtr<UStaticMeshComponent> GoalNorth;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Soccer")
	TObjectPtr<UStaticMeshComponent> GoalSouth;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Soccer")
	TObjectPtr<UAudioComponent> CrowdAudio;

	UPROPERTY(EditAnywhere, Category = "FEL|Soccer|Crowd", meta = (ClampMin = "32", ClampMax = "1200"))
	int32 CrowdInstanceCount = 360;

	UPROPERTY(EditAnywhere, Category = "FEL|Soccer|Crowd", meta = (ClampMin = "500"))
	float CrowdRadiusUU = 4800.f;

	UPROPERTY(EditAnywhere, Category = "FEL|Soccer|Crowd", meta = (ClampMin = "100"))
	float CrowdHeightAboveFieldUU = 650.f;

	UPROPERTY(EditAnywhere, Category = "FEL|Soccer|Crowd")
	float GoalDistanceUU = 3200.f;

	/** Optional: assign a looping crowd bed in editor / BP; code also tries `/Game/FEL/Audio/Ambience/SC_Crowd_Stadium_Loop`. */
	UPROPERTY(EditAnywhere, Category = "FEL|Soccer|Audio")
	TSoftObjectPtr<USoundBase> CrowdAmbienceSound;

private:
	void BuildCrowdRing(const FVector& FieldCenter);
	void PlaceGoals(const FVector& FieldCenter, const FRotator& FieldFacing);
	void TryStartCrowdAudio();
	static UStaticMesh* ResolveSoccerGoalMesh();
};
