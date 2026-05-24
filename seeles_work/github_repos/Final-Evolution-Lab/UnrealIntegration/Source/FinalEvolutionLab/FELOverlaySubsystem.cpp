// Copyright (c) Final Evolution Lab.

#include "FELOverlaySubsystem.h"

#include "FELIOSWebOverlay.h"
#include "FELEmergentDeepLinkSubsystem.h"
#include "FELPerformanceManagerSubsystem.h"
#include "FELSystemScanSubsystem.h"

#include "Dom/JsonObject.h"
#include "Engine/AssetManager.h"
#include "Engine/StreamableManager.h"
#include "Engine/GameInstance.h"
#include "HAL/PlatformMisc.h"
#include "Misc/ConfigCacheIni.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "TimerManager.h"

void UFELOverlaySubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);

	DashboardUrl = TEXT("https://finalevolutiongroup.com/");
	GConfig->GetString(TEXT("FELOverlay"), TEXT("DashboardUrl"), DashboardUrl, GGameIni);
	DashboardUrl.TrimStartAndEndInline();

	FELIOSWebOverlay::SetOnMessage(
		[this](const FString& Payload)
		{
			HandleOverlayMessage(Payload);
		});

	// Create + load immediately; show overlay as the "instant start" curtain.
	FELIOSWebOverlay::EnsureCreatedAndLoaded(DashboardUrl);
	FELIOSWebOverlay::Show();

	// Hide only after the first map load when requested (prevents black-frame flashes).
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELEmergentDeepLinkSubsystem* DL = GI->GetSubsystem<UFELEmergentDeepLinkSubsystem>())
		{
			DL->OnFELMapLoaded.AddDynamic(this, &UFELOverlaySubsystem::HandleMapLoaded);
		}
	}

	// Optional: send a boot packet to the overlay for telemetry/debug.
	const FString BootJson = FString::Printf(
		TEXT("{\"type\":\"fel_boot\",\"device_id\":\"%s\"}"),
		*FPlatformMisc::GetDeviceId());
	SendJsonToOverlay(BootJson);

	// Heartbeat to keep dashboard in sync (readiness / thermal bucket / overlay state).
	if (UGameInstance* GI = GetGameInstance())
	{
		GI->GetTimerManager().SetTimer(HeartbeatTimer, this, &UFELOverlaySubsystem::TickOverlayHeartbeat, 1.0f, true);
	}
}

void UFELOverlaySubsystem::Deinitialize()
{
	FELIOSWebOverlay::SetOnMessage(nullptr);
	if (UGameInstance* GI = GetGameInstance())
	{
		GI->GetTimerManager().ClearTimer(HeartbeatTimer);
	}
	Super::Deinitialize();
}

void UFELOverlaySubsystem::ShowOverlay()
{
	FELIOSWebOverlay::Show();
}

void UFELOverlaySubsystem::HideOverlay()
{
	FELIOSWebOverlay::Hide();
}

void UFELOverlaySubsystem::LoadOverlayUrl(const FString& Url)
{
	FString U = Url.TrimStartAndEnd();
	if (U.IsEmpty())
	{
		return;
	}
	FELIOSWebOverlay::EnsureCreatedAndLoaded(U);
}

void UFELOverlaySubsystem::EvalOverlayJS(const FString& JavaScript)
{
	FELIOSWebOverlay::Eval(JavaScript);
}

void UFELOverlaySubsystem::SendJsonToOverlay(const FString& Json)
{
	FString J = Json.TrimStartAndEnd();
	if (J.IsEmpty())
	{
		return;
	}
	// If your page defines:
	//   window.FELNativeReceive = (json) => { ... }
	// this delivers a parsed object. Safe no-op if not defined.
	const FString JS = FString::Printf(
		TEXT("try { if (window.FELNativeReceive) { window.FELNativeReceive(%s); } } catch(e) {}"),
		*J);
	FELIOSWebOverlay::Eval(JS);
}

void UFELOverlaySubsystem::HandleOverlayMessage(const FString& Payload)
{
	const FString P = Payload.TrimStartAndEnd();
	if (P.IsEmpty())
	{
		return;
	}

	// Try JSON first (recommended).
	if (P.StartsWith(TEXT("{")))
	{
		TSharedPtr<FJsonObject> Root;
		TSharedRef<TJsonReader<>> R = TJsonReaderFactory<>::Create(P);
		if (FJsonSerializer::Deserialize(R, Root) && Root.IsValid())
		{
			HandleOverlayJsonObject(Root);
			return;
		}
	}

	// Fallback: treat as a command string "launchGame:modeId"
	if (P.StartsWith(TEXT("launchGame:"), ESearchCase::IgnoreCase))
	{
		const FString ModeId = P.Mid(10).TrimStartAndEnd();
		if (UGameInstance* GI = GetGameInstance())
		{
			if (UFELEmergentDeepLinkSubsystem* DL = GI->GetSubsystem<UFELEmergentDeepLinkSubsystem>())
			{
				DL->RequestPlayFromEmergent(ModeId, FString(), ModeId);
				FELIOSWebOverlay::Hide();
			}
		}
	}
}

