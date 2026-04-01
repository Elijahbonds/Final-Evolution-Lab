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

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FFELDemonstrationMontageEnded, bool, bInterrupted);

UCLASS()
class FINALEVOLUTIONLAB_API AFELExerciseDemonstrator : public AActor
{
	GENERATED_BODY()

public:
	AFELExerciseDemonstrator();

	/** Fires when the active demonstration montage finishes (or is interrupted). */
	UPROPERTY(BlueprintAssignable, Category = "FEL|Demonstration")
	FFELDemonstrationMontageEnded OnDemonstrationMontageEnded;

	/** Applies mesh + AnimBP class and initial global play rate (call after spawn). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Demonstration")
	void ConfigureDemonstrator(USkeletalMesh* Mesh, TSubclassOf<UAnimInstance> AnimClass, float InitialGlobalPlayRate);

	/** Bonds Bounce: low PRQ → slower "common leaks"; high PRQ → elite tempo (with optional kinetic leakage damp). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Demonstration")
	void ApplyDemonstrationPlayRateFromNeuro(float PRQ0to100, float KineticLeakageMultiplier01);

	/** DeepMotion / Academy montage (defers if AnimInstance not ready yet). Binds completion for UI / camera handoff. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Demonstration")
	void PlayDemonstrationMontage(UAnimMontage* Montage);

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Demonstration")
	USkeletalMeshComponent* MeshComponent = nullptr;

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	void BindMontageFinishedDelegate(UAnimInstance* AI, UAnimMontage* Montage);
	void UnbindMontageFinishedDelegate();

	UFUNCTION()
	void HandleMontageEnded(UAnimMontage* Montage, bool bInterrupted);

	UPROPERTY()
	TObjectPtr<UAnimMontage> ActiveDemonstrationMontage = nullptr;
};
