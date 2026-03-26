// Copyright (c) Final Evolution Lab.
// Default player controller for FEL basketball: dev hot-reload + optional Neuro debug HUD.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "FELJumpTimingTypes.h"
#include "GameFramework/PlayerController.h"
#include "InputMappingContext.h"
#include "InputActionValue.h"
#include "FELBasketballPlayerController.generated.h"

class UInputAction;
class UFELNeuroDebugHUDWidget;
class AFELBasketballCharacter;

UCLASS()
class FINALEVOLUTIONLAB_API AFELBasketballPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	AFELBasketballPlayerController();

	/** Gamepad / compatible device: Perfect = sharp heavy pulse; Early/Late/Leaky = low-frequency rumble (energy loss). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Feedback")
	void PlayBondsBounceHaptics(EFELJumpTimingBand Band, float TimingLeakFactor);

	/**
	 * Swap Enhanced Input mapping contexts per ActiveMode (assign IMC assets in editor / Data Asset).
	 * Default: no-op until UInputMappingContext soft refs are wired.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Input")
	void ApplyArenaInputForMode(EFELArenaMode Mode);

	EFELArenaMode GetCachedAppliedArenaMode() const { return CachedAppliedArenaMode; }

	/** When true, Jump / enhanced jump should not move the pawn (standalone or listen-server host only for phase checks). */
	bool TryHandleBaseballJumpAsSwing();

	/** Routes to server subsystem swing resolution. */
	void FEL_RequestBaseballSwing();

	/**
	 * Fortnite-style input tier: on iOS/Android, if a gamepad is present, touch signature gestures are bypassed
	 * and IA_SignatureGamepadStick (Right Stick Y up) drives signature — map Gamepad Right Thumb Y in IMC.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Input")
	void SwitchInputMode();

	/** Persist venue, gear mult, and Sovereign unlocks (e.g. Bonds_Apex_Ignition) to disk. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Save")
	void SaveGearState();

	/** Load `UFELSaveGame` and merge into possessed `AFELBasketballCharacter`. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Save")
	void LoadGearState();

	/** Idempotent: ensures Bonds_Apex_Ignition is in the unlock list and saves. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Save")
	void EnsureBondsApexIgnitionUnlockedAndSave();

	/** RC 1.0: competitive snapshot for clipboard / social (athlete, gear, peak Z, fatigue trend). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Save|Coach")
	FString GenerateAthletePerformanceJSON();

	/**
	 * Gold Master tri-platform: touch (iOS) uses `IA_SignatureVerticalSwipe` + `IA_ShootTap` under `FEL_TOUCH_DRIVE`;
	 * gamepad / keyboard bind here so Square/X, right-stick up, Space, Shift merge with the same `ExecuteSignatureMove` / shoot / sprint paths.
	 */
	void InputModeHandshake();

	/** AUDIT_QUALITY — Instant Ignition: measure touch/button → Bonds Apex `Jump()` latency (warn if >16.6 ms @60). */
	void InputLatencyMonitor_MarkPress();
	void InputLatencyMonitor_OnCharacterLaunch();

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
	virtual void OnPossess(APawn* InPawn) override;
	virtual void SetupInputComponent() override;
	virtual void PlayerTick(float DeltaTime) override;
#if PLATFORM_IOS || PLATFORM_ANDROID
	virtual void InputTouch(uint32 Handle, ETouchType::Type Type, FVector2D Location) override;
