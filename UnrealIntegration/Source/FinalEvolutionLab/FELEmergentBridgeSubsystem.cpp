// Copy into your game's Source/FinalEvolutionLab/ module.

#include "FELEmergentBridgeSubsystem.h"

#include "FELBasketballGameState.h"
#include "FELEmergentSovereignDatabase.h"
#include "HAL/FileManager.h"
#include "Dom/JsonObject.h"
#include "Policies/CondensedJsonPrintPolicy.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"
#include "TimerManager.h"
#include "Engine/World.h"
#include "Engine/GameInstance.h"
#include "HAL/PlatformMisc.h"
#include "Misc/ConfigCacheIni.h"
#include "Misc/DateTime.h"
#include "Misc/Paths.h"
#include "SocketSubsystem.h"
#include "Sockets.h"
#include "WebSocketsModule.h"
#include "IWebSocket.h"

namespace
{
	FString SovereignVenueTokenForArena(const FString& ArenaId)
	{
		static const TMap<FString, FString> Map = [] {
			TMap<FString, FString> M;
			M.Add(TEXT("basketball_h2h"), TEXT("Venice_Beach_Court"));
			M.Add(TEXT("basketball_dunk"), TEXT("Venice_Beach_Court"));
			M.Add(TEXT("basketball_3v3"), TEXT("Venice_Beach_Court"));
			M.Add(TEXT("karate"), TEXT("Zen_Dojo"));
			M.Add(TEXT("karate_h2h"), TEXT("Zen_Dojo"));
			M.Add(TEXT("karate_endless"), TEXT("Zen_Dojo"));
			M.Add(TEXT("baseball"), TEXT("Baseball_Park"));
			M.Add(TEXT("football"), TEXT("Gridiron_Stadium"));
			M.Add(TEXT("soccer"), TEXT("Soccer_Stadium"));
			M.Add(TEXT("golf"), TEXT("Links_Course"));
			M.Add(TEXT("tennis"), TEXT("Tennis_Court"));
			M.Add(TEXT("volleyball"), TEXT("Sand_Court"));
			M.Add(TEXT("gymnastics"), TEXT("Training_Floor"));
			M.Add(TEXT("surfing"), TEXT("Venice_Beach_Surf"));
			M.Add(TEXT("skateboarding"), TEXT("Skate_Park"));
			M.Add(TEXT("snowboarding"), TEXT("Mountain_Slope"));
			M.Add(TEXT("brain_brawl"), TEXT("Neuro_Arena"));
			M.Add(TEXT("market_browse"), TEXT("Sovereign_Shop"));
			M.Add(TEXT("who_scene_it"), TEXT("Neuro_Arena"));
			M.Add(TEXT("court_carnival"), TEXT("Venice_Beach_Court"));
			return M;
		}();
		if (const FString* Found = Map.Find(ArenaId))
		{
			return *Found;
		}
		return FString();
	}

	FString SovereignHandshakeDisplayMode(const FString& ArenaId)
	{
		if (ArenaId == TEXT("basketball_dunk"))
		{
			return TEXT("Venice_Beach_Dunk");
		}
		if (ArenaId == TEXT("basketball_h2h"))
		{
			return TEXT("Venice_Beach_Street");
		}
		if (ArenaId == TEXT("basketball_3v3"))
		{
			return TEXT("Venice_Beach_3v3");
		}
		if (ArenaId.StartsWith(TEXT("karate")))
		{
			return TEXT("Zen_Dojo_Karate");
		}
		if (ArenaId == TEXT("surfing"))
		{
			return TEXT("Venice_Beach_Surf");
		}
		if (ArenaId == TEXT("brain_brawl"))
		{
			return TEXT("Neuro_Arena");
		}
		if (ArenaId == TEXT("who_scene_it"))
		{
			return TEXT("Neuro_Arena");
		}
		if (ArenaId == TEXT("court_carnival"))
		{
			return TEXT("Venice_Beach_Court");
		}
		return ArenaId.IsEmpty() ? TEXT("Venice_Beach_Default") : ArenaId;
	}

