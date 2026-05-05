// Copy into your game's Source/FinalEvolutionLab/ module.

#include "FELPerformanceManagerSubsystem.h"

#include "Engine/AssetManager.h"
#include "Engine/StreamableManager.h"
#include "HAL/IConsoleManager.h"
#include "HAL/PlatformMisc.h"
#include "Misc/Paths.h"

namespace
{
	void SetFloatCVar(const TCHAR* Name, float Value, const TCHAR* Reason)
	{
		if (IConsoleVariable* Var = IConsoleManager::Get().FindConsoleVariable(Name))
		{
			Var->Set(Value, ECVF_SetByGameSetting);
			UE_LOG(LogTemp, Log, TEXT("[FELPerf] %s=%0.2f (%s)"), Name, Value, Reason ? Reason : TEXT("apply"));
		}
		else
		{
			UE_LOG(LogTemp, Warning, TEXT("[FELPerf] Missing cvar %s (wanted %0.2f)"), Name, Value);
		}
	}

	int32 GetDeviceTemperatureLevelInt()
	{
		// UE exposes this on Apple platforms; returns an enum-ish int.
		// If unavailable, this will typically return 0 (nominal) on non-iOS.
		return static_cast<int32>(FPlatformMisc::GetDeviceTemperatureLevel());
	}
}

void UFELPerformanceManagerSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);

	DeviceModel = FPlatformMisc::GetDeviceModel();
	DeviceModel.TrimStartAndEndInline();

	ApplyNow();

	// Poll every 30 seconds to respond to long sessions (e.g., Scene It).
	if (UGameInstance* GI = GetGameInstance())
	{
		GI->GetTimerManager().SetTimer(
			ThermalTimer,
			this,
			&UFELPerformanceManagerSubsystem::TickThermal,
			30.0f,
			true);
	}
}

void UFELPerformanceManagerSubsystem::Deinitialize()
{
	if (UGameInstance* GI = GetGameInstance())
	{
		GI->GetTimerManager().ClearTimer(ThermalTimer);
	}
	PrewarmHandle.Reset();
	Super::Deinitialize();
}

bool UFELPerformanceManagerSubsystem::IsLikelyIPhoneProMaxTier(const FString& Model)
{
	// Apple does not provide a stable "iPhone 16 Pro Max" string to UE.
	// UE typically returns hw.machine (e.g. "iPhone17,4"). We'll tier broadly:
	// - Any "iPhone" with a high major model number is treated as high-end.
	// - We prefer to be conservative; thermal bucket will still downscale.
	if (!Model.StartsWith(TEXT("iPhone"), ESearchCase::IgnoreCase))
	{
		return false;
	}

	// Parse "iPhone17,4"
	int32 Comma = INDEX_NONE;
	if (!Model.FindChar(TEXT(','), Comma))
	{
		return true;
	}
	FString Left = Model.Left(Comma); // "iPhone17"
	Left.ReplaceInline(TEXT("iPhone"), TEXT(""), ESearchCase::IgnoreCase);
	const int32 Major = FCString::Atoi(*Left);
	return Major >= 16; // ~iPhone 15/16+ generation as "high end"
}

EFELThermalBucket UFELPerformanceManagerSubsystem::MapTemperatureLevelToBucket(int32 LevelInt)
{
	// UE's EDeviceTemperatureLevel typically goes:
	// Unknown(-1), Nominal(0), Fair(1), Serious(2), Critical(3)
	switch (LevelInt)
	{
	case 3:
		return EFELThermalBucket::Critical;
	case 2:
		return EFELThermalBucket::Serious;
	case 1:
		return EFELThermalBucket::Fair;
	case 0:
	default:
		return EFELThermalBucket::Nominal;
	}
}

void UFELPerformanceManagerSubsystem::TickThermal()
{
	const EFELThermalBucket NewBucket = MapTemperatureLevelToBucket(GetDeviceTemperatureLevelInt());
	if (NewBucket == ThermalBucket)
	{
		return;
	}
	ThermalBucket = NewBucket;
	ApplyNow();
}