void UFELOverlaySubsystem::HandleOverlayJsonObject(const TSharedPtr<FJsonObject>& Root)
{
	const FString Action = Root->HasField(TEXT("action")) ? Root->GetStringField(TEXT("action")) : FString();
	if (Action.Equals(TEXT("show"), ESearchCase::IgnoreCase))
	{
		FELIOSWebOverlay::Show();
		return;
	}
	if (Action.Equals(TEXT("hide"), ESearchCase::IgnoreCase))
	{
		FELIOSWebOverlay::Hide();
		return;
	}

	// Prewarm can happen even if we don't launch.
	if (Action.Equals(TEXT("prewarm"), ESearchCase::IgnoreCase))
	{
		PrewarmFromJson(Root);
		return;
	}

	if (Action.Equals(TEXT("launchGame"), ESearchCase::IgnoreCase) || Action.Equals(TEXT("play"), ESearchCase::IgnoreCase))
	{
		const FString ModeId = Root->HasField(TEXT("modeId")) ? Root->GetStringField(TEXT("modeId")) :
			Root->HasField(TEXT("mode")) ? Root->GetStringField(TEXT("mode")) : FString();

		const FString PackagePath = Root->HasField(TEXT("package")) ? Root->GetStringField(TEXT("package")) :
			Root->HasField(TEXT("map")) ? Root->GetStringField(TEXT("map")) : FString();

		const FString ArenaMode = Root->HasField(TEXT("arena_mode")) ? Root->GetStringField(TEXT("arena_mode")) : ModeId;

		if (ModeId.IsEmpty())
		{
			UE_LOG(LogTemp, Warning, TEXT("[FELOverlay] launchGame missing modeId."));
			return;
		}

		if (UGameInstance* GI = GetGameInstance())
		{
			if (UFELEmergentDeepLinkSubsystem* DL = GI->GetSubsystem<UFELEmergentDeepLinkSubsystem>())
			{
				DL->RequestPlayFromEmergent(ModeId, PackagePath, ArenaMode);
				// Keep overlay up until PostLoadMapWithWorld fires (avoid black frame on slower loads).
				bPendingHideOnMapLoad = true;
			}
		}
		return;
	}
}

void UFELOverlaySubsystem::HandleMapLoaded(FString MapTokenOrName, FString ModeId)
{
	if (!bPendingHideOnMapLoad)
	{
		return;
	}
	bPendingHideOnMapLoad = false;
	FELIOSWebOverlay::Hide();
}

void UFELOverlaySubsystem::TickOverlayHeartbeat()
{
	UGameInstance* GI = GetGameInstance();
	if (!GI)
	{
		return;
	}

	float Readiness01 = 0.0f;
	bool bGate = false;
	if (UFELSystemScanSubsystem* Scan = GI->GetSubsystem<UFELSystemScanSubsystem>())
	{
		Readiness01 = Scan->GetUnifiedReadiness01();
		bGate = Scan->ShouldRecommendCorrectiveFirst();
	}

	int32 Thermal = 0;
	if (UFELPerformanceManagerSubsystem* Perf = GI->GetSubsystem<UFELPerformanceManagerSubsystem>())
	{
		Thermal = static_cast<int32>(Perf->GetThermalBucket());
	}

	const FString Json = FString::Printf(
		TEXT("{\"type\":\"fel_heartbeat\",\"readiness01\":%.3f,\"gate\":%s,\"thermal_bucket\":%d}"),
		Readiness01,
		bGate ? TEXT("true") : TEXT("false"),
		Thermal);
	SendJsonToOverlay(Json);
}

void UFELOverlaySubsystem::PrewarmFromJson(const TSharedPtr<FJsonObject>& Root)
{
	UAssetManager* AM = UAssetManager::GetIfInitialized();
	if (!AM)
	{
		return;
	}

	const TSharedPtr<FJsonValue> AssetsValue = Root->TryGetField(TEXT("assets"));
	if (!AssetsValue.IsValid() || AssetsValue->Type != EJson::Array)
	{
		// Default "core venues" prewarm if no list provided.
		TArray<FSoftObjectPath> ToLoad;
		ToLoad.Add(FSoftObjectPath(TEXT("/Game/FEL/Venues/VeniceBeach/VeniceBeach.VeniceBeach")));
		ToLoad.Add(FSoftObjectPath(TEXT("/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop.Luma_Venice_Shop")));
		AM->GetStreamableManager().RequestAsyncLoad(ToLoad, FStreamableDelegate(), FStreamableManager::AsyncLoadHighPriority);
		return;
	}

	const TArray<TSharedPtr<FJsonValue>>& Arr = AssetsValue->AsArray();
	TArray<FSoftObjectPath> ToLoad;
	for (const TSharedPtr<FJsonValue>& V : Arr)
	{
		if (!V.IsValid() || V->Type != EJson::String)
		{
			continue;
		}
		const FString Path = V->AsString();
		if (!Path.IsEmpty())
		{
			ToLoad.Add(FSoftObjectPath(Path));
		}
	}
	if (ToLoad.Num() > 0)
	{
		AM->GetStreamableManager().RequestAsyncLoad(ToLoad, FStreamableDelegate(), FStreamableManager::AsyncLoadHighPriority);
	}
}

