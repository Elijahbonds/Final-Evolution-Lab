// Copy into your game's Source/FinalEvolutionLab/ module.

#include "FELEmergentBridgeSubsystem.h"

#include "Dom/JsonObject.h"
#include "Policies/CondensedJsonPrintPolicy.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"
#include "TimerManager.h"
#include "Engine/GameInstance.h"
#include "HAL/PlatformMisc.h"
#include "Misc/ConfigCacheIni.h"
#include "Misc/DateTime.h"
#include "Misc/Paths.h"
#include "WebSocketsModule.h"
#include "IWebSocket.h"

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
	if (UGameInstance* GI = GetGameInstance())
	{
		GI->GetTimerManager().ClearTimer(FocusTimer);
		GI->GetTimerManager().ClearTimer(ReconnectTimer);
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

		FlushOutboundQueue();

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
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("type"), TEXT("map_loaded"));
	O->SetStringField(TEXT("map"), MapTokenOrPackage);
	O->SetStringField(TEXT("mode"), ModeId);
	O->SetNumberField(TEXT("t"), FDateTime::UtcNow().ToUnixTimestamp());
	SendJsonObject(O);
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
