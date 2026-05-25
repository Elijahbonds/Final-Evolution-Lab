// Copy into your game's Source/FinalEvolutionLab/ module.

#include "FELBridgeSubsystem.h"

#include "FELBasketballGameState.h"
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
	FString VaultVenueTokenForArena(const FString& ArenaId)
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
			M.Add(TEXT("market_browse"), TEXT("Vault_Shop"));
			return M;
		}();
		if (const FString* Found = Map.Find(ArenaId))
		{
			return *Found;
		}
		return FString();
	}

	FString VaultHandshakeDisplayMode(const FString& ArenaId)
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
		return ArenaId.IsEmpty() ? TEXT("Venice_Beach_Default") : ArenaId;
	}
}

void UFELBridgeSubsystem::LoadBridgeDefaultsFromIni()
{
	const FString GameIni = FPaths::ProjectConfigDir() / TEXT("DefaultGame.ini");
	if (!FPaths::FileExists(GameIni))
	{
		return;
	}
	FString Url;
	if (GConfig->GetString(TEXT("FELBridge"), TEXT("GameWebSocketUrl"), Url, GameIni))
	{
		Url = Url.TrimStartAndEnd();
		if (!Url.IsEmpty())
		{
			CachedWsUrl = Url;
		}
	}
	bool bKa = bKeepaliveEnabled;
	if (GConfig->GetBool(TEXT("FELBridge"), TEXT("bFocusKeepalive"), bKa, GameIni))
	{
		bKeepaliveEnabled = bKa;
	}
	float KaInterval = KeepaliveInterval;
	if (GConfig->GetFloat(TEXT("FELBridge"), TEXT("KeepaliveInterval"), KaInterval, GameIni))
	{
		KeepaliveInterval = FMath::Max(0.05f, KaInterval);
	}

	bool bAr = bAutoReconnect;
	if (GConfig->GetBool(TEXT("FELBridge"), TEXT("bAutoReconnect"), bAr, GameIni))
	{
		bAutoReconnect = bAr;
	}
	float Rd = ReconnectDelaySeconds;
	if (GConfig->GetFloat(TEXT("FELBridge"), TEXT("ReconnectDelaySeconds"), Rd, GameIni))
	{
		ReconnectDelaySeconds = FMath::Max(0.5f, Rd);
	}
	int32 MaxRA = MaxReconnectAttempts;
	if (GConfig->GetInt(TEXT("FELBridge"), TEXT("MaxReconnectAttempts"), MaxRA, GameIni))
	{
		MaxReconnectAttempts = FMath::Max(0, MaxRA);
	}

	GConfig->GetString(TEXT("FELBridge"), TEXT("VaultHubHost"), VaultHubHostIni, GameIni);
	VaultHubHostIni.TrimStartAndEndInline();

	GConfig->GetBool(TEXT("FELHubDiscovery"), TEXT("bProbeCandidateHosts"), bProbeCandidateHosts, GameIni);
	FString RawCandidates;
	if (GConfig->GetString(TEXT("FELHubDiscovery"), TEXT("CandidateLanHosts"), RawCandidates, GameIni))
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
	GConfig->GetInt(TEXT("FELHubDiscovery"), TEXT("DiscoveryPort"), DiscoveryPortOverride, GameIni);
	GConfig->GetBool(TEXT("FELHubDiscovery"), TEXT("bScanLocalSubnet"), bScanLocalSubnet, GameIni);
}

void UFELBridgeSubsystem::ApplyDynamicHubResolution(FString& InOutUrl)
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

	FString Hub = FPlatformMisc::GetEnvironmentVariable(TEXT("FEL_HUB_HOST")).TrimStartAndEnd();
	if (Hub.IsEmpty())
	{
		Hub = VaultHubHostIni;
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
			UE_LOG(LogTemp, Log, TEXT("[VaultHub] Candidate LAN hub %s:%d (TCP probe OK)"), *H, Port);
			return;
		}
	}

	// IMPORTANT: Avoid full subnet scans on the game thread; blocking connects over a /24 can freeze startup on iOS.
	// If you need LAN routing, set either:
	//   - [FELBridge] VaultHubHost=192.168.x.y
	//   - FEL_HUB_HOST env
	//   - [FELHubDiscovery] CandidateLanHosts=192.168.x.y,192.168.x.z (with bProbeCandidateHosts=True)
	if (bScanLocalSubnet)
	{
		UE_LOG(LogTemp, Warning,
			TEXT("[VaultHub] bScanLocalSubnet is enabled but full subnet scan is disabled for UX safety. Set VaultHubHost or CandidateLanHosts instead."));
	}
}

