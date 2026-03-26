// Copyright (c) Final Evolution Lab.
// Mode-specific HUD + demo overlay copy (tuned per UFELArenaModeData asset).

#pragma once

#include "CoreMinimal.h"
#include "FELArenaHUDTypes.generated.h"

USTRUCT(BlueprintType)
struct FFELArenaHUDConfig
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|HUD")
	FText ModeHudTitle;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|HUD")
	FText ModeHudSubtitle;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|HUD")
	bool bShowPerfectFormPanel = true;

	/** Lines shown next to demo "checkbox" affordances (visual-only in native fallback). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|HUD")
	TArray<FText> PerfectFormChecklistLines;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|HUD", meta = (ClampMin = "0.5", UIMin = "0.5"))
	float PerfectFormChecklistFontScale = 1.f;
};
