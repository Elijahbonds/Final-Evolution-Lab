// Copyright (c) Final Evolution Lab.
// Athlete Hub — PRQ gauge, Primed status, kinetic leakage heat (Ankle / Knee / Hip).

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELMovementDecoderAcademy.h"
#include "FELReadinessTypes.h"
#include "FELSystemScanTypes.h"
#include "UFELAthleteHubWidget.generated.h"

class UTextBlock;
class UProgressBar;

UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API UFELAthleteHubWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	virtual void NativeConstruct() override;
	virtual void NativeDestruct() override;

	/** Populate from readiness snapshot + scan extension fields (or gameplay defaults). */
	UFUNCTION(BlueprintCallable, Category = "FEL|AthleteHub")
	void SetHubFromReadiness(double PRQ, bool bPrimed, double HeatAnkle, double HeatKnee, double HeatHip);

	UFUNCTION(BlueprintCallable, Category = "FEL|AthleteHub")
	void SetHubData(const FFELAthleteHubDisplay& Data) { SetHubFromReadiness(Data.PRQGauge, Data.bPrimed, Data.HeatAnkle, Data.HeatKnee, Data.HeatHip); }

	/** Decoder copy from kinetic heat (optional Blueprint wiring). */
	UFUNCTION(BlueprintCallable, Category = "FEL|AthleteHub")
	void SetMovementDecoderFromHeat(double HeatAnkle, double HeatKnee, double HeatHip);

	/** Phase 1 Identity Handshake — PRQ + Creator Card line from clinical snapshot (bind in WBP). */
	UFUNCTION(BlueprintCallable, Category = "FEL|AthleteHub")
	void ApplyIdentityHandshakeFromSnapshot(const FFELReadinessSnapshot& Snapshot);

protected:
	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> CreatorIdentityText = nullptr;

	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> PrimedStatusText = nullptr;

	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> PRQValueText = nullptr;

	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UProgressBar> PRQGaugeBar = nullptr;

	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UProgressBar> HeatAnkleBar = nullptr;

	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UProgressBar> HeatKneeBar = nullptr;

	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UProgressBar> HeatHipBar = nullptr;

	/** Engine movement (replaces Swift-only Sprint slider when bound in WBP). */
	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UProgressBar> SprintBar = nullptr;

	/** Neural drive 0–1 from `AFELBasketballCharacter` (Gather analog). */
	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UProgressBar> GatherBar = nullptr;

	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> DecoderAnkleWhy = nullptr;

	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> DecoderKneeWhy = nullptr;

	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> DecoderHipWhy = nullptr;

	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> DecoderAnkleFix = nullptr;

	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> DecoderKneeFix = nullptr;

	UPROPERTY(Transient, meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> DecoderHipFix = nullptr;

	void RefreshVisuals(double PRQ, bool bPrimed, double A, double K, double H);

	/** NeuroMechanic broadcast: monospace + Signal Velocity tints (bind optional WBP controls). */
	void ApplyNeuroMechanicProBroadcastStyle();

	FTimerHandle PawnPollTimer;

	void PollEngineMovementForHub();

	UFUNCTION()
	void HandleReadinessApplied(const FFELReadinessSnapshot& Snapshot);
};