bool UFELBridgeSubsystem::FelProbeTcpHost(const FString& Host, int32 Port) const
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

	FSocket* Socket = SockSub->CreateSocket(NAME_Stream, TEXT("FelLanProbe"), false);
	if (!Socket)
	{
		return false;
	}

	TSharedRef<FInternetAddr> Addr = SockSub->CreateInternetAddr();
	bool bResolved = false;
	Addr->SetIp(*Host, bResolved);
	if (!bResolved)
	{
		SockSub->DestroySocket(Socket);
		return false;
	}
	Addr->SetPort(Port);

	// Keep probes very short to avoid blocking the game thread.
	Socket->SetNonBlocking(true);
	const bool bStarted = Socket->Connect(*Addr);
	bool bConnected = bStarted;
	if (!bConnected)
	{
		bConnected = Socket->Wait(ESocketWaitConditions::WaitForWrite, FTimespan::FromMilliseconds(50));
	}
	Socket->Close();
	SockSub->DestroySocket(Socket);
	return bConnected;
}

FString UFELBridgeSubsystem::FelDiscoverHubViaSubnetScan(int32 Port) const
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
		UE_LOG(LogTemp, Warning, TEXT("[VaultHub] Subnet scan skipped (no local IPv4 adapters)."));
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

int32 UFELBridgeSubsystem::FelExtractPortFromWsUrl(const FString& Url) const
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

void UFELBridgeSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	if (!FModuleManager::Get().IsModuleLoaded("WebSockets"))
	{
		FModuleManager::Get().LoadModule("WebSockets");
	}

	LoadBridgeDefaultsFromIni();

	FString UrlToUse = FPlatformMisc::GetEnvironmentVariable(TEXT("FEL_GAME_WS_URL")).TrimStartAndEnd();
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

void UFELBridgeSubsystem::Deinitialize()
{
	bDeinitializing = true;
	StopVaultTelemetryTimer();
	if (UGameInstance* GI = GetGameInstance())
	{
		GI->GetTimerManager().ClearTimer(FocusTimer);
		GI->GetTimerManager().ClearTimer(ReconnectTimer);
		GI->GetTimerManager().ClearTimer(VaultDeferTimer);
	}
	PendingOutboundMessages.Reset();
	if (Socket.IsValid())
	{
		Socket->Close();
		Socket.Reset();
	}
	Super::Deinitialize();
}

void UFELBridgeSubsystem::SetGameWebSocketUrl(const FString& FullWsUrl)
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

void UFELBridgeSubsystem::EnsureSocketCreated()
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

void UFELBridgeSubsystem::BindSocketHandlers()
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

		TryStartVaultTelemetryTimer();

		if (bKeepaliveEnabled && GetGameInstance())
		{
			GetGameInstance()->GetTimerManager().SetTimer(
				FocusTimer, this, &UFELBridgeSubsystem::TickFocusKeepalive, KeepaliveInterval, true);
		}
	});

	Socket->OnMessage().AddLambda([this](const FString& Message)
	{
		UE_LOG(LogTemp, Verbose, TEXT("Emergent WS inbound: %s"), *Message);
		OnRawMessage.Broadcast(Message);
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

void UFELBridgeSubsystem::HandleSocketClosedOrError()
{
	StopVaultTelemetryTimer();
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

void UFELBridgeSubsystem::ScheduleReconnect()
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
		ReconnectTimer, this, &UFELBridgeSubsystem::AttemptReconnect, ReconnectDelaySeconds, false);

	UE_LOG(LogTemp, Log, TEXT("Emergent: reconnect scheduled in %.1fs (attempt next: %d)."),
		ReconnectDelaySeconds,
		ReconnectAttemptCount + 1);
}

void UFELBridgeSubsystem::AttemptReconnect()
{
	if (bDeinitializing || CachedWsUrl.IsEmpty())
	{
		return;
	}
	ReconnectAttemptCount++;
	EnsureSocketCreated();
}

void UFELBridgeSubsystem::FlushOutboundQueue()
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

void UFELBridgeSubsystem::SendMatchScoreToWebSocket(int32 ScoreA, int32 ScoreB, const FString& ExtraJsonFields)
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

void UFELBridgeSubsystem::SetFocusKeepaliveEnabled(bool bEnable, float IntervalSeconds)
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
				FocusTimer, this, &UFELBridgeSubsystem::TickFocusKeepalive, KeepaliveInterval, true);
		}
	}
}

