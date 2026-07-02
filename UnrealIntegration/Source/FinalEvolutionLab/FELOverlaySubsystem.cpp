// Copyright (c) Final Evolution Lab.

#include "FELOverlaySubsystem.h"

#include "FELIOSWebOverlay.h"
#include "FELDeepLinkSubsystem.h"
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
#include "Misc/Guid.h"

FString UFELOverlaySubsystem::HostFromHttpUrl(const FString& Url)
{
	FString U = Url.TrimStartAndEnd();
	const int32 SchemeIdx = U.Find(TEXT("://"));
	if (SchemeIdx == INDEX_NONE)
	{
		return FString();
	}
	FString Rest = U.Mid(SchemeIdx + 3);
	int32 SlashIdx = INDEX_NONE;
	if (Rest.FindChar(TEXT('/'), SlashIdx))
	{
		Rest = Rest.Left(SlashIdx);
	}
	int32 ColonIdx = INDEX_NONE;
	if (Rest.FindChar(TEXT(':'), ColonIdx))
	{
		Rest = Rest.Left(ColonIdx);
	}
	FString H = Rest.ToLower();
	if (H.StartsWith(TEXT("www.")))
	{
		H = H.Mid(4);
	}
	return H;
}

void UFELOverlaySubsystem::BuildAllowedHosts(TArray<FString>& OutHosts) const
{
	OutHosts.Reset();
	auto AddUniqueNormalized = [&OutHosts](const FString& In)
	{
		FString H = In.TrimStartAndEnd().ToLower();
		if (H.StartsWith(TEXT("www.")))
		{
			H = H.Mid(4);
		}
		if (H.IsEmpty())
		{
			return;
		}
		if (!OutHosts.Contains(H))
		{
			OutHosts.Add(H);
		}
	};

	AddUniqueNormalized(HostFromHttpUrl(DashboardUrl));
	AddUniqueNormalized(TEXT("finalevolutiongroup.com"));

	FString Extra;
	GConfig->GetString(TEXT("FELOverlay"), TEXT("AdditionalDashboardHosts"), Extra, GGameIni);
	Extra.TrimStartAndEndInline();
	if (!Extra.IsEmpty())
	{
		TArray<FString> Parts;
		Extra.ParseIntoArray(Parts, TEXT(","));
		for (const FString& P : Parts)
		{
			AddUniqueNormalized(P);
		}
	}

	const FString DashboardHost = HostFromHttpUrl(DashboardUrl);
	if (DashboardHost.Equals(TEXT("localhost")) || DashboardHost.Equals(TEXT("127.0.0.1")))
	{
		AddUniqueNormalized(TEXT("localhost"));
		AddUniqueNormalized(TEXT("127.0.0.1"));
	}
}

bool UFELOverlaySubsystem::IsHostAllowedForDashboard(const FString& Url) const
{
	const FString H = HostFromHttpUrl(Url);
	if (H.IsEmpty())
	{
		return false;
	}
	return AllowedDashboardHosts.Contains(H);
}

void UFELOverlaySubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);

	DashboardUrl = TEXT("https://finalevolutiongroup.com/");
	GConfig->GetString(TEXT("FELOverlay"), TEXT("DashboardUrl"), DashboardUrl, GGameIni);
	DashboardUrl.TrimStartAndEndInline();

	OverlaySessionId = FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens);
	OverlayBridgeToken = FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens);

	TArray<FString> HostList;
	BuildAllowedHosts(HostList);
	AllowedDashboardHosts.Empty();
	for (const FString& H : HostList)
	{
		AllowedDashboardHosts.Add(H);
	}

	FELIOSWebOverlay::SetOnMessage(
		[this](const FString& Payload)
		{
			HandleOverlayMessage(Payload);
		});

	TArray<FString> HostArray = AllowedDashboardHosts.Array();

	// Create + load immediately; show overlay as the "instant start" curtain.
	if (!IsHostAllowedForDashboard(DashboardUrl))
	{
		UE_LOG(LogTemp, Error, TEXT("[FELOverlay] DashboardUrl host is not in allowed set — fix FELOverlay/DashboardUrl."));
	}
	FELIOSWebOverlay::EnsureCreatedAndLoadedWithSecurity(DashboardUrl, OverlayBridgeToken, HostArray);
	FELIOSWebOverlay::Show();

	// Hide only after the first map load when requested (prevents black-frame flashes).
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELDeepLinkSubsystem* DL = GI->GetSubsystem<UFELDeepLinkSubsystem>())
		{
			DL->OnFELMapLoaded.AddDynamic(this, &UFELOverlaySubsystem::HandleMapLoaded);
		}
	}

	const FString BootJson = FString::Printf(
		TEXT("{\"type\":\"fel_boot\",\"session_id\":\"%s\",\"bridge_token\":\"%s\"}"),
		*OverlaySessionId,
		*OverlayBridgeToken);
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
	if (!IsHostAllowedForDashboard(U))
	{
		UE_LOG(LogTemp, Warning, TEXT("[FELOverlay] Blocked LoadOverlayUrl — host not allowlisted."));
		return;
	}
	FELIOSWebOverlay::EnsureCreatedAndLoadedWithSecurity(U, OverlayBridgeToken, AllowedDashboardHosts.Array());
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

	OnOverlayMessageReceived.Broadcast(P);

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
}

void UFELOverlaySubsystem::HandleOverlayJsonObject(const TSharedPtr<FJsonObject>& Root)
{
	const FString Tok = Root->HasField(TEXT("bridge_token")) ? Root->GetStringField(TEXT("bridge_token")) : FString();
	if (!Tok.Equals(OverlayBridgeToken, ESearchCase::CaseSensitive))
	{
		UE_LOG(LogTemp, Warning, TEXT("[FELOverlay] Ignored bridge message (invalid bridge_token)."));
		return;
	}

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
			if (UFELDeepLinkSubsystem* DL = GI->GetSubsystem<UFELDeepLinkSubsystem>())
			{
				DL->RequestPlayFromFEL(ModeId, PackagePath, ArenaMode);
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

