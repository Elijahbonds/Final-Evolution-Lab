// FELHudRelaySubsystem.cpp

#include "FELHudRelaySubsystem.h"
#include "FELBackendConfig.h"
#include "Dom/JsonObject.h"
#include "Policies/CondensedJsonPrintPolicy.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"
#include "TimerManager.h"
#include "WebSocketsModule.h"
#include "IWebSocket.h"

void UFELHudRelaySubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	if (!FModuleManager::Get().IsModuleLoaded("WebSockets"))
	{
		FModuleManager::Get().LoadModule("WebSockets");
	}
	CachedWsUrl = FELBackendConfig::ResolveHudWebSocketUrl();
}

void UFELHudRelaySubsystem::Deinitialize()
{
	bDeinitializing = true;
	if (UGameInstance* GI = GetGameInstance())
	{
		GI->GetTimerManager().ClearTimer(ReconnectTimer);
	}
	if (Socket.IsValid())
	{
		Socket->Close();
		Socket.Reset();
	}
	Super::Deinitialize();
}

bool UFELHudRelaySubsystem::IsConnected() const
{
	return Socket.IsValid() && Socket->IsConnected();
}

void UFELHudRelaySubsystem::EnsureConnected()
{
	if (CachedWsUrl.IsEmpty())
	{
		CachedWsUrl = FELBackendConfig::ResolveHudWebSocketUrl();
	}
	if (CachedWsUrl.IsEmpty() || IsConnected())
	{
		return;
	}
	if (Socket.IsValid())
	{
		return;
	}

	Socket = FWebSocketsModule::Get().CreateWebSocket(CachedWsUrl, FString());
	BindHandlers();
	Socket->Connect();
}

void UFELHudRelaySubsystem::BindHandlers()
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
		UE_LOG(LogTemp, Log, TEXT("[FEL HUD] relay connected (%s)"), *CachedWsUrl);
		FlushPending();
	});

	Socket->OnConnectionError().AddLambda([this](const FString& Err)
	{
		UE_LOG(LogTemp, Warning, TEXT("[FEL HUD] relay connection error: %s"), *Err);
		Socket.Reset();
		ScheduleReconnect();
	});

	Socket->OnClosed().AddLambda([this](int32 Code, const FString& Reason, bool /*bRemote*/)
	{
		UE_LOG(LogTemp, Verbose, TEXT("[FEL HUD] relay closed (%d): %s"), Code, *Reason);
		Socket.Reset();
		if (!bDeinitializing)
		{
			ScheduleReconnect();
		}
	});
}

void UFELHudRelaySubsystem::ScheduleReconnect()
{
	if (bDeinitializing || CachedWsUrl.IsEmpty() || ReconnectAttemptCount >= MaxReconnectAttempts)
	{
		return;
	}
	UGameInstance* GI = GetGameInstance();
	if (!GI)
	{
		return;
	}
	GI->GetTimerManager().SetTimer(
		ReconnectTimer,
		this,
		&UFELHudRelaySubsystem::AttemptReconnect,
		ReconnectDelaySeconds,
		false);
}

void UFELHudRelaySubsystem::AttemptReconnect()
{
	++ReconnectAttemptCount;
	EnsureConnected();
}

void UFELHudRelaySubsystem::FlushPending()
{
	if (!IsConnected())
	{
		return;
	}
	for (const FString& Pending : PendingOutboundMessages)
	{
		Socket->Send(Pending);
	}
	PendingOutboundMessages.Reset();
}

void UFELHudRelaySubsystem::SendRawJson(const FString& Json)
{
	if (!IsConnected())
	{
		if (PendingOutboundMessages.Num() >= MaxPendingOutbound)
		{
			PendingOutboundMessages.RemoveAt(0);
		}
		PendingOutboundMessages.Add(Json);
		return;
	}
	Socket->Send(Json);
}

void UFELHudRelaySubsystem::BroadcastMessage(const FString& MessageType, const FString& PayloadJson)
{
	EnsureConnected();

	TSharedPtr<FJsonObject> PayloadObject = MakeShared<FJsonObject>();
	if (!PayloadJson.IsEmpty())
	{
		TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(PayloadJson);
		TSharedPtr<FJsonObject> Parsed;
		if (FJsonSerializer::Deserialize(Reader, Parsed) && Parsed.IsValid())
		{
			PayloadObject = Parsed;
		}
	}

	TSharedPtr<FJsonObject> Frame = MakeShared<FJsonObject>();
	Frame->SetStringField(TEXT("type"), MessageType);
	Frame->SetStringField(TEXT("event"), MessageType);
	Frame->SetObjectField(TEXT("payload"), PayloadObject);

	FString Out;
	TSharedRef<TJsonWriter<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>> Writer =
		TJsonWriterFactory<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>::Create(&Out);
	FJsonSerializer::Serialize(Frame.ToSharedRef(), Writer);

	SendRawJson(Out);
	UE_LOG(LogTemp, Verbose, TEXT("[FEL HUD] sent frame type=%s"), *MessageType);
}
