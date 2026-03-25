// Copyright (c) Final Evolution Lab. Copy into your game module (e.g. Source/FinalEvolutionLab/).

#pragma once

#include "CoreMinimal.h"
#include "FELReadinessTypes.h"
#include "IFELBiometricReceiver.h"
#include "IFELInteractable.h"
#include "GameFramework/Actor.h"
#include "FELBasketballActor.generated.h"

class UStaticMeshComponent;
class USphereComponent;

/**
 * HoopBus basketball visual on a physics sphere (tweak radius / mesh scale in editor).
 */
UCLASS()
class FINALEVOLUTIONLAB_API AFELBasketballActor : public AActor, public IFELBiometricReceiver, public IFELInteractable
{
	GENERATED_BODY()

public:
	AFELBasketballActor();

	virtual void ApplyBiometricContext_Implementation(const FFELBiometricContext& Context) override;
	virtual FVector GetMagnetTargetLocation_Implementation() const override;
	virtual float GetPredictiveMagnetStrength_Implementation(float NeuralDrive0to100) const override;

	/** Light mass / feel hook from Pop Force + PRQ. */
	void ApplyReadiness(const FFELReadinessSnapshot& Snap);

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	USphereComponent* CollisionSphere;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	UStaticMeshComponent* BallMesh;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL")
	float BallRadiusUU = 12.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL")
	FVector BallMeshScale = FVector(1.f, 1.f, 1.f);

	/** Last snapshot neural drive — predictive magnet toward IFELInteractable targets. */
	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|Neuro")
	float CachedNeuralDriveForMagnet = 0.f;

	virtual void Tick(float DeltaSeconds) override;
	virtual void OnConstruction(const FTransform& Transform) override;

protected:
	void ApplyPredictiveMagnetTowardTargets(float DeltaSeconds);

	TWeakObjectPtr<AActor> CachedMagnetTargetActor;
};
