// Copyright (c) Final Evolution Lab.
// Live Neuro-Mechanic debug overlay (non-Shipping / editor verification).

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELNeuroDebugHUDWidget.generated.h"

class UTextBlock;

/**
 * Lightweight on-screen readout: vertical estimate, PRQ, effective JumpZ (same math as character apply).
 * Create from AFELBasketballPlayerController in dev builds; refresh via UFELNeuroMechanicBridgeSubsystem::OnNeuroHUDStatsRefresh.
 */
UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API UFELNeuroDebugHUDWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	virtual void NativeConstruct() override;
	virtual void NativeDestruct() override;

	/** Called when UFELNeuroMechanicBridgeSubsystem broadcasts OnNeuroHUDStatsRefresh (after OnReadinessApplied). */
	UFUNCTION()
	void NotifyStatsChanged();

protected:
	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> NeuroStatsText = nullptr;

	void RebuildDebugTextIfNeeded();
	void RefreshDisplay();
};
