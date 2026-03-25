// Copyright (c) Final Evolution Lab.

#include "UFELInputManager.h"
#include "Engine/Engine.h"
#include "Engine/EngineTypes.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/PlayerInput.h"
#include "HAL/Platform.h"
#include "Math/UnrealMathUtility.h"
#if PLATFORM_PS5
#include "GameFramework/ForceFeedbackParameters.h"
#endif

void UFELInputManager::PlayPushTwelveClinicalHaptic(const UObject* WorldContextObject, int32 BeatPhaseMod3)
{
	UWorld* World = GEngine ? GEngine->GetWorldFromContextObject(WorldContextObject, EGetWorldErrorMode::ReturnNull) : nullptr;
	if (!World)
	{
		return;
	}
	APlayerController* PC = World->GetFirstPlayerController();
	if (!PC)
	{
		return;
	}
	const int32 Phase = ((BeatPhaseMod3 % 3) + 3) % 3;
	// Bonds Standard calibration: Phase 0 = penultimate "Push" — heavy / grounded (both large motors, longer duration).
	// Phases 1–2 = takeoff "1, 2" — short, sharp small-motor snaps (explosive cue).
#if PLATFORM_PS5
	// DualSense: use FForceFeedbackParameters + stacked pulses — L2/R2 lanes match `FELConsoleHapticBridge` (adaptive trigger feel).
	FForceFeedbackParameters FFP;
	FFP.bLooping = false;
	FFP.Tag = NAME_None;
	if (Phase == 0)
	{
		// Grounded push: symmetric large-motor rumble, then brief L2 resistance lane (same bool pattern as Gather tension).
		PC->PlayDynamicForceFeedback(1.0f, 0.19f, true, false, true, false, FFP);
		PC->PlayDynamicForceFeedback(0.45f, 0.11f, false, false, true, false, FFP);
	}
	else
	{
		const float SnapIntensity = (Phase == 1) ? 0.88f : 0.95f;
		PC->PlayDynamicForceFeedback(SnapIntensity, 0.028f, false, true, false, true, FFP);
		PC->PlayDynamicForceFeedback(1.f, 0.05f, false, false, false, true, FFP);
	}
#else
	// Desktop / Mac / Xbox / mobile: standard rumble routing via gameplay channel tag (matches `AFELBasketballPlayerController::PlayBondsBounceHaptics`).
#if PLATFORM_IOS || PLATFORM_ANDROID
	// Alpha 1: small-motor snaps read subtle on phone speakers / Taptic-adjacent rumble — boost takeoff phases slightly.
	static constexpr float MobileSnapBoost = 1.14f;
#else
	static constexpr float MobileSnapBoost = 1.f;
#endif
	if (Phase == 0)
	{
		PC->PlayDynamicForceFeedback(1.0f, 0.19f, true, false, true, false, ECollisionChannel::ECC_GameTraceChannel1, false);
	}
	else
	{
		const float BaseSnap = (Phase == 1) ? 0.88f : 0.95f;
		const float SnapIntensity = FMath::Clamp(BaseSnap * MobileSnapBoost, 0.f, 1.f);
		const float SnapDur = (MobileSnapBoost > 1.f) ? 0.034f : 0.028f;
		PC->PlayDynamicForceFeedback(SnapIntensity, SnapDur, false, true, false, true, ECollisionChannel::ECC_GameTraceChannel1, false);
	}
#endif
}

namespace
{
struct FFELBrowserPadState
{
	float LeftX = 0.f;
	float LeftY = 0.f;
	float RightX = 0.f;
	float RightY = 0.f;
	bool FaceBottom = false;
	bool FaceRight = false;
	bool LeftShoulder = false;
	bool RightShoulder = false;
};

FFELBrowserPadState GBrowserPadState;
}

bool UFELInputManager::IsAnyGamepadConnected(const UObject* WorldContextObject)
{
	UWorld* World = GEngine ? GEngine->GetWorldFromContextObject(WorldContextObject, EGetWorldErrorMode::ReturnNull) : nullptr;
	if (!World)
	{
		return false;
	}
	for (FConstPlayerControllerIterator It = World->GetPlayerControllerIterator(); It; ++It)
	{
		APlayerController* PC = It->Get();
		if (PC && PC->PlayerInput && PC->PlayerInput->GetJoystickCount() > 0)
		{
			return true;
		}
	}
	return false;
}

void UFELInputManager::InjectBrowserGamepadSample(
	float LeftStickX,
	float LeftStickY,
	float RightStickX,
	float RightStickY,
	bool FaceBottom,
	bool FaceRight,
	bool LeftShoulder,
	bool RightShoulder)
{
	// Consumed by Pixel Streaming / WASM UI layers that bridge navigator.getGamepads() or navigator.hid (WebHID).
	GBrowserPadState.LeftX = FMath::Clamp(LeftStickX, -1.f, 1.f);
	GBrowserPadState.LeftY = FMath::Clamp(LeftStickY, -1.f, 1.f);
	GBrowserPadState.RightX = FMath::Clamp(RightStickX, -1.f, 1.f);
	GBrowserPadState.RightY = FMath::Clamp(RightStickY, -1.f, 1.f);
	GBrowserPadState.FaceBottom = FaceBottom;
	GBrowserPadState.FaceRight = FaceRight;
	GBrowserPadState.LeftShoulder = LeftShoulder;
	GBrowserPadState.RightShoulder = RightShoulder;
}
