// Copyright (c) Final Evolution Lab.

#include "UFELPlatformManager.h"
#include "FELArenaDifficultyScaling.h"
#include "FELBuildTargetTypes.h"
#include "FELPlatformManager.h"
#include "Engine/Engine.h"
#include "GameFramework/GameUserSettings.h"
#include "GameFramework/PlayerController.h"
#include "HAL/IConsoleManager.h"
#include "HAL/PlatformMisc.h"
#include "Math/UnrealMathUtility.h"
#include "TimerManager.h"
#include "Kismet/GameplayStatics.h"
#if PLATFORM_IOS
#include "FELBasketballCharacter.h"
#endif

namespace
{
#if PLATFORM_PS5
/** PS5 Pro Enhanced: PSSR 2.0 path — if false, use TSR fallback for stable 60 Hz on standard PS5. */
static bool FEL_IsPS5ProHardware()
{
	if (FPlatformMisc::GetEnvironmentVariable(TEXT("FEL_FORCE_PS5_PRO")) == TEXT("1"))
	{
		return true;
	}
	// SDK-dependent: CPU brand / marketing string may include "Pro" on PS5 Pro; QA can force via env.
	const FString Brand = FPlatformMisc::GetCPUBrand();
	return Brand.Contains(TEXT("Pro"), ESearchCase::IgnoreCase);
}
#endif
void SetCVarFloat(const TCHAR* Name, float Value)
{
	if (IConsoleVariable* CV = IConsoleManager::Get().FindConsoleVariable(Name))
	{
		CV->Set(Value, ECVF_SetByCode);
	}
}

void SetCVarInt32(const TCHAR* Name, int32 Value)
{
	if (IConsoleVariable* CV = IConsoleManager::Get().FindConsoleVariable(Name))
	{
		CV->Set(Value, ECVF_SetByCode);
	}
}

UWorld* FEL_ResolveWorldForSubsystem(UGameInstanceSubsystem* Subsys)
{
	if (!Subsys)
	{
		return nullptr;
	}
	if (UGameInstance* GI = Subsys->GetGameInstance())
	{
		if (UWorld* W = GI->GetWorld())
		{
			return W;
		}
	}
	if (GEngine)
	{
		for (const FWorldContext& Ctx : GEngine->GetWorldContexts())
		{
			if (Ctx.World() && Ctx.WorldType == EWorldType::Game)
			{
				return Ctx.World();
			}
		}
	}
	return nullptr;
}

#if PLATFORM_IOS
/** Principal spec names `GetThermalState()`; Unreal exposes `FPlatformMisc::GetDeviceThermalState()` → `EDeviceThermalState` (Nominal/Fair/Serious/Critical). */
static EDeviceThermalState FEL_ReadIOSPlatformThermalState()
{
	return FPlatformMisc::GetDeviceThermalState();
}
#endif
} // namespace

void UFELPlatformManager::TouchSovereignGearScalingSourceOfTruth()
{
	(void)FELArenaDifficultyScaling::CalculateGearBoost(TEXT("gear_sovereign_placeholder"));
}

void UFELPlatformManager::RegisterWorldHooks()
{
	if (bWorldHooksRegistered)
	{
		return;
	}
	bWorldHooksRegistered = true;
	PostWorldInitDelegateHandle = FWorldDelegates::OnPostWorldInitialization.AddUObject(this, &UFELPlatformManager::HandlePostWorldInit);
}

