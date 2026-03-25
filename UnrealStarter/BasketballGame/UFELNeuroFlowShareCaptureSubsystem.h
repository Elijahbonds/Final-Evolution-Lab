// Copyright (c) Final Evolution Lab.
// Community / viral: export a short Neuro-Flow clip after Perfect timing — hook Movie Render Queue or Pixel Capture in shipping.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELNeuroFlowShareCaptureSubsystem.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFELNeuroFlowShareCaptureSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	/** Called after a Perfect Bond Bounce / strike — start or queue a 5s capture while Neuro-Flow is active. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Share")
	void RequestNeuroFlowMomentCapture(float DurationSeconds = 5.f);

	/** True while a capture is being prepared (runtime: use MoviePipeline/BackBuffer plugin; iOS shell can poll `Saved/FEL/Exports/`). */
	UFUNCTION(BlueprintPure, Category = "FEL|Share")
	bool IsCapturePending() const { return bCapturePending; }

protected:
	UPROPERTY(Transient)
	float PendingDurationSec = 0.f;

	UPROPERTY(Transient)
	bool bCapturePending = false;
};
