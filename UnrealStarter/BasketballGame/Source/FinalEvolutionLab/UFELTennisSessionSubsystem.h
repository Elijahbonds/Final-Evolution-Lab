// Copyright (c) Final Evolution Lab.
// Tennis arena — Switch Sports–style serve/rally; PRQ widens ace cone, Creator Card scales court speed.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELTennisSessionSubsystem.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

UCLASS()
class FINALEVOLUTIONLAB_API UFELTennisSessionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	void ResetForMatch(bool bTennis);

	void ProgressSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, float DeltaSeconds);

	FString BuildHudLine() const;

private:
	enum class ETennisPhase : uint8
	{
		Idle,
		Serve,
		Rally,
		PointScored,
		Cooldown
	};

	bool bSessionActive = false;
	ETennisPhase Phase = ETennisPhase::Idle;
	float PhaseTimer = 0.f;
	bool bPlayerServing = true;
	int32 PlayerGames = 0;
	int32 OpponentGames = 0;
	int32 PlayerPoints = 0;
	int32 OpponentPoints = 0;
	int32 RallyCount = 0;
	float AceConeHalfAngle = 3.f;
	FString LastResultLine;

	void BeginServe(AFELBasketballGameMode* GameMode);
	void ResolveRally(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
	void AwardPoint(bool bPlayer, AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
	void CheckGameWin(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
	static FString TennisPointLabel(int32 Points);
};