void UFELPlatformManager::HandlePostWorldInit(UWorld* World, const UWorld::InitializationValues& InitValues)
{
	(void)InitValues;
	if (!World || World->IsPreviewWorld() || World->WorldType != EWorldType::Game)
	{
		return;
	}

#if PLATFORM_IOS
	if (!ThermalPollTimerHandle.IsValid())
	{
		World->GetTimerManager().SetTimer(
			ThermalPollTimerHandle,
			this,
			&UFELPlatformManager::PollThermalStateIOS,
			2.0f,
			true);
	}
	if (!IOSDRSTimerHandle.IsValid())
	{
		World->GetTimerManager().SetTimer(
			IOSDRSTimerHandle,
			this,
			&UFELPlatformManager::PollIOSDynamicResolution,
			0.05f,
			true);
	}
#endif

#if !UE_BUILD_SHIPPING && (PLATFORM_MAC || PLATFORM_PS5)
	ScheduleDevelopmentStatOverlay(World);
#endif

#if PLATFORM_PS5
	// PS5 Pro: PSSR_QualityGuard — 120 Hz budget (Luma Venice Shop mirror / RTGI spikes).
	if (FEL_IsPS5ProHardware() && World && !PS5PSSRQualityGuardTimerHandle.IsValid())
	{
		World->GetTimerManager().SetTimer(
			PS5PSSRQualityGuardTimerHandle,
			this,
			&UFELPlatformManager::PollPS5ProPSSRQualityGuard,
			0.05f,
			true);
	}
#endif
}

void UFELPlatformManager::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	TouchSovereignGearScalingSourceOfTruth();

#if !UE_BUILD_SHIPPING
	{
		const EFELBuildTarget Tier = FELPlatformManager::GetActivePlatform();
		UE_LOG(LogTemp, Log, TEXT("FEL Universal Launch: active platform tier = %d"), static_cast<int32>(Tier));
	}
#endif

	InitializePlatformSettings();

	RegisterWorldHooks();
}

void UFELPlatformManager::InitializePlatformSettings()
{
#if PLATFORM_IOS
	ApplyIOSSettings();
#elif PLATFORM_ANDROID
	ApplyAndroid();
#elif PLATFORM_SWITCH
	ApplySwitchSettings();
#elif PLATFORM_PS5
	ApplyPS5Settings();
#elif PLATFORM_MAC
	ApplyMacSettings();
#elif PLATFORM_DESKTOP
	ApplyMacSettings();
#elif PLATFORM_TVOS
	ApplyIOSSettings();
#else
	ApplyGenericConsole();
#endif
}

void UFELPlatformManager::Deinitialize()
{
	if (PostWorldInitDelegateHandle.IsValid())
	{
		FWorldDelegates::OnPostWorldInitialization.Remove(PostWorldInitDelegateHandle);
		PostWorldInitDelegateHandle.Reset();
	}
#if PLATFORM_IOS
	if (UWorld* World = FEL_ResolveWorldForSubsystem(this))
	{
		World->GetTimerManager().ClearTimer(ThermalPollTimerHandle);
		World->GetTimerManager().ClearTimer(IOSDRSTimerHandle);
	}
#endif
#if PLATFORM_PS5
	if (UWorld* World = FEL_ResolveWorldForSubsystem(this))
	{
		World->GetTimerManager().ClearTimer(PS5PSSRQualityGuardTimerHandle);
	}
#endif
	Super::Deinitialize();
}

#if PLATFORM_IOS
void UFELPlatformManager::PollThermalStateIOS()
{
	const EDeviceThermalState TS = FEL_ReadIOSPlatformThermalState();
	const bool bSerious = (TS == EDeviceThermalState::Serious || TS == EDeviceThermalState::Critical);
	if (bSerious && !bThermalThrottleActive)
	{
		ApplyThermalThrottle(true);
	}
	else if (!bSerious && bThermalThrottleActive)
	{
		ApplyThermalThrottle(false);
	}
}

void UFELPlatformManager::ApplyThermalThrottle(const bool bEnable)
{
	bThermalThrottleActive = bEnable;
	if (bEnable)
	{
		IOSDRSCurrentScreenPct = 85.f;
		SetCVarFloat(TEXT("r.ScreenPercentage"), 85.f);
		SetCVarFloat(TEXT("r.MobileContentScaleFactor"), 1.5f);
	}
	else
	{
		IOSDRSCurrentScreenPct = 100.f;
		SetCVarFloat(TEXT("r.ScreenPercentage"), 100.f);
		SetCVarFloat(TEXT("r.MobileContentScaleFactor"), 2.0f);
	}
}

