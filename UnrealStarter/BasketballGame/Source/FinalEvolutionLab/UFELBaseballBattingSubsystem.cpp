// Copyright (c) Final Evolution Lab.

#include "UFELBaseballBattingSubsystem.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FELJumpTimingTypes.h"
#include "FELMatchTypes.h"
#include "FELNeuroSkill.h"
#include "FELBasketballPlayerController.h"
#include "Engine/World.h"
#include "Math/UnrealMathUtility.h"

void UFELBaseballBattingSubsystem::ResetForMatch(const bool bBaseball)
{
	bSessionActive = bBaseball;
	Phase = EPitchPhase::Idle;
	PhaseTimer = 0.f;
	Strikes = 0;
	Hits = 0;
	LastResultLine = bBaseball ? TEXT("Jump, tap, or confirm to swing in the plate window.") : FString();
	bSwungThisPitch = false;
	PlateWorldTime = 0.0;
	WinStartWorld = 0.0;
	WinEndWorld = 0.0;
}

float UFELBaseballBattingSubsystem::ComputeWindowSeconds(
	const AFELBasketballGameMode* GameMode,
	const AFELBasketballGameState* GameState) const
{
	if (!GameMode || !GameState)
	{
		return 0.12f;
	}
	const float PRQ = GameState->GetReadinessSnapshot().PRQScore;
	const float Wms = FELNeuroSkill::PerfectHitWindowMsFromPRQ(
		EFELArenaMode::Baseball,
		PRQ,
		GameMode->CurrentArenaRules.SportNeuro);
	return FMath::Clamp(Wms * 0.001f, 0.05f, 0.35f);
}

void UFELBaseballBattingSubsystem::StartNextPitch(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState)
{
	bSwungThisPitch = false;
	WindupSeconds = FMath::FRandRange(0.52f, 1.02f);
	FlightSeconds = FMath::FRandRange(0.34f, 0.5f);
	WindowSeconds = ComputeWindowSeconds(GameMode, GameState);
	Phase = EPitchPhase::Windup;
	PhaseTimer = WindupSeconds;
	LastResultLine = TEXT("Wind-up…");
}

void UFELBaseballBattingSubsystem::EnterCooldown(
	AFELBasketballGameMode* /*GameMode*/,
	AFELBasketballGameState* /*GameState*/,
	const FString& ResultText)
{
	LastResultLine = ResultText;
	Phase = EPitchPhase::Cooldown;
	PhaseTimer = 0.82f;
	bSwungThisPitch = true;
}

void UFELBaseballBattingSubsystem::ApplyStrike(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const FString& Detail)
{
	Strikes++;
	const int32 StrikeNum = Strikes;
	if (Strikes >= 3)
	{
		Strikes = 0;
	}
	const FString Line = FString::Printf(TEXT("%s  (Strike %d)"), *Detail, StrikeNum);
	EnterCooldown(GameMode, GameState, Line);
}

void UFELBaseballBattingSubsystem::ApplyHit(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const FString& Grade,
	const int32 Points,
	const bool bPerfect,
	APlayerController* OptionalPC)
{
	(void)GameMode;
	Hits++;
	Strikes = 0;
	if (GameState && Points > 0)
	{
		GameState->AddScore(Points);
	}
	if (bPerfect && GameState)
	{
		GameState->AddPerfectTimingHit();
	}
	LastResultLine = FString::Printf(TEXT("%s  +%d pts"), *Grade, Points);
	Phase = EPitchPhase::Cooldown;
	PhaseTimer = 0.72f;
	bSwungThisPitch = true;

	if (AFELBasketballPlayerController* PC = Cast<AFELBasketballPlayerController>(OptionalPC))
	{
		const EFELJumpTimingBand Band = bPerfect ? EFELJumpTimingBand::Perfect : EFELJumpTimingBand::Good;
		PC->PlayBondsBounceHaptics(Band, 0.f);
	}
}

