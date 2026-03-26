// Copyright (c) Final Evolution Lab.
// Wii Sports–style batting: wind-up, ball flight to plate, PRQ-wide timing window, swing on Jump / tap / shoot.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELBaseballBattingSubsystem.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;
class APlayerController;

UCLASS()
class FINALEVOLUTIONLAB_API UFELBaseballBattingSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	void ResetForMatch(bool bBaseball);

	void ProgressSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, float DeltaSeconds);

	/** Server / standalone: commit a swing for the active pitch. */
	void HandleSwingInput(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, APlayerController* OptionalPC);

	FString BuildHudLine() const;

private:
	enum class EPitchPhase : uint8
	{
		Idle,
		Windup,
		Live,
		Cooldown
	};

	bool bSessionActive = false;
	EPitchPhase Phase = EPitchPhase::Idle;
	float PhaseTimer = 0.f;
	float WindupSeconds = 0.8f;
	float FlightSeconds = 0.42f;
	float WindowSeconds = 0.12f;
	double PlateWorldTime = 0.0;
	double WinStartWorld = 0.0;
	double WinEndWorld = 0.0;
	int32 Strikes = 0;
	int32 Hits = 0;
	FString LastResultLine;
	bool bSwungThisPitch = false;

	void StartNextPitch(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
	void EnterCooldown(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, const FString& ResultText);
	void ApplyStrike(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, const FString& Detail);
	void ApplyHit(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, const FString& Grade, int32 Points, bool bPerfect, APlayerController* OptionalPC);
	float ComputeWindowSeconds(const AFELBasketballGameMode* GameMode, const AFELBasketballGameState* GameState) const;
};
