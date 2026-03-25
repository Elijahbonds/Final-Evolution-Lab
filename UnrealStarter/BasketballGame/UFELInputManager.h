// Copyright (c) Final Evolution Lab.
// Cross-platform gamepad bridge: desktop uses `UPlayerInput` joystick count; browser / Pixel Streaming uses
// W3C Gamepad API (Chromium maps DualSense via standard layout) and optional WebHID for vendor-specific bands.
// Inject path: call `InjectBrowserGamepadSample` from a JS→C++ bridge when running WASM or Pixel Streaming mirrors.

#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "UFELInputManager.generated.h"

/**
 * Sovereign Launch input facade — Gamepad API parity across PC, Mac, and web-hosted mirrors.
 * WebHID (DualSense / custom PJF-Band firmware) is surfaced in-browser; forward HID reports through your
 * Pixel Streaming or WASM JavaScript layer into `InjectBrowserGamepadSample`.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELInputManager : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	/**
	 * Vertical Velocity Academy — Push 1,2 haptics: Phase 0 = penultimate "Push" (grounded, both large motors);
	 * phases 1–2 = takeoff "1, 2" snaps (small motors). PS5: stacked FFP pulses + L2/R2 lanes (see UFELInputManager.cpp).
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Input|Haptics", meta = (WorldContext = "WorldContextObject"))
	static void PlayPushTwelveClinicalHaptic(const UObject* WorldContextObject, int32 BeatPhaseMod3);

public:
	/** True when at least one physical gamepad is connected (desktop / console targets). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Input", meta = (WorldContext = "WorldContextObject"))
	static bool IsAnyGamepadConnected(const UObject* WorldContextObject);

	/**
	 * Browser mirror path: maps W3C Gamepad axes/buttons (or WebHID-decoded DualSense) into FEL handshake buffers.
	 * Thresholds match `AFELBasketballPlayerController` stick gates for signature gestures.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Input")
	static void InjectBrowserGamepadSample(
		float LeftStickX,
		float LeftStickY,
		float RightStickX,
		float RightStickY,
		bool FaceBottom,
		bool FaceRight,
		bool LeftShoulder,
		bool RightShoulder);
};