void UFELPlatformManager::PollIOSDynamicResolution()
{
	if (bThermalThrottleActive)
	{
		return;
	}
	UWorld* W = FEL_ResolveWorldForSubsystem(this);
	if (!W || W->IsPaused())
	{
		return;
	}
	const float DS = W->GetDeltaSeconds();
	if (DS <= KINDA_SMALL_NUMBER)
	{
		return;
	}
	const float FrameMs = DS * 1000.f;
	// Below 60 FPS: frame time > 16.6ms — ease internal resolution down toward 70%.
	constexpr float TargetMs = 1000.f / 60.f;
	float Pct = IOSDRSCurrentScreenPct;
	if (FrameMs > TargetMs + 0.5f)
	{
		Pct = FMath::Max(70.f, Pct - 1.f);
	}
	else if (FrameMs < TargetMs - 2.5f)
	{
		Pct = FMath::Min(100.f, Pct + 0.5f);
	}
	if (!FMath::IsNearlyEqual(Pct, IOSDRSCurrentScreenPct, 0.01f))
	{
		IOSDRSCurrentScreenPct = Pct;
		SetCVarFloat(TEXT("r.ScreenPercentage"), Pct);
	}
}

void UFELPlatformManager::ApplyIOSLiveSessionLuminancePostProcess(const float NormalizedLuma01, const float DeltaLuma)
{
	UWorld* W = FEL_ResolveWorldForSubsystem(this);
	if (!W || W->IsPaused())
	{
		return;
	}
	APlayerController* PC = W->GetFirstPlayerController();
	AFELBasketballCharacter* Ch = PC ? Cast<AFELBasketballCharacter>(PC->GetPawn()) : nullptr;
	if (!Ch || !Ch->FollowCamera)
	{
		return;
	}
	FPostProcessSettings& PP = Ch->FollowCamera->PostProcessSettings;
	// Brighter ambient: tame bloom threshold so Sonic Flare stays readable (AUDIT_QUALITY visual prestige).
	if (DeltaLuma > 0.04f)
	{
		PP.bOverride_BloomIntensity = true;
		PP.BloomIntensity = FMath::Clamp(1.45f - NormalizedLuma01 * 0.35f, 1.05f, 1.55f);
		PP.bOverride_BloomThreshold = true;
		PP.BloomThreshold = FMath::Lerp(0.35f, -0.35f, NormalizedLuma01);
		PP.bOverride_AutoExposureBias = true;
		PP.AutoExposureBias = FMath::Lerp(1.15f, 0.85f, NormalizedLuma01);
	}
	else if (DeltaLuma < -0.04f)
	{
		PP.bOverride_BloomIntensity = true;
		PP.BloomIntensity = FMath::Clamp(1.35f + (1.f - NormalizedLuma01) * 0.45f, 1.15f, 1.95f);
		PP.bOverride_BloomThreshold = true;
		PP.BloomThreshold = FMath::Lerp(-0.25f, 0.55f, 1.f - NormalizedLuma01);
		PP.bOverride_AutoExposureBias = true;
		PP.AutoExposureBias = FMath::Lerp(1.35f, 0.95f, 1.f - NormalizedLuma01);
	}
}
#endif

#if PLATFORM_PS5
void UFELPlatformManager::PollPS5ProPSSRQualityGuard()
{
	if (!FEL_IsPS5ProHardware() || !GEngine)
	{
		return;
	}
	const float FPS = GEngine->GetAverageFPS();
	// Luma Venice Shop: prioritize 120 FPS for PSSR 2.0 + shop lighting — ease RT sooner on that map.
	UWorld* const W = FEL_ResolveWorldForSubsystem(this);
	bool bLumaVeniceLighting = false;
	if (W)
	{
		const FString Short = UGameplayStatics::GetCurrentLevelName(W, true);
		bLumaVeniceLighting = Short.Contains(TEXT("Luma_Venice"), ESearchCase::IgnoreCase)
			|| Short.Contains(TEXT("Venice"), ESearchCase::IgnoreCase);
	}
	const float FpsGuardCutOn = bLumaVeniceLighting ? 112.f : 118.f;
	const float FpsGuardRecover = bLumaVeniceLighting ? 117.f : 119.f;
	// SHIP_CRITERIA — PS5 Pro 120 Hz target; guard mirror/RTGI cost during Luma Venice "Mirror Finish" sessions.
	if (FPS > 1.f && FPS < FpsGuardCutOn)
	{
		if (!bPS5PSSRGuardReducedMirrorRt)
		{
			SetCVarFloat(TEXT("r.RayTracing.Reflections.MaxRoughness"), 1.0f);
			SetCVarInt32(TEXT("r.RayTracing.GlobalIllumination"), 0);
			bPS5PSSRGuardReducedMirrorRt = true;
		}
	}
	else if (FPS >= FpsGuardRecover && bPS5PSSRGuardReducedMirrorRt)
	{
		SetCVarFloat(TEXT("r.RayTracing.Reflections.MaxRoughness"), 0.8f);
		SetCVarInt32(TEXT("r.RayTracing.GlobalIllumination"), 1);
		bPS5PSSRGuardReducedMirrorRt = false;
	}
}
#endif