	/** Matches `backend/FEL_ModeManager.production.json` `map` (maps package path). */
	FString FELProductionMapPathForMode(const FString& ModeId)
	{
		static const TMap<FString, FString> P = [] {
			TMap<FString, FString> M;
			M.Add(TEXT("basketball_h2h"), TEXT("/Game/FEL/Maps/Venice_Beach_Court"));
			M.Add(TEXT("basketball_dunk"), TEXT("/Game/FEL/Maps/Venice_Beach_Court"));
			M.Add(TEXT("basketball_3v3"), TEXT("/Game/FEL/Maps/Venice_Beach_Court"));
			M.Add(TEXT("karate_h2h"), TEXT("/Game/FEL/Maps/Zen_Dojo"));
			M.Add(TEXT("karate_endless"), TEXT("/Game/FEL/Maps/Zen_Dojo"));
			M.Add(TEXT("baseball"), TEXT("/Game/FEL/Maps/Baseball_Park"));
			M.Add(TEXT("football"), TEXT("/Game/FEL/Maps/Gridiron_Stadium"));
			M.Add(TEXT("soccer"), TEXT("/Game/FEL/Maps/Soccer_Stadium"));
			M.Add(TEXT("golf"), TEXT("/Game/FEL/Maps/Links_Course"));
			M.Add(TEXT("tennis"), TEXT("/Game/FEL/Maps/Tennis_Court"));
			M.Add(TEXT("volleyball"), TEXT("/Game/FEL/Maps/Sand_Court"));
			M.Add(TEXT("gymnastics"), TEXT("/Game/FEL/Maps/Training_Floor"));
			M.Add(TEXT("surfing"), TEXT("/Game/FEL/Maps/Venice_Beach_Surf"));
			M.Add(TEXT("skateboarding"), TEXT("/Game/FEL/Maps/Skate_Park"));
			M.Add(TEXT("snowboarding"), TEXT("/Game/FEL/Maps/Mountain_Slope"));
			M.Add(TEXT("brain_brawl"), TEXT("/Game/FEL/Maps/Neuro_Arena"));
			M.Add(TEXT("market_browse"), TEXT("/Game/FEL/Maps/Sovereign_Shop"));
			M.Add(TEXT("who_scene_it"), TEXT("/Game/FEL/Maps/Neuro_Arena"));
			M.Add(TEXT("court_carnival"), TEXT("/Game/FEL/Maps/Venice_Beach_Court"));
			return M;
		}();
		if (const FString* Found = P.Find(ModeId))
		{
			return *Found;
		}
		return FString();
	}
}

void UFELEmergentBridgeSubsystem::LoadEmergentDefaultsFromIni()
{
	const FString GameIni = FPaths::ProjectConfigDir() / TEXT("DefaultGame.ini");
	if (!FPaths::FileExists(GameIni))
	{
		return;
	}
	FString Url;
	if (GConfig->GetString(TEXT("Emergent"), TEXT("GameWebSocketUrl"), Url, GameIni))
	{
		Url = Url.TrimStartAndEnd();
		if (!Url.IsEmpty())
		{
			CachedWsUrl = Url;
		}
	}
	bool bKa = bKeepaliveEnabled;
	if (GConfig->GetBool(TEXT("Emergent"), TEXT("bFocusKeepalive"), bKa, GameIni))
	{
		bKeepaliveEnabled = bKa;
	}
	float KaInterval = KeepaliveInterval;
	if (GConfig->GetFloat(TEXT("Emergent"), TEXT("KeepaliveInterval"), KaInterval, GameIni))
	{
		KeepaliveInterval = FMath::Max(0.05f, KaInterval);
	}

	bool bAr = bAutoReconnect;
	if (GConfig->GetBool(TEXT("Emergent"), TEXT("bAutoReconnect"), bAr, GameIni))
	{
		bAutoReconnect = bAr;
	}
	float Rd = ReconnectDelaySeconds;
	if (GConfig->GetFloat(TEXT("Emergent"), TEXT("ReconnectDelaySeconds"), Rd, GameIni))
	{
		ReconnectDelaySeconds = FMath::Max(0.5f, Rd);
	}
	int32 MaxRA = MaxReconnectAttempts;
	if (GConfig->GetInt(TEXT("Emergent"), TEXT("MaxReconnectAttempts"), MaxRA, GameIni))
	{
		MaxReconnectAttempts = FMath::Max(0, MaxRA);
	}

	GConfig->GetString(TEXT("Emergent"), TEXT("SovereignHubHost"), SovereignHubHostIni, GameIni);
	SovereignHubHostIni.TrimStartAndEndInline();

	GConfig->GetBool(TEXT("EmergentHubDiscovery"), TEXT("bProbeCandidateHosts"), bProbeCandidateHosts, GameIni);
	FString RawCandidates;
	if (GConfig->GetString(TEXT("EmergentHubDiscovery"), TEXT("CandidateLanHosts"), RawCandidates, GameIni))
	{
		CandidateLanHosts.Reset();
		TArray<FString> Parts;
		RawCandidates.ParseIntoArray(Parts, TEXT(","));
		for (FString& P : Parts)
		{
			P.TrimStartAndEndInline();
			if (!P.IsEmpty())
			{
				CandidateLanHosts.Add(P);
			}
		}
	}
	GConfig->GetInt(TEXT("EmergentHubDiscovery"), TEXT("DiscoveryPort"), DiscoveryPortOverride, GameIni);
	GConfig->GetBool(TEXT("EmergentHubDiscovery"), TEXT("bScanLocalSubnet"), bScanLocalSubnet, GameIni);
}

