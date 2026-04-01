// Copyright (c) Final Evolution Lab.
// Ghost avatar for "Perfect Form" / Bonds Bounce demonstration before workouts.

#pragma once

#include "CoreMinimal.h"
#include "Components/SkeletalMeshComponent.h"
#include "GameFramework/Actor.h"
#include "FELExerciseDemonstrator.generated.h"

class USkeletalMesh;
class UAnimInstance;
class UAnimMontage;

UCLASS()
class FINALEVOLUTIONLAB_API AFELExerciseDemonstrator : public AActor
{
	GENERATED_BODY()

public:
	AFELExerciseDemonstrator();

	/** Applies mesh + AnimBP class and initial global play rate (call after spawn). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Demonstration")
	void ConfigureDemonstrator(USkeletalMesh* Mesh, TSubclassOf<UAnimInstance> AnimClass, float InitialGlobalPlayRate);

	/** Bonds Bounce: low PRQ → slower "common leaks"; high PRQ → elite tempo (with optional kinetic leakage damp). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Demonstration")
	void ApplyDemonstrationPlayRateFromNeuro(float PRQ0to100, float KineticLeakageMultiplier01);

	/** DeepMotion / Academy montage on the default slot (defers if AnimInstance not ready yet). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Demonstration")
	void PlayDemonstrationMontage(UAnimMontage* Montage);

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Demonstration")
	USkeletalMeshComponent* MeshComponent = nullptr;

protected:
	virtual void BeginPlay() override;
};
