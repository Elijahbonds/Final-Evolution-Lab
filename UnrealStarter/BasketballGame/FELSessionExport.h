// Copyright (c) Final Evolution Lab.
// Writes JSON shaped for Swift GameSessionResult (camelCase).

#pragma once

#include "CoreMinimal.h"
#include "FELMatchTypes.h"

class AFELBasketballGameState;
class UWorld;

struct FELSessionExport
{
	/** Legacy filename under FEL data dir. */
	static bool WriteLastSession(const AFELBasketballGameState* GS, UWorld* World, FString* OutError = nullptr);

	/**
	 * Production session_results.json (Swift GameSessionResult keys + neuro fields + masteryScore/masteryMetric).
	 * Includes nested `arena_result` (`FFELArenaResult`) for Vault / economy handshake.
	 * Writes to Documents/FEL on iOS (see FELPlatformPaths).
	 */
	static bool WriteSessionResults(const FFELMatchResultSummary& Summary, const FString& ArenaGameModeId, FString* OutError = nullptr);
};