void UFELEmergentBridgeSubsystem::ApplyDynamicHubResolution(FString& InOutUrl)
{
	if (InOutUrl.IsEmpty())
	{
		return;
	}

	const bool bLocal = InOutUrl.Contains(TEXT("127.0.0.1"))
		|| InOutUrl.Contains(TEXT("localhost"), ESearchCase::IgnoreCase);
	if (!bLocal)
	{
		return;
	}

	FString Hub = FPlatformMisc::GetEnvironmentVariable(TEXT("EMERGENT_SOVEREIGN_HOST")).TrimStartAndEnd();
	if (Hub.IsEmpty())
	{
		Hub = SovereignHubHostIni;
	}

	if (!Hub.IsEmpty())
	{
		InOutUrl.ReplaceInline(TEXT("127.0.0.1"), *Hub);
		InOutUrl.ReplaceInline(TEXT("localhost"), *Hub, ESearchCase::IgnoreCase);
		return;
	}

	const int32 Port =
		(DiscoveryPortOverride > 0) ? DiscoveryPortOverride : FelExtractPortFromWsUrl(InOutUrl);

	if (bProbeCandidateHosts && CandidateLanHosts.Num() > 0)
	{
		for (const FString& H : CandidateLanHosts)
		{
			if (!FelProbeTcpHost(H, Port))
			{
				continue;
			}
			InOutUrl.ReplaceInline(TEXT("127.0.0.1"), *H);
			InOutUrl.ReplaceInline(TEXT("localhost"), *H, ESearchCase::IgnoreCase);
			UE_LOG(LogTemp, Log, TEXT("[SovereignHub] Candidate LAN hub %s:%d (TCP probe OK)"), *H, Port);
			return;
		}
	}

	// IMPORTANT: Avoid full subnet scans on the game thread; blocking connects over a /24 can freeze startup on iOS.
	// If you need LAN routing, set either:
	//   - [Emergent] SovereignHubHost=192.168.x.y
	//   - EMERGENT_SOVEREIGN_HOST env
	//   - [EmergentHubDiscovery] CandidateLanHosts=192.168.x.y,192.168.x.z (with bProbeCandidateHosts=True)
	if (bScanLocalSubnet)
	{
		UE_LOG(LogTemp, Warning,
			TEXT("[SovereignHub] bScanLocalSubnet is enabled but full subnet scan is disabled for UX safety. Set SovereignHubHost or CandidateLanHosts instead."));
	}
}

bool UFELEmergentBridgeSubsystem::FelProbeTcpHost(const FString& Host, int32 Port) const
{
	if (Host.IsEmpty() || Port <= 0)
	{
		return false;
	}

	ISocketSubsystem* SockSub = ISocketSubsystem::Get(PLATFORM_SOCKETSUBSYSTEM);
	if (!SockSub)
	{
		return false;
	}

	FSocket* ProbeSocket = SockSub->CreateSocket(NAME_Stream, TEXT("FelLanProbe"), false);
	if (!ProbeSocket)
	{
		return false;
	}

	TSharedRef<FInternetAddr> Addr = SockSub->CreateInternetAddr();
	bool bResolved = false;
	Addr->SetIp(*Host, bResolved);
	if (!bResolved)
	{
		SockSub->DestroySocket(ProbeSocket);
		return false;
	}
	Addr->SetPort(Port);

	// Keep probes very short to avoid blocking the game thread.
	ProbeSocket->SetNonBlocking(true);
	const bool bStarted = ProbeSocket->Connect(*Addr);
	bool bConnected = bStarted;
	if (!bConnected)
	{
		bConnected = ProbeSocket->Wait(ESocketWaitConditions::WaitForWrite, FTimespan::FromMilliseconds(50));
	}
	ProbeSocket->Close();
	SockSub->DestroySocket(ProbeSocket);
	return bConnected;
}

FString UFELEmergentBridgeSubsystem::FelDiscoverHubViaSubnetScan(int32 Port) const
{
	if (Port <= 0)
	{
		return FString();
	}

	ISocketSubsystem* SockSub = ISocketSubsystem::Get(PLATFORM_SOCKETSUBSYSTEM);
	if (!SockSub)
	{
		return FString();
	}

	TArray<TSharedPtr<FInternetAddr>> Adapters;
	if (!SockSub->GetLocalAdapterAddresses(Adapters) || Adapters.Num() == 0)
	{
		UE_LOG(LogTemp, Warning, TEXT("[SovereignHub] Subnet scan skipped (no local IPv4 adapters)."));
		return FString();
	}

	for (const TSharedPtr<FInternetAddr>& Adapter : Adapters)
	{
		if (!Adapter.IsValid())
		{
			continue;
		}

		FString IpOnly = Adapter->ToString(false);
		int32 ColonIdx = INDEX_NONE;
		if (IpOnly.FindLastChar(TEXT(':'), ColonIdx))
		{
			IpOnly.LeftInline(ColonIdx);
		}

		TArray<FString> Octets;
		IpOnly.ParseIntoArray(Octets, TEXT("."));
		if (Octets.Num() != 4)
		{
			continue;
		}

		const int32 O0 = FCString::Atoi(*Octets[0]);
		const int32 O1 = FCString::Atoi(*Octets[1]);
		const int32 O2 = FCString::Atoi(*Octets[2]);
		const int32 O3 = FCString::Atoi(*Octets[3]);
		if (O0 == 127)
		{
			continue;
		}

		for (int32 Last = 1; Last <= 254; ++Last)
		{
			if (Last == O3)
			{
				continue;
			}

			const FString Host =
				FString::Printf(TEXT("%d.%d.%d.%d"), O0, O1, O2, Last);
			if (FelProbeTcpHost(Host, Port))
			{
				return Host;
			}
		}
	}

	return FString();
}

