// Copyright (c) Final Evolution Lab.
// DualSense / console haptics — maps Bonds Bounce gather + Sonic Flare apex to controller feedback.
// Full adaptive-trigger resistance (SCE Pad Trigger Effects) wires in when PS5 SDK + ICommonInputHandler are available.

#pragma once

#include "CoreMinimal.h"

class APlayerController;

/** PS5: Sonic Flare / Bonds Apex trigger lane — bridge until proprietary SDK hooks are linked. */
struct FELConsoleHapticBridge
{
	/** Gather phase: **L2** adaptive resistance (tension → 0.8) while TouchGatherBlend01 charges. */
	static void UpdateGatherTriggerResistance(APlayerController* PC, float GatherBlend01, float DeltaSeconds);

	/** Bonds Apex jump: **R2** pulse (intensity 1.0) at signature commit. */
	static void ApplyBondsApexTriggerSnap(APlayerController* PC);

	/** Sonic Flare apex VFX moment — short high-intensity impulse (shares lane with adaptive trigger snap on hardware). */
	static void ApplySonicFlareApexImpulse(APlayerController* PC);
};
