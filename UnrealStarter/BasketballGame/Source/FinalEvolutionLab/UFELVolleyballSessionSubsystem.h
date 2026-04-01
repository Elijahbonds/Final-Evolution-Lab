// Copyright (c) Final Evolution Lab.
// Volleyball arena — set/spike timing margin from PRQ; Creator Card scales power; wave-based rally.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELVolleyballSessionSubsystem.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

UCLASS()
class FINALEVOLUTIONLAB_API UFELVolleyballSessionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	void ResetForMatch(bool bVolleyball);

	void ProgressSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, float DeltaSeconds);

	FString BuildHudLine() const;

private:
	enum class EVolleyPhase : uint8
	{
		Idle,
		Serve,
		Set,
		Spike,
		PointResolved,
		Cooldown
	};

	bool bSessionActive = false;
	EVolleyPhase Phase = EVolleyPhase::Idle;
	float PhaseTimer = 0.f;
	bool bPlayerServing = true;
	int32 PlayerScore = 0;
	int32 OpponentScore = 0;
	int32 SetNumber = 1;
	int32 PlayerSetsWon = 0;
	int32 OpponentSetsWon = 0;
	float SpikeTimingMarginMs = 30.f;
	int32 RallyLength = 0;
	FString LastResultLine;

	void BeginServe(AFELBasketballGameMode* GameMode);
	void ResolveSpike(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
	void AwardPoint(bool bPlayer, AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
	void CheckSetWin(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
};