int32 UFELEmergentBridgeSubsystem::FelExtractPortFromWsUrl(const FString& Url) const
{
	const int32 SchemeIdx = Url.Find(TEXT("://"));
	if (SchemeIdx == INDEX_NONE)
	{
		return (DiscoveryPortOverride > 0) ? DiscoveryPortOverride : 8787;
	}

	FString AfterScheme = Url.Mid(SchemeIdx + 3);
	int32 SlashIdx = INDEX_NONE;
	AfterScheme.FindChar(TEXT('/'), SlashIdx);
	const FString HostPort = (SlashIdx == INDEX_NONE) ? AfterScheme : AfterScheme.Left(SlashIdx);

	int32 ColonIdx = INDEX_NONE;
	if (!HostPort.FindLastChar(TEXT(':'), ColonIdx))
	{
		return (DiscoveryPortOverride > 0) ? DiscoveryPortOverride : 8787;
	}

	const int32 Parsed = FCString::Atoi(*HostPort.Mid(ColonIdx + 1));
	return Parsed > 0 ? Parsed : ((DiscoveryPortOverride > 0) ? DiscoveryPortOverride : 8787);
}

void UFELEmergentBridgeSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	if (!FModuleManager::Get().IsModuleLoaded("WebSockets"))
	{
		FModuleManager::Get().LoadModule("WebSockets");
	}

	SovereignDb = MakeUnique<FELEmergentSovereignDatabase>();
	FString DbDir = FPaths::ProjectSavedDir() / TEXT("Sovereign");
	IFileManager::Get().MakeDirectory(*DbDir, true);
	FString DbPath = DbDir / TEXT("Sovereign.db");
	if (!SovereignDb->Open(DbPath))
	{
		UE_LOG(LogTemp, Error, TEXT("FELEmergentBridgeSubsystem: Failed to open Sovereign database at %s"), *DbPath);
	}
	else
	{
		UE_LOG(LogTemp, Log, TEXT("FELEmergentBridgeSubsystem: Sovereign database opened successfully at %s"), *DbPath);
	}

	LoadEmergentDefaultsFromIni();

	FString UrlToUse = FPlatformMisc::GetEnvironmentVariable(TEXT("EMERGENT_GAME_WS_URL")).TrimStartAndEnd();
	if (UrlToUse.IsEmpty())
	{
		UrlToUse = CachedWsUrl;
	}
	if (!UrlToUse.IsEmpty())
	{
		ApplyDynamicHubResolution(UrlToUse);
		SetGameWebSocketUrl(UrlToUse);
	}
}

void UFELEmergentBridgeSubsystem::Deinitialize()
{
	bDeinitializing = true;
	StopSovereignTelemetryTimer();
	if (UGameInstance* GI = GetGameInstance())
	{
		GI->GetTimerManager().ClearTimer(FocusTimer);
		GI->GetTimerManager().ClearTimer(ReconnectTimer);
		GI->GetTimerManager().ClearTimer(SovereignDeferTimer);
	}
	PendingOutboundMessages.Reset();
	if (Socket.IsValid())
	{
		Socket->Close();
		Socket.Reset();
	}

	if (SovereignDb.IsValid())
	{
		SovereignDb->Close();
		SovereignDb.Reset();
	}

	Super::Deinitialize();
}

void UFELEmergentBridgeSubsystem::SetGameWebSocketUrl(const FString& FullWsUrl)
{
	PendingOutboundMessages.Reset();
	ReconnectAttemptCount = 0;

	if (UGameInstance* GI = GetGameInstance())
	{
		GI->GetTimerManager().ClearTimer(ReconnectTimer);
	}

	CachedWsUrl = FullWsUrl.TrimStartAndEnd();

	if (CachedWsUrl.IsEmpty())
	{
		if (Socket.IsValid())
		{
			Socket->Close();
			Socket.Reset();
		}
		return;
	}

	if (Socket.IsValid())
	{
		Socket->Close();
		Socket.Reset();
	}
	EnsureSocketCreated();
}

void UFELEmergentBridgeSubsystem::EnsureSocketCreated()
{
	if (CachedWsUrl.IsEmpty() || Socket.IsValid())
	{
		return;
	}
	if (!FModuleManager::Get().IsModuleLoaded("WebSockets"))
	{
		FModuleManager::Get().LoadModule("WebSockets");
	}
	Socket = FWebSocketsModule::Get().CreateWebSocket(CachedWsUrl, FString());
	BindSocketHandlers();
	Socket->Connect();
}

void UFELEmergentBridgeSubsystem::BindSocketHandlers()
{
	if (!Socket.IsValid())
	{
		return;
	}

	Socket->OnConnected().AddLambda([this]()
	{
		ReconnectAttemptCount = 0;
		if (UGameInstance* GI = GetGameInstance())
		{
			GI->GetTimerManager().ClearTimer(ReconnectTimer);
		}

		UE_LOG(LogTemp, Log, TEXT("Emergent WS connected (%s)"), *CachedWsUrl);

		FlushOutboundQueue();

		TryStartSovereignTelemetryTimer();

		if (bKeepaliveEnabled && GetGameInstance())
		{
			GetGameInstance()->GetTimerManager().SetTimer(
				FocusTimer, this, &UFELEmergentBridgeSubsystem::TickFocusKeepalive, KeepaliveInterval, true);
		}
	});

	Socket->OnMessage().AddLambda([this](const FString& Message)
	{
		UE_LOG(LogTemp, Verbose, TEXT("Emergent WS inbound: %s"), *Message);
		OnEmergentRawMessage.Broadcast(Message);
	});

	Socket->OnConnectionError().AddLambda([this](const FString& Err)
	{
		UE_LOG(LogTemp, Warning, TEXT("Emergent WS connection error: %s"), *Err);
		HandleSocketClosedOrError();
	});

	Socket->OnClosed().AddLambda([this](int32 Code, const FString& Reason, bool /*bRemote*/)
	{
		UE_LOG(LogTemp, Log, TEXT("Emergent WS closed (%d): %s"), Code, *Reason);
		HandleSocketClosedOrError();
	});
}