#if !UE_BUILD_SHIPPING
void UFELPlatformManager::ScheduleDevelopmentStatOverlay(UWorld* World)
{
	if (!World || bDevStatOverlayScheduled)
	{
		return;
	}
	bDevStatOverlayScheduled = true;
	FTimerHandle Once;
	World->GetTimerManager().SetTimer(
		Once,
		[this, World]()
		{
			if (!World)
			{
				return;
			}
			APlayerController* PC = World->GetFirstPlayerController();
			if (!PC && GEngine && GEngine->GameViewport)
			{
				if (UWorld* VW = GEngine->GameViewport->GetWorld())
				{
					PC = VW->GetFirstPlayerController();
				}
			}
			if (PC)
			{
				PC->ConsoleCommand(TEXT("stat unit"));
				PC->ConsoleCommand(TEXT("stat fps"));
			}
		},
		0.5f,
		false);
}

void UFELPlatformManager::TogglePerformanceHUD()
{
	UWorld* World = FEL_ResolveWorldForSubsystem(this);
	if (!World && GEngine && GEngine->GameViewport)
	{
		World = GEngine->GameViewport->GetWorld();
	}
	if (!World)
	{
		return;
	}
	APlayerController* PC = World->GetFirstPlayerController();
	if (!PC)
	{
		return;
	}
	bPerformanceHUDVisible = !bPerformanceHUDVisible;
	if (bPerformanceHUDVisible)
	{
		PC->ConsoleCommand(TEXT("stat unit"));
		PC->ConsoleCommand(TEXT("stat fps"));
	}
	else
	{
		PC->ConsoleCommand(TEXT("stat none"));
	}
}
#else
void UFELPlatformManager::TogglePerformanceHUD()
{
}
#endif

void UFELPlatformManager::ApplyIOSSettings()
{
	SetCVarInt32(TEXT("r.Mobile.ForwardShading"), 1);
	SetCVarInt32(TEXT("r.Mobile.AllowDistanceFieldShadows"), 1);
	SetCVarFloat(TEXT("r.MobileContentScaleFactor"), 2.0f);
	SetCVarFloat(TEXT("t.MaxFPS"), 60.f);
	IOSDRSCurrentScreenPct = 100.f;
	SetCVarFloat(TEXT("r.ScreenPercentage"), 100.f);
	SetCVarInt32(TEXT("r.DynamicGlobalIlluminationMethod"), 0);
	SetCVarInt32(TEXT("r.ReflectionMethod"), 0);
	SetCVarInt32(TEXT("r.FidelityFX.FSR.Enabled"), 1);

	if (GEngine)
	{
		if (UGameUserSettings* S = GEngine->GetGameUserSettings())
		{
			S->SetPostProcessingQuality(1);
			S->ApplySettings(false);
		}
	}
	SetCVarInt32(TEXT("r.BloomQuality"), 0);
	SetCVarInt32(TEXT("r.DepthOfFieldQuality"), 0);
	SetCVarInt32(TEXT("r.MotionBlurQuality"), 0);
}

