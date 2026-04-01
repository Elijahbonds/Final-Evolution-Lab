// Copyright (c) Final Evolution Lab.
// Persistent profile: high scores + preferred arena / inspiration (retail loop).

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "UFELPlayerProfileSave.generated.h"

/**
 * Player-facing persistence for packaged builds (complements UFELSaveGame gear/coach data).
 * Slot: FELPlayerProfile (see UFELGameInstance).
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELPlayerProfileSave : public USaveGame
{
	GENERATED_BODY()

public:
	static const TCHAR* GetSlotName() { return TEXT("FELPlayerProfile"); }
	static constexpr int32 UserSlotIndex = 0;

	/** Best single-match bucket count (basketball slice). */
	UPROPERTY(SaveGame, VisibleAnywhere, Category = "FEL|Profile")
	int32 BestBucketHighScore = 0;

	/** Canonical arena mode id string (see FELArenaModeIds / readiness active_mode). */
	UPROPERTY(SaveGame, VisibleAnywhere, Category = "FEL|Profile")
	FString PreferredArenaModeId = TEXT("basketball_h2h");

	/** Mirrors INSPIRATIONS / MODE_INSPIRATIONS — user-selected flavor line (optional). */
	UPROPERTY(SaveGame, VisibleAnywhere, Category = "FEL|Profile")
	FString SelectedInspirationTag = TEXT("NBA Street style");

	/** false = Quality (Epic), true = Performance (scaled) — INSPIRATIONS_COMPARISON roadmap. */
	UPROPERTY(SaveGame, VisibleAnywhere, Category = "FEL|Profile")
	bool bPerformanceMode = false;

	/** After first successful "Play" from retail splash/menu, skip startup on subsequent level loads (Rematch). */
	UPROPERTY(SaveGame, VisibleAnywhere, Category = "FEL|Retail")
	bool bHasCompletedRetailStartup = false;
};