#endif

	/** iOS/Android: screen-space stick, sprint hold, gather pad (second finger), look drag on right half. */
	void ProcessTouchDrive(float DeltaSeconds);

	/** Sovereign Shop map: visibility trace from tap → `AFELShopInteractionActor`. Returns true if a hotspot consumed the tap. */
	bool TryTraceShopHotspotOnTap(float ScreenNormX, float ScreenNormY, int32 ViewportSizeX, int32 ViewportSizeY);

	float TouchLookSensitivity = 2.85f;
	FVector2D LastTouch1Norm = FVector2D::ZeroVector;
	bool bTouch1WasPressed = false;
	float Touch1PressTime = -1.f;
	bool bTouch1MovedSignificantly = false;
	bool bGatherPadActive = false;

	/** Right-half double-tap window for `AFELBasketballCharacter::ExecuteSignatureMove` (Creator Card signature). */
	float RightHalfLastTapReleaseTime = -100.f;
	FVector2D LastTouch2Norm = FVector2D::ZeroVector;
	float SignatureGestureDebounce = 0.f;

	/** Bound to **FELHotReloadReadiness** (default **R**): reload `readiness_snapshot.json` and re-apply physics. No-op in Shipping. */
	UFUNCTION()
	void InputHotReloadReadiness();

	/** After ~2s (first paint / Metal): flush RHI work — mitigates black frame until shaders present on device. */
	UFUNCTION()
	void OnDelayedRenderingFlush();

	FTimerHandle RenderingWarmupFlushTimerHandle;
	FTimerHandle LoadGearRetryTimerHandle;

	/**
	 * Optional: assign `/Game/FEL/Input/IMC_FELMobile` in editor — registers with Enhanced Input subsystem (priority 100).
	 * Touch sampling still runs in C++ for zero-frame virtual stick; IMC holds sprint/gather action metadata for mapping parity.
	 */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Input|Enhanced")
	TObjectPtr<UInputMappingContext> MobileTouchMappingContext;

	/** Optional: bind `Touch` → Long Press in IMC; merged with built-in long-press sprint in `ProcessTouchDrive`. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Input|Enhanced")
	TObjectPtr<UInputAction> IA_SprintLongPress;

	/** Optional: bind vertical swipe → Signature Move in IMC (pairs with right-half fast up-swipe in `ProcessTouchDrive`). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Input|Enhanced")
	TObjectPtr<UInputAction> IA_SignatureVerticalSwipe;

	/** Optional: bind `Touch` → tap for jump; merges with left short-tap and right-up swipe. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Input|Enhanced")
	TObjectPtr<UInputAction> IA_JumpPrimary;

	/** Optional: digital tap = shoot (`BufferJump`) — IMC maps Touch Tap → this action. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Input|Enhanced")
	TObjectPtr<UInputAction> IA_ShootTap;

	/** Optional: double-tap gesture → `ExecuteSignatureMove` (pairs with touch double-tap on right half). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Input|Enhanced")
	TObjectPtr<UInputAction> IA_SignatureDoubleTap;

	/** Optional: Gamepad Right Stick Y (axis / 2D) → `ExecuteSignatureMove` when pushed up — used on mobile when a pad is connected. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Input|Enhanced")
	TObjectPtr<UInputAction> IA_SignatureGamepadStick;

	/** Fired from optional IMC mappings (same frame as ProcessTouchDrive merge, after Super::PlayerTick input). */
	void OnIASprintLongPress(const FInputActionValue& Value);
	void OnIASignatureVerticalSwipe(const FInputActionValue& Value);
	void OnIASignatureGamepadStick(const FInputActionValue& Value);
	void OnIAJump(const FInputActionValue& Value);
	void OnIAShootTap(const FInputActionValue& Value);
	void OnIASignatureDoubleTap(const FInputActionValue& Value);

	UFUNCTION()
	void OnDeferredShootTap();

	/** Gold Master: deferred single-tap shoot so double-tap can cancel and fire `ExecuteSignatureMove`. */
	FTimerHandle DeferredShootTapTimerHandle;

	/** 0..1 from optional Enhanced Input actions (same frame as ProcessTouchDrive merge). */
	float EnhancedInputSprint01 = 0.f;
	bool bEnhancedJumpQueued = false;

	/** Optional Blueprint subclass of UFELNeuroDebugHUDWidget; defaults to native C++ widget. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Debug")
	TSubclassOf<UFELNeuroDebugHUDWidget> NeuroDebugHUDWidgetClass;

	UPROPERTY(Transient)
	TObjectPtr<UFELNeuroDebugHUDWidget> NeuroDebugHUDWidgetInstance = nullptr;

	/** Mobile: true when a gamepad is active — touch signature paths are skipped; use Right Stick action instead. */
	bool bGamepadMobileSignatureOverride = false;

	void OnHandshakeShoot();
	void OnHandshakeJumpKey();
	void OnHandshakeSprintPressed();
	void OnHandshakeSprintReleased();
	void OnHandshakeRightStickY(float Value);

	/** Pixel Streaming (Web): wheel / alternate pointer path → same signature window as `IA_SignatureVerticalSwipe`. */
	void OnPixelStreamingSignatureSwipe();

	/** Mac keyboard sprint — merged in `PlayerTick` with `EnhancedInputSprint01` via `ApplyTouchDriveInput`. */
	float HandshakeKeyboardSprint01 = 0.f;

	/** Legacy axis: edge-detect right-stick up so `OnHandshakeRightStickY` does not fire every frame. */
	float HandshakeLastRightStickY = 0.f;

	/** Last mode from `ApplyArenaInputForMode` (used when `GetAuthGameMode` is null, e.g. network client). */
	EFELArenaMode CachedAppliedArenaMode = EFELArenaMode::BasketballHeadToHead;

	UFUNCTION(Server, Reliable)
	void ServerFELBaseballSwing();

	void ExecBaseballSwingOnServer();

private:
	double InputLatencyPressWallSeconds = -1.0;
	bool bInputLatencyAwaitingLaunch = false;
};