void UFELEmergentBridgeSubsystem::HandleSocketClosedOrError()
{
	StopSovereignTelemetryTimer();
	if (UGameInstance* GI = GetGameInstance())
	{
		GI->GetTimerManager().ClearTimer(FocusTimer);
	}

	Socket.Reset();

	if (bDeinitializing || !bAutoReconnect || CachedWsUrl.IsEmpty())
	{
		return;
	}

	ScheduleReconnect();
}

void UFELEmergentBridgeSubsystem::ScheduleReconnect()
{
	if (bDeinitializing || !bAutoReconnect || CachedWsUrl.IsEmpty())
	{
		return;
	}
	if (MaxReconnectAttempts > 0 && ReconnectAttemptCount >= MaxReconnectAttempts)
	{
		UE_LOG(LogTemp, Warning, TEXT("Emergent: max reconnect attempts (%d) reached; stopping."), MaxReconnectAttempts);
		return;
	}

	UGameInstance* GI = GetGameInstance();
	if (!GI)
	{
		return;
	}

	GI->GetTimerManager().ClearTimer(ReconnectTimer);
	GI->GetTimerManager().SetTimer(
		ReconnectTimer, this, &UFELEmergentBridgeSubsystem::AttemptReconnect, ReconnectDelaySeconds, false);

	UE_LOG(LogTemp, Log, TEXT("Emergent: reconnect scheduled in %.1fs (attempt next: %d)."),
		ReconnectDelaySeconds,
		ReconnectAttemptCount + 1);
}

void UFELEmergentBridgeSubsystem::AttemptReconnect()
{
	if (bDeinitializing || CachedWsUrl.IsEmpty())
	{
		return;
	}
	ReconnectAttemptCount++;
	EnsureSocketCreated();
}

void UFELEmergentBridgeSubsystem::FlushOutboundQueue()
{
	if (!Socket.IsValid() || !Socket->IsConnected())
	{
		return;
	}
	for (const FString& Msg : PendingOutboundMessages)
	{
		Socket->Send(Msg);
	}
	PendingOutboundMessages.Reset();
}

void UFELEmergentBridgeSubsystem::SendMatchScoreToWebSocket(int32 ScoreA, int32 ScoreB, const FString& ExtraJsonFields)
{
	EnsureSocketCreated();
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("match_score_final"));
	O->SetNumberField(TEXT("score_a"), ScoreA);
	O->SetNumberField(TEXT("score_b"), ScoreB);
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	if (!ExtraJsonFields.IsEmpty())
	{
		O->SetStringField(TEXT("extra"), ExtraJsonFields);
	}
	SendJsonObject(O);
}

void UFELEmergentBridgeSubsystem::SetFocusKeepaliveEnabled(bool bEnable, float IntervalSeconds)
{
	bKeepaliveEnabled = bEnable;
	KeepaliveInterval = FMath::Max(0.05f, IntervalSeconds);
	if (!GetGameInstance())
	{
		return;
	}
	GetGameInstance()->GetTimerManager().ClearTimer(FocusTimer);
	if (bKeepaliveEnabled)
	{
		EnsureSocketCreated();
		if (Socket.IsValid() && Socket->IsConnected())
		{
			GetGameInstance()->GetTimerManager().SetTimer(
				FocusTimer, this, &UFELEmergentBridgeSubsystem::TickFocusKeepalive, KeepaliveInterval, true);
		}
	}
}

