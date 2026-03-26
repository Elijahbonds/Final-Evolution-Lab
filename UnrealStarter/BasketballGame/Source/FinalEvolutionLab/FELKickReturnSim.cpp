// Copyright (c) Final Evolution Lab.

#include "FELKickReturnSim.h"
#include "Math/UnrealMathUtility.h"

void FELKickReturnSim::Reset(FFELKickReturnRuntime& R)
{
	R = FFELKickReturnRuntime();
}

void FELKickReturnSim::Tick(
	FFELKickReturnRuntime& R,
	const float DeltaSeconds,
	const float PlayerPRQ0to100,
	const float PlayerCreatorArena,
	const float GhostOpponentPRQ0to100,
	const FFELSportNeuroConstants& N)
{
	if (DeltaSeconds <= 0.f)
	{
		return;
	}

	const bool bP = R.bPlayerTurn;
	const float PRQ = FMath::Clamp(bP ? PlayerPRQ0to100 : GhostOpponentPRQ0to100, 0.f, 100.f);
	const float P01 = PRQ * 0.01f;
	const float Creator = FMath::Clamp(bP ? PlayerCreatorArena : 1.f, 0.75f, 1.25f);
	float& Dur = bP ? R.PlayerDurability01 : R.OpponentDurability01;
	Dur = FMath::Clamp(Dur, 0.05f, 1.f);

	const float CreatorSpeedT = FMath::Clamp((Creator - 0.75f) / 0.5f, 0.f, 1.f);
	const float SpeedYps = N.KickReturnBaseYardsPerSecond
		* (1.f + P01 * N.KickReturnPRQSpeedCoef)
		* FMath::Lerp(0.94f, 1.08f, CreatorSpeedT);
	R.YardsOnField = FMath::Clamp(R.YardsOnField + SpeedYps * DeltaSeconds, 0.f, 100.f);

	const float WaveMult = 1.f + static_cast<float>(FMath::Max(0, R.WaveIndex - 1)) * N.KickReturnWaveRamp;
	const float DurArmor = FMath::Clamp(
		0.38f + P01 * N.KickReturnPRQDurabilityCoef + (Creator - 1.f) * 0.12f,
		0.28f,
		0.98f);
	const float DurPenalty = 1.f / FMath::Max(0.2f, Dur);
	R.TackleGauge01 += DeltaSeconds * N.KickReturnGaugeFillPerSecond * WaveMult * DurPenalty / DurArmor;

	if (R.YardsOnField >= 99.5f)
	{
		if (bP)
		{
			R.PlayerTouchdowns++;
		}
		else
		{
			R.OpponentTouchdowns++;
		}
		R.YardsOnField = 25.f;
		R.TackleGauge01 = 0.f;
		Dur = FMath::Min(1.f, Dur + N.KickReturnTdDurabilityRecover);
		R.WaveIndex++;
		return;
	}

	if (R.TackleGauge01 >= 1.f)
	{
		R.TackleGauge01 = 0.f;
		R.YardsOnField = 25.f;
		Dur *= N.KickReturnTackleDurabilityMult;
		R.bPlayerTurn = !R.bPlayerTurn;
		R.WaveIndex++;
	}
}
