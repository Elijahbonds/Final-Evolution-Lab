// Copyright (c) Final Evolution Lab.
// "Bonds Bounce" / victory screen — Neuro-Performance, Shards, Return to Dashboard (Exit Protocol).

#pragma once

#include "CoreMinimal.h"
#include "FELMatchTypes.h"
#include "Blueprint/UserWidget.h"
#include "FELMatchResultsWidget.generated.h"

class UTextBlock;
class UButton;

UCLASS()
class FINALEVOLUTIONLAB_API UFELMatchResultsWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintCallable, Category = "FEL|Match")
	void InitializeWithSummary(const FFELMatchResultSummary& Summary);

protected:
	virtual void NativeConstruct() override;

private:
	void BuildFallbackLayoutIfNeeded();
	void EnsureShareButton();
	void WireShareButton();
	void WireReplayButton();
	void WireRematchButton();
	UFUNCTION()
	void OnRematchClicked();

	UFUNCTION()
	void OnReturnToDashboardClicked();

	UFUNCTION()
	void OnShareEvolutionClicked();

	UFUNCTION()
	void OnReplayBestMomentClicked();

	UFUNCTION()
	void RestoreAfterReplayHighlight();

	UPROPERTY(Transient)
	FFELMatchResultSummary CachedSummary;

	UPROPERTY(Transient)
	FTimerHandle ReplayRestoreTimerHandle;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> TitleText = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> InspirationLine = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> ScoreSummaryLine = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> PrqEstimateLine = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> NeuroLine = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> ShardsLine = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> MentalSharpnessLine = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UButton> ReplayBestMomentButton = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UButton> RematchButton = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UButton> ShareButton = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UButton> ReturnButton = nullptr;
};