void UFELEmergentBridgeSubsystem::TickFocusKeepalive()
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("focus_keepalive"));
	O->SetStringField(TEXT("source"), TEXT("ue"));
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELEmergentBridgeSubsystem::BroadcastMapLoaded(const FString& MapTokenOrPackage, const FString& ModeId)
{
	bSovereignHandshakeLoggedThisMap = false;

	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("map_loaded"));
	O->SetStringField(TEXT("map"), MapTokenOrPackage);
	O->SetStringField(TEXT("mode"), ModeId);
	FString ProdPath = FELProductionMapPathForMode(ModeId);
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* W = GI->GetWorld())
		{
			if (AFELBasketballGameState* GS = W->GetGameState<AFELBasketballGameState>())
			{
				const FString ArenaId = GS->GetArenaGameModeId();
				if (ProdPath.IsEmpty())
				{
					ProdPath = FELProductionMapPathForMode(ArenaId);
				}
				O->SetStringField(TEXT("arena_game_mode_id"), ArenaId);
				O->SetStringField(TEXT("venue_token"), SovereignVenueTokenForArena(ArenaId));
				O->SetStringField(TEXT("sovereign_display_mode"), SovereignHandshakeDisplayMode(ArenaId));
				O->SetNumberField(TEXT("prq"), GS->GetReadinessSnapshot().PRQScore);
				O->SetNumberField(TEXT("combo_meter"), GS->GetComboMeter01());
			}
		}
	}
	if (!ProdPath.IsEmpty())
	{
		O->SetStringField(TEXT("production_map_path"), ProdPath);
	}
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELEmergentBridgeSubsystem::EmitSovereignSessionSnapshot(UWorld* World)
{
	if (!World)
	{
		return;
	}
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("sovereign_session"));
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	FString MapName = World->GetMapName();
	MapName.RemoveFromStart(World->StreamingLevelsPrefix);
	O->SetStringField(TEXT("map"), MapName);

	if (AFELBasketballGameState* GS = World->GetGameState<AFELBasketballGameState>())
	{
		const FString ArenaId = GS->GetArenaGameModeId();
		const FString ProdPath = FELProductionMapPathForMode(ArenaId);
		if (!ProdPath.IsEmpty())
		{
			O->SetStringField(TEXT("production_map_path"), ProdPath);
		}
		O->SetStringField(TEXT("arena_game_mode_id"), ArenaId);
		O->SetStringField(TEXT("venue_token"), SovereignVenueTokenForArena(ArenaId));
		O->SetStringField(TEXT("sovereign_display_mode"), SovereignHandshakeDisplayMode(ArenaId));
		O->SetNumberField(TEXT("prq"), GS->GetReadinessSnapshot().PRQScore);
		O->SetNumberField(TEXT("combo_streak"), GS->GetComboStreak());
		O->SetNumberField(TEXT("combo_meter"), GS->GetComboMeter01());

		if (SovereignDb.IsValid() && SovereignDb->IsOpen())
		{
			SovereignDb->InsertSample(GS);
		}

		if (!bSovereignHandshakeLoggedThisMap && !ArenaId.IsEmpty())
		{
			UE_LOG(LogTemp, Log, TEXT("[SovereignHub] Handshake Successful - Mode: %s"), *SovereignHandshakeDisplayMode(ArenaId));
			bSovereignHandshakeLoggedThisMap = true;
		}
	}
	SendJsonObject(O);
	TryStartSovereignTelemetryTimer();
}

void UFELEmergentBridgeSubsystem::ScheduleSovereignSessionSnapshotDeferred(float DelaySeconds)
{
	if (!GetGameInstance())
	{
		return;
	}
	UGameInstance* GI = GetGameInstance();
	GI->GetTimerManager().ClearTimer(SovereignDeferTimer);
	GI->GetTimerManager().SetTimer(
		SovereignDeferTimer,
		[this]()
		{
			if (UGameInstance* G = GetGameInstance())
			{
				EmitSovereignSessionSnapshot(G->GetWorld());
			}
		},
		FMath::Max(0.02f, DelaySeconds),
		false);
}

void UFELEmergentBridgeSubsystem::TickSovereignTelemetry()
{
	if (!Socket.IsValid() || !Socket->IsConnected())
	{
		return;
	}
	UGameInstance* GI = GetGameInstance();
	if (!GI)
	{
		return;
	}
	UWorld* W = GI->GetWorld();
	if (!W)
	{
		return;
	}
	AFELBasketballGameState* GS = W->GetGameState<AFELBasketballGameState>();
	if (!GS)
	{
		return;
	}
	const FString ArenaId = GS->GetArenaGameModeId();
	if (!bSovereignHandshakeLoggedThisMap && !ArenaId.IsEmpty())
	{
		UE_LOG(LogTemp, Log, TEXT("[SovereignHub] Handshake Successful - Mode: %s"), *SovereignHandshakeDisplayMode(ArenaId));
		bSovereignHandshakeLoggedThisMap = true;
	}
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("sovereign_telemetry"));
	O->SetNumberField(TEXT("prq"), GS->GetReadinessSnapshot().PRQScore);
	O->SetNumberField(TEXT("combo_streak"), GS->GetComboStreak());
	O->SetNumberField(TEXT("combo_meter"), GS->GetComboMeter01());
	O->SetStringField(TEXT("arena_game_mode_id"), ArenaId);
	O->SetStringField(TEXT("venue_token"), SovereignVenueTokenForArena(ArenaId));
	O->SetStringField(TEXT("sovereign_display_mode"), SovereignHandshakeDisplayMode(ArenaId));
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELEmergentBridgeSubsystem::TryStartSovereignTelemetryTimer()
{
	if (!GetGameInstance())
	{
		return;
	}
	GetGameInstance()->GetTimerManager().ClearTimer(SovereignTelemetryTimer);
	GetGameInstance()->GetTimerManager().SetTimer(
		SovereignTelemetryTimer,
		this,
		&UFELEmergentBridgeSubsystem::TickSovereignTelemetry,
		SovereignTelemetryIntervalSeconds,
		true);
}

void UFELEmergentBridgeSubsystem::StopSovereignTelemetryTimer()
{
	if (GetGameInstance())
	{
		GetGameInstance()->GetTimerManager().ClearTimer(SovereignTelemetryTimer);
	}
}

