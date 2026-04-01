// Copyright (c) Final Evolution Lab.
// Karate lab sub-modes — same EFELArenaMode::Karate; variant from readiness / ArenaSettings.

#pragma once

#include "CoreMinimal.h"
#include "FELKarateLabModes.generated.h"

UENUM(BlueprintType)
enum class EFELKarateLabMode : uint8
{
	/** 1v1 Neural Tempest duel — you vs one opponent shell; storm meters on both sides. */
	HeadToHeadStorm UMETA(DisplayName = "Karate · 1v1 Head-To-Head Storm"),
	/** Matrix-style endless waves — agent integrity pool scales per wave; PRQ fuels your output. */
	EndlessAgentWaves UMETA(DisplayName = "Karate · Endless Agent Waves"),
	/**
	 * Matrix Revolutions–style siege: endless “Smith” waves, rising swarm pressure, aerial surge channel
	 * reduces infection squall; PRQ widens strike windows and mitigates horde bleed (zombie-like persistence).
	 */
	MatrixRevolutionsSiege UMETA(DisplayName = "Karate · Matrix Revolutions Siege"),
};
