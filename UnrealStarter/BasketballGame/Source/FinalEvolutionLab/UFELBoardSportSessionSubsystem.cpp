// Copyright (c) Final Evolution Lab.

#include "UFELBoardSportSessionSubsystem.h"
#include "FELArenaRulesTypes.h"
#include "FELArenaModeDefinitions.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "Math/UnrealMathUtility.h"

void UFELBoardSportSessionSubsystem::ResetForMatch(const bool bBoardSportActive)
{
	bSessionActive = bBoardSportActive;
	LineScore = 0.f;
	TrickGauge0to100 = 0.f;
	Balance01 = 1.f;
	LastFlooredLineScore = 0;
	WipeoutCount = 0;
	LastLine.Empty();
}

void UFELBoardSportSessionSubsystem::ProgressSession(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const float DeltaSeconds)
{
	if (!bSessionActive || !GameMode || !GameState || GameState->HasMatchEnded())
	{
		return;
	}
	const EFELArenaMode M = GameMode->CurrentMode;
	if (M != EFELArenaMode::Surfing && M != EFELArenaMode::Skateboarding && M != EFELArenaMode::Snowboarding)
	{
		return;
	}

	const FFELSportNeuroConstants& N = GameMode->CurrentArenaRules.SportNeuro;
	const float PRQ = GameMode->GetNeuroPRQScoreFloat();
	const float P01 = FMath::Clamp(PRQ * 0.01f, 0.f, 1.f);

	const float LineRate = N.BoardSportBaseLineScorePerSecond + P01 * N.BoardSportPRQLineCoef;
	LineScore += LineRate * DeltaSeconds;

	const float TrickFill = (N.BoardSportTrickGaugeFillPerSecond + P01 * N.BoardSportPRQTrickCoef) * Balance01;
	TrickGauge0to100 = FMath::Clamp(TrickGauge0to100 + TrickFill * DeltaSeconds, 0.f, 100.f);

	const float BalanceLeak = FMath::Max(0.f, N.BoardSportBalanceLeakPerSecond - P01 * N.BoardSportPRQBalanceMitigation * 0.01f);
	Balance01 = FMath::Clamp(Balance01 - BalanceLeak * DeltaSeconds, 0.f, 1.f);

	if (Balance01 < 0.11f && FMath::FRand() < DeltaSeconds * 0.9f)
	{
		WipeoutCount++;
		Balance01 = 0.52f;
		TrickGauge0to100 *= 0.5f;
		LineScore = FMath::Max(0.f, LineScore - N.BoardSportWipeoutBalanceLoss * 24.f);
		LastLine = TEXT("Wipeout — line trimmed");
	}
	else
	{
		const TCHAR* Sport = M == EFELArenaMode::Surfing ? TEXT("Surf")
			: M == EFELArenaMode::Skateboarding ? TEXT("Skate") : TEXT("Snow");
		LastLine = FString::Printf(
			TEXT("%s line · trick %.0f · balance %.0f%% · PRQ %.0f"),
			Sport,
			TrickGauge0to100,
			Balance01 * 100.f,
			PRQ);
	}

	const int32 Floored = FMath::FloorToInt(LineScore);
	if (Floored != LastFlooredLineScore && GameState->IsScoringEnabled())
	{
		GameState->AddScore(Floored - LastFlooredLineScore);
		LastFlooredLineScore = Floored;
	}
}

FString UFELBoardSportSessionSubsystem::BuildHudLine() const
{
	if (!bSessionActive)
	{
		return FString();
	}
	return FString::Printf(
		TEXT("Board · line %.0f · trick %.0f · wipeouts %d · %s"),
		LineScore,
		TrickGauge0to100,
		WipeoutCount,
		*LastLine);
}