void UFELPlatformManager::ApplySwitchSettings()
{
#if PLATFORM_SWITCH
	// Global Expansion 1.0.0 — Nintendo Switch: portable Neuro-Mechanic lab @ 60 FPS (Forward + baked lighting bias for Luma Venice Shop).
	SetCVarInt32(TEXT("r.Mobile.ForwardShading"), 1);
	SetCVarInt32(TEXT("r.Mobile.SceneColorFormat"), 0);
	SetCVarFloat(TEXT("t.MaxFPS"), 60.f);
	SetCVarInt32(TEXT("r.DynamicGlobalIlluminationMethod"), 0);
	SetCVarInt32(TEXT("r.ReflectionMethod"), 0);
	SetCVarInt32(TEXT("r.RayTracing"), 0);
	SetCVarInt32(TEXT("r.Lumen.HardwareRayTracing"), 0);
	SetCVarInt32(TEXT("r.FidelityFX.FSR.Enabled"), 1);
	SetCVarFloat(TEXT("r.MobileContentScaleFactor"), 1.75f);
	SetCVarFloat(TEXT("r.ScreenPercentage"), 100.f);
	if (GEngine)
	{
		if (UGameUserSettings* S = GEngine->GetGameUserSettings())
		{
			S->SetOverallScalabilityLevel(1);
			S->SetTextureQuality(1);
			S->SetShadowQuality(1);
			S->SetPostProcessingQuality(1);
			S->SetEffectsQuality(1);
			S->ApplySettings(false);
		}
	}
	SetCVarInt32(TEXT("r.BloomQuality"), 1);
	SetCVarInt32(TEXT("r.DepthOfFieldQuality"), 0);
	SetCVarInt32(TEXT("r.MotionBlurQuality"), 0);
#endif
}

void UFELPlatformManager::ApplyAndroid()
{
	// Vulkan + vertex fog off — align with high-end Android / Pixel device tiers.
	SetCVarInt32(TEXT("r.Android.Vulkan"), 1);
	SetCVarInt32(TEXT("r.Mobile.DisableVertexFog"), 1);
	SetCVarFloat(TEXT("r.MobileContentScaleFactor"), 2.0f);
	SetCVarFloat(TEXT("t.MaxFPS"), 60.f);
	SetCVarInt32(TEXT("r.DynamicGlobalIlluminationMethod"), 0);
	SetCVarInt32(TEXT("r.ReflectionMethod"), 0);
	SetCVarInt32(TEXT("r.FidelityFX.FSR.Enabled"), 1);
	if (GEngine)
	{
		if (UGameUserSettings* S = GEngine->GetGameUserSettings())
		{
			S->SetPostProcessingQuality(1);
			S->ApplySettings(false);
		}
	}
	SetCVarInt32(TEXT("r.BloomQuality"), 0);
	SetCVarInt32(TEXT("r.DepthOfFieldQuality"), 0);
	SetCVarInt32(TEXT("r.MotionBlurQuality"), 0);
}

void UFELPlatformManager::ApplyMacSettings()
{
	if (GEngine)
	{
		if (UGameUserSettings* S = GEngine->GetGameUserSettings())
		{
			S->SetOverallScalabilityLevel(4);
			S->SetViewDistanceQuality(4);
			S->SetAntiAliasingQuality(4);
			S->SetShadowQuality(4);
			S->SetGlobalIlluminationQuality(4);
			S->SetReflectionQuality(4);
			S->SetPostProcessingQuality(4);
			S->SetTextureQuality(4);
			S->SetEffectsQuality(4);
			S->SetFoliageQuality(4);
			S->SetShadingQuality(4);
			S->ApplySettings(false);
		}
	}
	SetCVarFloat(TEXT("t.MaxFPS"), 120.f);
	SetCVarInt32(TEXT("r.DynamicGlobalIlluminationMethod"), 1);
	SetCVarInt32(TEXT("r.ReflectionMethod"), 1);
	SetCVarInt32(TEXT("r.NaniteProjectEnabled"), 1);
}

