// Copy into your game's Source/FinalEvolutionLab/ module.

#include "FELEmergentBridgeSubsystem.h"

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
		return ArenaId.IsEmpty() ? TEXT("Venice_Beach_Default") : ArenaId;
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
}

void UFELEmergentBridgeSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	if (!FModuleManager::Get().IsModuleLoaded("WebSockets"))
	{
		FModuleManager::Get().LoadModule("WebSockets");
	}

	LoadEmergentDefaultsFromIni();

	FString UrlToUse = FPlatformMisc::GetEnvironmentVariable(TEXT("EMERGENT_GAME_WS_URL")).TrimStartAndEnd();
	if (UrlToUse.IsEmpty())
	{
		UrlToUse = CachedWsUrl;
	}
	if (!UrlToUse.IsEmpty())
	{
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
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* W = GI->GetWorld())
		{
			if (AFELBasketballGameState* GS = W->GetGameState<AFELBasketballGameState>())
			{
				const FString ArenaId = GS->GetArenaGameModeId();
				O->SetStringField(TEXT("arena_game_mode_id"), ArenaId);
				O->SetStringField(TEXT("venue_token"), SovereignVenueTokenForArena(ArenaId));
				O->SetStringField(TEXT("sovereign_display_mode"), SovereignHandshakeDisplayMode(ArenaId));
				O->SetNumberField(TEXT("prq"), GS->GetReadinessSnapshot().PRQScore);
				O->SetNumberField(TEXT("combo_meter"), GS->GetComboMeter01());
			}
		}
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
		O->SetStringField(TEXT("arena_game_mode_id"), ArenaId);
		O->SetStringField(TEXT("venue_token"), SovereignVenueTokenForArena(ArenaId));
		O->SetStringField(TEXT("sovereign_display_mode"), SovereignHandshakeDisplayMode(ArenaId));
		O->SetNumberField(TEXT("prq"), GS->GetReadinessSnapshot().PRQScore);
		O->SetNumberField(TEXT("combo_streak"), GS->GetComboStreak());
		O->SetNumberField(TEXT("combo_meter"), GS->GetComboMeter01());

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
