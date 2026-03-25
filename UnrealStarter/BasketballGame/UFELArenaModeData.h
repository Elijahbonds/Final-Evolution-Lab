// Copyright (c) Final Evolution Lab.
// Primary Data Asset: one instance per Arena mode — tune sports without C++ recompile.

#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "FELArenaModeDefinitions.h"
#include "FELArenaRulesTypes.h"
#include "FELArenaHUDTypes.h"
#include "UFELArenaModeData.generated.h"

/**
 * Authoritative mode definition for Unreal (12 assets under /Game/FEL/Data/).
 * Holds gameplay rules, sport neuro constants, demonstration meshes, and HUD/demo UI copy.
 * JSON (ArenaSettings.json) still applies optional hotfixes via FELArenaRulesRegistry::ApplyJsonOverridesToRules.
 */
UCLASS(BlueprintType)
class FINALEVOLUTIONLAB_API UFELArenaModeData : public UPrimaryDataAsset
{
	GENERATED_BODY()

public:
	/** Must match this asset's logical mode (Swift active_mode / EFELArenaMode). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Arena")
	EFELArenaMode ArenaMode = EFELArenaMode::BasketballHeadToHead;

	/** Display name for Content Browser / validation (optional). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Arena")
	FString DeveloperNote;

	/** Full rules + SportNeuro (includes demonstrator mesh/AnimBP soft refs). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Arena")
	FFELArenaRules ArenaRules;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|HUD")
	FFELArenaHUDConfig Hud;

	UFUNCTION(BlueprintCallable, Category = "FEL|Arena")
	EFELArenaMode GetArenaMode() const { return ArenaMode; }

	UFUNCTION(BlueprintCallable, Category = "FEL|Arena")
	const FFELArenaRules& GetArenaRules() const { return ArenaRules; }

	UFUNCTION(BlueprintCallable, Category = "FEL|HUD")
	const FFELArenaHUDConfig& GetHudConfig() const { return Hud; }
};