void UFELPlatformManager::ApplyPS5Settings()
{
#if PLATFORM_PS5
	const bool bPS5Pro = FEL_IsPS5ProHardware();
#endif
	if (GEngine)
	{
		if (UGameUserSettings* S = GEngine->GetGameUserSettings())
		{
			S->SetOverallScalabilityLevel(4);
			S->SetGlobalIlluminationQuality(4);
			S->SetReflectionQuality(4);
			S->SetPostProcessingQuality(4);
			S->SetTextureQuality(4);
			S->SetEffectsQuality(4);
			S->ApplySettings(false);
		}
	}
#if PLATFORM_PS5
	SetCVarFloat(TEXT("t.MaxFPS"), bPS5Pro ? 120.f : 60.f);
#else
	SetCVarFloat(TEXT("t.MaxFPS"), 120.f);
#endif
	SetCVarInt32(TEXT("r.DynamicGlobalIlluminationMethod"), 1);
	SetCVarInt32(TEXT("r.ReflectionMethod"), 1);
	SetCVarInt32(TEXT("r.NaniteProjectEnabled"), 1);
#if PLATFORM_PS5
	if (bPS5Pro)
	{
		ApplyPS5ProSettings();
	}
	else
	{
		ApplyPS5StandardTsFallback();
	}
#else
	ApplyPS5ProSettings();
#endif
}

void UFELPlatformManager::ApplyPS5ProSettings()
{
#if PLATFORM_PS5
	// 1.0.0 PS5 Pro Enhanced — PSSR 2.0 handshake (Sony hardware): temporal resolve + Lumen HWRT + Nanite density.
	// Order: enable PSSR first, then sharpness, then dependent lighting (Luma Venice Shop relies on stable PSSR).
	SetCVarFloat(TEXT("r.ScreenPercentage"), 100.f);
	SetCVarInt32(TEXT("r.PS5.UsePSSR"), 1);
	SetCVarInt32(TEXT("r.PS5.PSSR.Enabled"), 1);
	SetCVarInt32(TEXT("r.PS5.PSSR.EnhancedMode"), 1);
	SetCVarFloat(TEXT("r.PS5.PSSR.Sharpness"), 0.4f);
	SetCVarInt32(TEXT("r.Lumen.HardwareRayTracing"), 1);
	SetCVarFloat(TEXT("r.Nanite.MaxPIXELSPerEdge"), 0.5f);
	// 120 Hz target: t.MaxFPS set in ApplyPS5Settings — PSSR_QualityGuard recovers when FPS returns to band.
#endif
}

void UFELPlatformManager::ApplyPS5StandardTsFallback()
{
#if PLATFORM_PS5
	// PSSR visibility check: standard PS5 — TSR for stable 60 FPS; temporal resolve keeps Bonds Apex / Sonic Flare reads crisp.
	SetCVarInt32(TEXT("r.PS5.PSSR.Enabled"), 0);
	SetCVarInt32(TEXT("r.PS5.PSSR.EnhancedMode"), 0);
	SetCVarInt32(TEXT("r.PS5.UsePSSR"), 0);
	SetCVarInt32(TEXT("r.AntiAliasingMethod"), 4);
	SetCVarFloat(TEXT("r.TemporalAA.Sharpness"), 0.85f);
	SetCVarInt32(TEXT("r.Lumen.HardwareRayTracing"), 0);
	SetCVarFloat(TEXT("t.MaxFPS"), 60.f);
#endif
}

void UFELPlatformManager::ApplyGenericConsole()
{
	if (GEngine)
	{
		if (UGameUserSettings* S = GEngine->GetGameUserSettings())
		{
			S->SetOverallScalabilityLevel(4);
			S->SetPostProcessingQuality(4);
			S->ApplySettings(false);
		}
	}
	SetCVarFloat(TEXT("t.MaxFPS"), 60.f);
	SetCVarInt32(TEXT("r.DynamicGlobalIlluminationMethod"), 1);
	SetCVarInt32(TEXT("r.ReflectionMethod"), 1);
	SetCVarInt32(TEXT("r.NaniteProjectEnabled"), 1);
}

void UFELPlatformManager::SetLowPowerScreenPercentage(UObject* WorldContextObject, bool bEnabled)
{
	(void)WorldContextObject;
	ApplyLowPowerScreenPercentage(bEnabled);
}

void UFELPlatformManager::ApplyLowPowerScreenPercentage(bool bEnabled)
{
	SetCVarFloat(TEXT("r.ScreenPercentage"), bEnabled ? 75.f : 100.f);
}
