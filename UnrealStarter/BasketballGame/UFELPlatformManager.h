// Copyright (c) Final Evolution Lab.
// Gold Master: single cross-platform scalability entry (iOS vs Mac/PS5 vs other).
// Sovereign gear physics stay aligned with `FELArenaDifficultyScaling.h` + `UFELNeuroMechanicBridgeSubsystem::ApplyReadiness`
// (this subsystem does not duplicate gear math — only rendering / frame budget).

#pragma once

#include "CoreMinimal.h"
#include "Engine/World.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELPlatformManager.generated.h"

/**
 * Unified platform scalability — GameInstanceSubsystem.
 * iOS: mobile scale, no Lumen, FSR 1.0 upscaling where supported; thermal watchdog throttles resolution under load.
 * Switch: forward mobile path, 60 FPS, VRAM-stable scalability (Global Expansion 1.0.0).
 * Mac / PS5: Nanite + Lumen (high), 120 FPS target; Development builds show stat unit + stat fps.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELPlatformManager : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	void InitializePlatformSettings();
	virtual void Deinitialize() override;

	/** Toggles stat unit + stat fps vs stat none (Development/Test only). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Platform")
	void TogglePerformanceHUD();

	/** Swift / Bonds Apex: lower internal resolution for frame headroom (Metal viewport). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Platform", meta = (WorldContext = "WorldContextObject"))
	static void SetLowPowerScreenPercentage(UObject* WorldContextObject, bool bEnabled);

	UFUNCTION(BlueprintCallable, Category = "FEL|Platform")
	static void ApplyLowPowerScreenPercentage(bool bEnabled);

protected:
	/** iPhone Performance tier (A17/A18 Pro): forward shading, DRS on r.ScreenPercentage 70–100 when frame budget slips. */
	void ApplyIOSSettings();
	/** Vulkan + mobile fog: high-end Android tier (see DefaultEngine / platform manager cvars). */
	void ApplyAndroid();
	/** Nintendo Switch / Switch Lite: forward shading, fixed scene color, 60 FPS, no RT — see `Config/Switch/DefaultScalability.ini`. */
	void ApplySwitchSettings();
	void ApplyMacSettings();
	void ApplyPS5Settings();
	/** PS5 Pro 1.0.0 Enhanced: PSSR 2.0 + Lumen HWRT + Nanite (see `ApplyPS5StandardTsFallback` for base PS5). */
	void ApplyPS5ProSettings();
	/** Standard PS5: TSR instead of PSSR for stable 60 FPS; PSSR visibility check / fallback. */
	void ApplyPS5StandardTsFallback();
	void ApplyGenericConsole();

	/** Reference-only: keeps gear id math from being stripped in monolithic builds; do not duplicate in Blueprint. */
	static void TouchSovereignGearScalingSourceOfTruth();

	void RegisterWorldHooks();
	void HandlePostWorldInit(UWorld* World, const UWorld::InitializationValues& InitValues);

#if PLATFORM_IOS
	void PollThermalStateIOS();
	void PollIOSDynamicResolution();
	void ApplyThermalThrottle(bool bEnable);
	/** AUDIT_QUALITY / FELLuminanceAnalyzer — keep Sonic Flare visible without highlight blowout when ambient light shifts mid-session. */
	void ApplyIOSLiveSessionLuminancePostProcess(float NormalizedLuma01, float DeltaLuma);
#endif

#if PLATFORM_PS5
	/** PS5 Pro: PSSR + RTGI must not drag below 120 FPS — temporarily soften mirror RT when budget slips (see `FELBasketballCharacter` flare window). */
	void PollPS5ProPSSRQualityGuard();
	FTimerHandle PS5PSSRQualityGuardTimerHandle;
	bool bPS5PSSRGuardReducedMirrorRt = false;
#endif

#if !UE_BUILD_SHIPPING
	void ScheduleDevelopmentStatOverlay(UWorld* World);
#endif

	FTimerHandle ThermalPollTimerHandle;
#if PLATFORM_IOS
	FTimerHandle IOSDRSTimerHandle;
	float IOSDRSCurrentScreenPct = 100.f;
#endif
	bool bThermalThrottleActive = false;
	bool bWorldHooksRegistered = false;
	FDelegateHandle PostWorldInitDelegateHandle;

#if !UE_BUILD_SHIPPING
	bool bPerformanceHUDVisible = true;
	bool bDevStatOverlayScheduled = false;
#endif
};