void UFELPerformanceManagerSubsystem::ApplyScalars(float MobileContentScaleFactor, float ScreenPercentage, const TCHAR* Reason)
{
	// These are the two knobs you asked for; they work across mobile configurations.
	SetFloatCVar(TEXT("r.MobileContentScaleFactor"), MobileContentScaleFactor, Reason);
	SetFloatCVar(TEXT("r.ScreenPercentage"), ScreenPercentage, Reason);
}

void UFELPerformanceManagerSubsystem::ApplyNow()
{
	const bool bHighEnd = IsLikelyIPhoneProMaxTier(DeviceModel);

	// Baseline targets:
	// - High-end: start sharper, then react to thermal.
	// - Others: start a bit lower to avoid immediate throttling.
	float MobileCSF = bHighEnd ? 1.0f : 0.9f;
	float ScreenPct = bHighEnd ? 100.0f : 90.0f;

	switch (ThermalBucket)
	{
	case EFELThermalBucket::Nominal:
		break;
	case EFELThermalBucket::Fair:
		MobileCSF = FMath::Min(MobileCSF, 0.95f);
		ScreenPct = FMath::Min(ScreenPct, 92.0f);
		break;
	case EFELThermalBucket::Serious:
		MobileCSF = FMath::Min(MobileCSF, 0.85f);
		ScreenPct = FMath::Min(ScreenPct, 80.0f);
		break;
	case EFELThermalBucket::Critical:
		MobileCSF = FMath::Min(MobileCSF, 0.75f);
		ScreenPct = FMath::Min(ScreenPct, 70.0f);
		break;
	}

	const TCHAR* Reason =
		(ThermalBucket == EFELThermalBucket::Nominal) ? TEXT("baseline") :
		(ThermalBucket == EFELThermalBucket::Fair) ? TEXT("thermal_fair") :
		(ThermalBucket == EFELThermalBucket::Serious) ? TEXT("thermal_serious") :
		TEXT("thermal_critical");

	UE_LOG(LogTemp, Log, TEXT("[FELPerf] DeviceModel=%s HighEnd=%d Thermal=%d"),
		*DeviceModel, bHighEnd ? 1 : 0, static_cast<int32>(ThermalBucket));

	ApplyScalars(MobileCSF, ScreenPct, Reason);
}

void UFELPerformanceManagerSubsystem::PrewarmSoftPaths(const TArray<FSoftObjectPath>& AssetsToLoad)
{
	if (AssetsToLoad.Num() == 0)
	{
		return;
	}

	UAssetManager* AM = UAssetManager::GetIfInitialized();
	if (!AM)
	{
		UE_LOG(LogTemp, Warning, TEXT("[FELPerf] AssetManager not initialized; cannot prewarm."));
		return;
	}

	FStreamableManager& SM = AM->GetStreamableManager();
	PrewarmHandle = SM.RequestAsyncLoad(
		AssetsToLoad,
		FStreamableDelegate::CreateLambda(
			[]()
			{
				UE_LOG(LogTemp, Log, TEXT("[FELPerf] Prewarm async load complete."));
			}),
		FStreamableManager::AsyncLoadHighPriority);
}

void UFELPerformanceManagerSubsystem::PrewarmCoreVenues()
{
	// These are map packages; prewarming the UWorld itself can be heavy, but loading
	// referenced assets (materials/meshes) can still help. Keep this list small.
	TArray<FSoftObjectPath> ToLoad;

	// VeniceBeach
	ToLoad.Add(FSoftObjectPath(TEXT("/Game/FEL/Venues/VeniceBeach/VeniceBeach.VeniceBeach")));
	// Luma shop (often opened from market_browse)
	ToLoad.Add(FSoftObjectPath(TEXT("/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop.Luma_Venice_Shop")));

	PrewarmSoftPaths(ToLoad);
}