void UFELEmergentBridgeSubsystem::SendJsonObject(const TSharedPtr<FJsonObject>& Payload)
{
	if (!Payload.IsValid())
	{
		return;
	}

	FString Out;
	TSharedRef<TJsonWriter<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>> W =
		TJsonWriterFactory<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>::Create(&Out);
	FJsonSerializer::Serialize(Payload.ToSharedRef(), W);

	if (!Socket.IsValid() || !Socket->IsConnected())
	{
		if (PendingOutboundMessages.Num() >= MaxPendingOutbound)
		{
			PendingOutboundMessages.RemoveAt(0);
			UE_LOG(LogTemp, Warning,
				TEXT("Emergent: outbound queue full (%d); dropped oldest pending message."), MaxPendingOutbound);
		}
		PendingOutboundMessages.Add(MoveTemp(Out));
		UE_LOG(LogTemp, Verbose, TEXT("Emergent: queued outbound JSON (socket not connected). Queue size=%d."),
			PendingOutboundMessages.Num());
		return;
	}

	Socket->Send(Out);
}

void UFELEmergentBridgeSubsystem::SendSceneItBuzzToHub(const FString& RoundId, const FString& ClipId, const FString& PlayerId, double ClientMonotonicMs)
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("fel_scene_it_buzz"));
	O->SetStringField(TEXT("round_id"), RoundId);
	O->SetStringField(TEXT("clip_id"), ClipId);
	O->SetStringField(TEXT("player_id"), PlayerId);
	O->SetNumberField(TEXT("client_monotonic_ms"), ClientMonotonicMs);
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELEmergentBridgeSubsystem::SendSceneItAnswerToHub(const FString& RoundId, const FString& ClipId, const FString& PlayerId, bool bCorrect, int32 ChosenIndex, int32 EvolutionShardsAwarded, float DistorterResolveAtBuzz)
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("fel_scene_it_answer"));
	O->SetStringField(TEXT("round_id"), RoundId);
	O->SetStringField(TEXT("clip_id"), ClipId);
	O->SetStringField(TEXT("player_id"), PlayerId);
	O->SetBoolField(TEXT("correct"), bCorrect);
	O->SetNumberField(TEXT("chosen_index"), ChosenIndex);
	O->SetNumberField(TEXT("evolution_shards_awarded"), EvolutionShardsAwarded);
	O->SetNumberField(TEXT("distorter_resolve_at_buzz"), DistorterResolveAtBuzz);
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);

	if (bCorrect && EvolutionShardsAwarded > 0)
	{
		AddLocalEvolutionShards(EvolutionShardsAwarded, FString::Printf(TEXT("SceneIt round Correct Answer - clip %s"), *ClipId), FString(), false);
	}
}

bool UFELEmergentBridgeSubsystem::TryQueryDraftActivations(int32 OptionalDraftYear, const FString& OptionalPathwaySubstring, int32 MaxRows, TArray<FFELDraftCardRow>& OutRows) const
{
	if (SovereignDb.IsValid() && SovereignDb->IsOpen())
	{
		return SovereignDb->TryQueryDraftActivations(OptionalDraftYear, OptionalPathwaySubstring, MaxRows, OutRows);
	}
	return false;
}

bool UFELEmergentBridgeSubsystem::TryQueryVaultRecentSessions(int32 MaxRows, TArray<FFELVaultRow>& OutRows) const
{
	if (SovereignDb.IsValid() && SovereignDb->IsOpen())
	{
		return SovereignDb->TryQueryRecentVaultRows(MaxRows, OutRows);
	}
	return false;
}

bool UFELEmergentBridgeSubsystem::TryGetLocalEvolutionShardTotal(int64& OutTotal) const
{
	OutTotal = 0;
	if (SovereignDb.IsValid() && SovereignDb->IsOpen())
	{
		return SovereignDb->TrySumShardLedger(OutTotal);
	}
	return false;
}

bool UFELEmergentBridgeSubsystem::InsertLocalDraftActivation(const FString& CardId, int32 DraftYear, const FString& Pathway, const FString& SerialId, const FString& SignatureHex, bool bCommissionerMint)
{
	if (SovereignDb.IsValid() && SovereignDb->IsOpen())
	{
		return SovereignDb->InsertDraftActivation(CardId, DraftYear, Pathway, SerialId, SignatureHex, bCommissionerMint);
	}
	return false;
}

bool UFELEmergentBridgeSubsystem::AddLocalEvolutionShards(int32 Delta, const FString& Reason, const FString& RefMealId, bool bRecommendedPick)
{
	if (SovereignDb.IsValid() && SovereignDb->IsOpen())
	{
		return SovereignDb->InsertShardLedgerEntry(Delta, Reason, RefMealId, bRecommendedPick);
	}
	return false;
}

bool UFELEmergentBridgeSubsystem::IsFullySecure() const
{
	return bImuSensorReady && bImuHudIntegrityOk && bIsHardwareAuthenticated && bMonotonicClockTrusted;
}

