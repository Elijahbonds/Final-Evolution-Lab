// Copyright (c) Final Evolution Lab.
// Push 1, 2 penultimate stride — audio click + Front Functional Line tension cue.

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "UFELRhythmicCueingWidget.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFELClinicalRhythmBeat, int32, BeatPhase);

/**
 * Syncs penultimate stride animation to rhythmic "Push" + "1, 2" beats; drives Front Functional Line scalar for educational takeoff visualization.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELRhythmicCueingWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	/** Phase 0 = penultimate Push, 1 = first count, 2 = second — pairs with UFELBiometricOverlays + haptics. */
	UPROPERTY(BlueprintAssignable, Category = "FEL|Clinical")
	FOnFELClinicalRhythmBeat OnClinicalBeat;

	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical")
	void StartPenultimateStrideLoop();

	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical")
	void StopPenultimateStrideLoop();

	virtual void NativeDestruct() override;

private:
	void OnBeat();

	UPROPERTY(EditAnywhere, Category = "FEL|Clinical")
	TObjectPtr<USoundBase> ClickSound;

	FTimerHandle BeatHandle;
	int32 BeatIndex = 0;
	bool bRunning = false;
	static constexpr float BeatIntervalSec = 0.42f;
};
