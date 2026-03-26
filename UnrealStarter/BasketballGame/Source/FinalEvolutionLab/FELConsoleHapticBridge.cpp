// Copyright (c) Final Evolution Lab.

#include "FELConsoleHapticBridge.h"
#include "GameFramework/PlayerController.h"
#include "Math/UnrealMathUtility.h"
#if PLATFORM_PS5
#include "GameFramework/ForceFeedbackParameters.h"
#endif

namespace
{
#if PLATFORM_PS5
float GatherHapticPhaseSec = 0.f;
#endif
} // namespace

void FELConsoleHapticBridge::UpdateGatherTriggerResistance(APlayerController* PC, const float GatherBlend01, const float DeltaSeconds)
{
#if PLATFORM_PS5
	if (!PC)
	{
		return;
	}
	if (GatherBlend01 < 0.12f)
	{
		GatherHapticPhaseSec = 0.f;
		return;
	}
	// Stagger pulses so we do not spam the input device every frame — reads as "building resistance".
	GatherHapticPhaseSec += DeltaSeconds;
	if (GatherHapticPhaseSec < 0.085f)
	{
		return;
	}
	GatherHapticPhaseSec = 0.f;
	FForceFeedbackParameters FFP;
	FFP.bLooping = false;
	FFP.Tag = NAME_None;
	// DualSense: **L2** adaptive resistance — target tension 0.8 at full Gather (UE maps LeftSmall → left trigger lane).
	const float U = FMath::Clamp((GatherBlend01 - 0.12f) / 0.88f, 0.f, 1.f);
	const float Tension = FMath::Lerp(0.f, 0.8f, U);
	PC->PlayDynamicForceFeedback(Tension, 0.1f, false, false, true, false, FFP);
#else
	(void)PC;
	(void)GatherBlend01;
	(void)DeltaSeconds;
#endif
}

void FELConsoleHapticBridge::ApplyBondsApexTriggerSnap(APlayerController* PC)
{
#if PLATFORM_PS5
	if (!PC)
	{
		return;
	}
	GatherHapticPhaseSec = 0.f;
	FForceFeedbackParameters FFP;
	FFP.bLooping = false;
	FFP.Tag = NAME_None;
	// DualSense: **R2** — pulse intensity 1.0 on Bonds Apex commit (RightSmall → right trigger lane).
	PC->PlayDynamicForceFeedback(1.f, 0.08f, false, false, false, true, FFP);
#else
	(void)PC;
#endif
}

void FELConsoleHapticBridge::ApplySonicFlareApexImpulse(APlayerController* PC)
{
#if PLATFORM_PS5
	if (!PC)
	{
		return;
	}
	FForceFeedbackParameters FFP;
	FFP.bLooping = false;
	FFP.Tag = NAME_None;
	PC->PlayDynamicForceFeedback(1.f, 0.22f, true, true, true, true, FFP);
#else
	(void)PC;
#endif
}
