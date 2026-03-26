// Copyright (c) Final Evolution Lab.
// Parity with FinalEvolutionLab/Utilities/PRQScoring.swift (modeWeight, attributeLabel, attributeValue).

#pragma once

#include "CoreMinimal.h"

struct FELArenaBridge
{
	/** Shards curve for Unreal Arena lab (tunable); scales with PRQ and Swift modeWeight. */
	static int32 ComputeShardsEarned(int32 ScoreBuckets, double PRQ, const FString& GameModeId, bool bEconomyEnabled);

	/** Small PRQ-linked bonus double for GameSessionResult. */
	static double ComputePRQBonus(int32 ScoreBuckets, double PRQ, bool bEconomyEnabled);

	static FString AttributeLabelForGameModeId(const FString& Id);
	static double AttributeDisplay01To100(double PRQ, const FString& GameModeId);
	static double ModeWeightForGameModeId(const FString& Id);
};