void UFELBaseballBattingSubsystem::ProgressSession(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const float DeltaSeconds)
{
	if (!bSessionActive || !GameMode || !GameState || GameState->HasMatchEnded())
	{
		return;
	}
	if (GameMode->MatchPhase != EFELMatchPhase::InProgress)
	{
		return;
	}

	UWorld* World = GameMode->GetWorld();
	if (!World)
	{
		return;
	}

	if (Phase == EPitchPhase::Idle)
	{
		StartNextPitch(GameMode, GameState);
		return;
	}

	const double Now = World->GetTimeSeconds();

	if (Phase == EPitchPhase::Windup)
	{
		PhaseTimer -= DeltaSeconds;
		if (PhaseTimer <= 0.f)
		{
			Phase = EPitchPhase::Live;
			PlateWorldTime = Now + static_cast<double>(FlightSeconds);
			WinStartWorld = PlateWorldTime - static_cast<double>(WindowSeconds) * 0.5;
			WinEndWorld = PlateWorldTime + static_cast<double>(WindowSeconds) * 0.5;
			LastResultLine = TEXT("SWING!");
		}
		return;
	}

	if (Phase == EPitchPhase::Live)
	{
		if (!bSwungThisPitch && Now >= WinEndWorld)
		{
			ApplyStrike(GameMode, GameState, TEXT("Strike — missed timing"));
		}
		return;
	}

	if (Phase == EPitchPhase::Cooldown)
	{
		PhaseTimer -= DeltaSeconds;
		if (PhaseTimer <= 0.f)
		{
			StartNextPitch(GameMode, GameState);
		}
	}
}

void UFELBaseballBattingSubsystem::HandleSwingInput(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	APlayerController* OptionalPC)
{
	if (!bSessionActive || !GameMode || !GameState || GameState->HasMatchEnded())
	{
		return;
	}
	if (GameMode->CurrentMode != EFELArenaMode::Baseball || GameMode->MatchPhase != EFELMatchPhase::InProgress)
	{
		return;
	}

	UWorld* World = GameMode->GetWorld();
	if (!World)
	{
		return;
	}

	const double Now = World->GetTimeSeconds();

	if (Phase == EPitchPhase::Windup)
	{
		ApplyStrike(GameMode, GameState, TEXT("Too soon!"));
		if (AFELBasketballPlayerController* PC = Cast<AFELBasketballPlayerController>(OptionalPC))
		{
			PC->PlayBondsBounceHaptics(EFELJumpTimingBand::Early, 0.35f);
		}
		return;
	}

	if (Phase != EPitchPhase::Live || bSwungThisPitch)
	{
		return;
	}

	if (Now < WinStartWorld)
	{
		ApplyStrike(GameMode, GameState, TEXT("Too soon!"));
		if (AFELBasketballPlayerController* PC = Cast<AFELBasketballPlayerController>(OptionalPC))
		{
			PC->PlayBondsBounceHaptics(EFELJumpTimingBand::Early, 0.35f);
		}
		return;
	}

	if (Now > WinEndWorld)
	{
		ApplyStrike(GameMode, GameState, TEXT("Too late!"));
		if (AFELBasketballPlayerController* PC = Cast<AFELBasketballPlayerController>(OptionalPC))
		{
			PC->PlayBondsBounceHaptics(EFELJumpTimingBand::Late, 0.35f);
		}
		return;
	}

	const float Half = WindowSeconds * 0.5f;
	const float DeltaSec = static_cast<float>(Now - PlateWorldTime);
	const float AbsSec = FMath::Abs(DeltaSec);
	const float PerfectLim = Half * 0.22f;
	const float GoodLim = Half * 0.48f;

	if (AbsSec <= PerfectLim)
	{
		ApplyHit(GameMode, GameState, TEXT("Perfect!"), 3, true, OptionalPC);
	}
	else if (AbsSec <= GoodLim)
	{
		ApplyHit(GameMode, GameState, TEXT("Solid hit!"), 2, false, OptionalPC);
	}
	else
	{
		ApplyHit(GameMode, GameState, TEXT("Foul tip — safe"), 1, false, OptionalPC);
	}
}

FString UFELBaseballBattingSubsystem::BuildHudLine() const
{
	if (!bSessionActive)
	{
		return FString();
	}
	return FString::Printf(TEXT("Batting line · %s · Hits %d"), *LastResultLine, Hits);
}