void UFELEmergentBridgeSubsystem::SendFuelConciergeOrderToHub(const FString& MealIdOrdered, bool bOrderedRecommendedMeal, int32 Shards, int32 TrainingPhase, float PRQScore)
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("fel_fuel_order"));
	O->SetStringField(TEXT("meal_id"), MealIdOrdered);
	O->SetBoolField(TEXT("recommended_pick"), bOrderedRecommendedMeal);
	O->SetNumberField(TEXT("shards_earned"), Shards);
	O->SetNumberField(TEXT("training_phase"), TrainingPhase);
	O->SetNumberField(TEXT("prq"), PRQScore);
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELEmergentBridgeSubsystem::GrantEvolutionShardsLocal(int32 Delta, const FString& Reason, const FString& RefMealId, bool bRecommendedPick)
{
	AddLocalEvolutionShards(Delta, Reason, RefMealId, bRecommendedPick);
}

void UFELEmergentBridgeSubsystem::SetCommissionerSessionActive(bool bActive)
{
	bIsCommissionerSessionActive = bActive;
}

void UFELEmergentBridgeSubsystem::SendCommissionerMintVerifyToHub(const FString& CardId, const FString& SerialId, int32 DraftYear, const FString& PathwayStr)
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("fel_commissioner_mint_verify"));
	O->SetStringField(TEXT("card_id"), CardId);
	O->SetStringField(TEXT("serial_id"), SerialId);
	O->SetNumberField(TEXT("draft_year"), DraftYear);
	O->SetStringField(TEXT("pathway"), PathwayStr);
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELEmergentBridgeSubsystem::SendDraftOwnerCertifiedToHub(const FString& CardId, const FString& SerialId, int32 DraftYear, const FString& PathwayStr, bool bCommissionerOk)
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("fel_draft_owner_certified"));
	O->SetStringField(TEXT("card_id"), CardId);
	O->SetStringField(TEXT("serial_id"), SerialId);
	O->SetNumberField(TEXT("draft_year"), DraftYear);
	O->SetStringField(TEXT("pathway"), PathwayStr);
	O->SetBoolField(TEXT("commissioner_ok"), bCommissionerOk);
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELEmergentBridgeSubsystem::SendJukeboxHostToHub(const FString& EquippedDjCardId, const FString& ActiveSpotifyPlaylistId, const FString& MenuPlaylistId)
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("fel_jukebox_host"));
	O->SetStringField(TEXT("dj_card_id"), EquippedDjCardId);
	O->SetStringField(TEXT("spotify_playlist_id"), ActiveSpotifyPlaylistId);
	O->SetStringField(TEXT("menu_playlist_id"), MenuPlaylistId);
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELEmergentBridgeSubsystem::SendDesignBlitzSubmitToHub(const FString& SessionId, int32 RoundIndex, const FString& JsonMetadataSnapshot)
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("fel_design_blitz_submit"));
	O->SetStringField(TEXT("session_id"), SessionId);
	O->SetNumberField(TEXT("round_index"), RoundIndex);
	O->SetStringField(TEXT("json_metadata_snapshot"), JsonMetadataSnapshot);
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELEmergentBridgeSubsystem::SendPartyBoardStateToHub(const FString& BoardId, int32 Phase, int32 SessionType, int32 ActivePlayerIndex, const TArray<FFELPartyPlayerSlot>& Players, const FString& PendingMinigameModeId, const FString& SubType)
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("fel_party_board_state"));
	O->SetStringField(TEXT("board_id"), BoardId);
	O->SetNumberField(TEXT("phase"), Phase);
	O->SetNumberField(TEXT("session_type"), SessionType);
	O->SetNumberField(TEXT("active_player_index"), ActivePlayerIndex);
	O->SetStringField(TEXT("pending_minigame_mode_id"), PendingMinigameModeId);
	O->SetStringField(TEXT("sub_type"), SubType);

	TArray<TSharedPtr<FJsonValue>> JsonPlayers;
	for (const FFELPartyPlayerSlot& P : Players)
	{
		TSharedPtr<FJsonObject> JP = MakeShared<FJsonObject>();
		JP->SetStringField(TEXT("card_id"), P.CardId);
		JP->SetStringField(TEXT("display_name"), P.DisplayName);
		JP->SetNumberField(TEXT("board_index"), P.BoardIndex);
		JP->SetNumberField(TEXT("evolution_shards"), P.EvolutionShards);
		JP->SetNumberField(TEXT("critique_tokens"), P.CritiqueTokens);
		JP->SetBoolField(TEXT("is_ghost"), P.bIsGhost);
		JP->SetNumberField(TEXT("last_die_roll"), P.LastDieRoll);
		JsonPlayers.Add(MakeShared<FJsonValueObject>(JP));
	}
	O->SetArrayField(TEXT("players"), JsonPlayers);
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELEmergentBridgeSubsystem::PersistDraftCardToVault(const FString& CardId, int32 DraftYear, const FString& PathwayStr, const FString& SerialId, const FString& Sig, bool bCommissionerOk)
{
	InsertLocalDraftActivation(CardId, DraftYear, PathwayStr, SerialId, Sig, bCommissionerOk);
}

void UFELEmergentBridgeSubsystem::PersistMatchEndSample(const AFELBasketballGameState* GS)
{
	if (SovereignDb.IsValid() && SovereignDb->IsOpen())
	{
		SovereignDb->InsertSample(GS);
	}
}