void UFELBridgeSubsystem::TickFocusKeepalive()
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("focus_keepalive"));
	O->SetStringField(TEXT("source"), TEXT("ue"));
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELBridgeSubsystem::BroadcastMapLoaded(const FString& MapTokenOrPackage, const FString& ModeId)
{
	bVaultHandshakeLoggedThisMap = false;

	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("map_loaded"));
	O->SetStringField(TEXT("map"), MapTokenOrPackage);
	O->SetStringField(TEXT("mode"), ModeId);
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* W = GI->GetWorld())
		{
			if (AFELBasketballGameState* GS = W->GetGameState<AFELBasketballGameState>())
			{
				const FString ArenaId = GS->GetArenaGameModeId();
				O->SetStringField(TEXT("arena_game_mode_id"), ArenaId);
				O->SetStringField(TEXT("venue_token"), VaultVenueTokenForArena(ArenaId));
				O->SetStringField(TEXT("vault_display_mode"), VaultHandshakeDisplayMode(ArenaId));
				O->SetNumberField(TEXT("prq"), GS->GetReadinessSnapshot().PRQScore);
				O->SetNumberField(TEXT("combo_meter"), GS->GetComboMeter01());
			}
		}
	}
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELBridgeSubsystem::EmitVaultSessionSnapshot(UWorld* World)
{
	if (!World)
	{
		return;
	}
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("vault_session"));
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	FString MapName = World->GetMapName();
	MapName.RemoveFromStart(World->StreamingLevelsPrefix);
	O->SetStringField(TEXT("map"), MapName);

	if (AFELBasketballGameState* GS = World->GetGameState<AFELBasketballGameState>())
	{
		const FString ArenaId = GS->GetArenaGameModeId();
		O->SetStringField(TEXT("arena_game_mode_id"), ArenaId);
		O->SetStringField(TEXT("venue_token"), VaultVenueTokenForArena(ArenaId));
		O->SetStringField(TEXT("vault_display_mode"), VaultHandshakeDisplayMode(ArenaId));
		O->SetNumberField(TEXT("prq"), GS->GetReadinessSnapshot().PRQScore);
		O->SetNumberField(TEXT("combo_streak"), GS->GetComboStreak());
		O->SetNumberField(TEXT("combo_meter"), GS->GetComboMeter01());

		if (!bVaultHandshakeLoggedThisMap && !ArenaId.IsEmpty())
		{
			UE_LOG(LogTemp, Log, TEXT("[VaultHub] Handshake Successful - Mode: %s"), *VaultHandshakeDisplayMode(ArenaId));
			bVaultHandshakeLoggedThisMap = true;
		}
	}
	SendJsonObject(O);
	TryStartVaultTelemetryTimer();
}

void UFELBridgeSubsystem::ScheduleVaultSessionSnapshotDeferred(float DelaySeconds)
{
	if (!GetGameInstance())
	{
		return;
	}
	UGameInstance* GI = GetGameInstance();
	GI->GetTimerManager().ClearTimer(VaultDeferTimer);
	GI->GetTimerManager().SetTimer(
		VaultDeferTimer,
		[this]()
		{
			if (UGameInstance* G = GetGameInstance())
			{
				EmitVaultSessionSnapshot(G->GetWorld());
			}
		},
		FMath::Max(0.02f, DelaySeconds),
		false);
}

void UFELBridgeSubsystem::TickVaultTelemetry()
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
	if (!bVaultHandshakeLoggedThisMap && !ArenaId.IsEmpty())
	{
		UE_LOG(LogTemp, Log, TEXT("[VaultHub] Handshake Successful - Mode: %s"), *VaultHandshakeDisplayMode(ArenaId));
		bVaultHandshakeLoggedThisMap = true;
	}
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("vault_telemetry"));
	O->SetNumberField(TEXT("prq"), GS->GetReadinessSnapshot().PRQScore);
	O->SetNumberField(TEXT("combo_streak"), GS->GetComboStreak());
	O->SetNumberField(TEXT("combo_meter"), GS->GetComboMeter01());
	O->SetStringField(TEXT("arena_game_mode_id"), ArenaId);
	O->SetStringField(TEXT("venue_token"), VaultVenueTokenForArena(ArenaId));
	O->SetStringField(TEXT("vault_display_mode"), VaultHandshakeDisplayMode(ArenaId));
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
}

void UFELBridgeSubsystem::TryStartVaultTelemetryTimer()
{
	if (!GetGameInstance())
	{
		return;
	}
	GetGameInstance()->GetTimerManager().ClearTimer(VaultTelemetryTimer);
	GetGameInstance()->GetTimerManager().SetTimer(
		VaultTelemetryTimer,
		this,
		&UFELBridgeSubsystem::TickVaultTelemetry,
		VaultTelemetryIntervalSeconds,
		true);
}

void UFELBridgeSubsystem::StopVaultTelemetryTimer()
{
	if (GetGameInstance())
	{
		GetGameInstance()->GetTimerManager().ClearTimer(VaultTelemetryTimer);
	}
}

void UFELBridgeSubsystem::SendJsonObject(const TSharedPtr<FJsonObject>& Payload)
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
