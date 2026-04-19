// Copy into your game's Source/FinalEvolutionLab/ module — add WebSockets + Json to *.Build.cs.
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Engine/TimerHandle.h"

#include "FELEmergentBridgeSubsystem.generated.h"

class IWebSocket;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FEmergentWebSocketRawMessage, FString, Message);

/**
 * Emergent backend bridge: outbound JSON (match scores, focus keepalive) over WebSocket.
 *
 * Configure full URL (ws:// or wss:// + path + room id) via DefaultGame.ini [Emergent] GameWebSocketUrl,
 * EMERGENT_GAME_WS_URL env (overrides ini), or SetGameWebSocketUrl from Blueprint/C++.
 *
 * While disconnected, outbound payloads are queued and flushed after OnConnected (bounded queue).
 * Optional auto-reconnect after close/error. Inbound text frames are logged (Verbose) and broadcast on OnEmergentRawMessage.
 */
UCLASS()
class UFELEmergentBridgeSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** Full URL including path and room id, e.g. wss://tunnel.example.com/ws/game/my-room — empty disconnects and clears queue */
	UFUNCTION(BlueprintCallable, Category = "Emergent")
	void SetGameWebSocketUrl(const FString& FullWsUrl);

	UFUNCTION(BlueprintCallable, Category = "Emergent")
	void SendMatchScoreToWebSocket(int32 ScoreA, int32 ScoreB, const FString& ExtraJsonFields);

	/** Sends JSON focus_keepalive every IntervalSeconds (default 0.5) when socket connected. */
	UFUNCTION(BlueprintCallable, Category = "Emergent")
	void SetFocusKeepaliveEnabled(bool bEnable, float IntervalSeconds = 0.5f);

	/** Emitted after a level finishes loading (see FELEmergentDeepLinkSubsystem). Sent over the Emergent WebSocket when connected. */
	UFUNCTION(BlueprintCallable, Category = "Emergent")
	void BroadcastMapLoaded(const FString& MapTokenOrPackage, const FString& ModeId);

	/** Rich session snapshot (PRQ, combo, arena id) after GameState is ready — called deferred from map load. */
	UFUNCTION(BlueprintCallable, Category = "Emergent")
	void EmitSovereignSessionSnapshot(UWorld* World);

	/** Deferred emit so GameState / arena id are populated after AFELBasketballGameMode::StartPlay. */
	UFUNCTION(BlueprintCallable, Category = "Emergent")
	void ScheduleSovereignSessionSnapshotDeferred(float DelaySeconds = 0.15f);

	/** Raw UTF-8 text frame from server (JSON or plain text per your backend). */
	UPROPERTY(BlueprintAssignable, Category = "Emergent")
	FEmergentWebSocketRawMessage OnEmergentRawMessage;

private:
	void LoadEmergentDefaultsFromIni();

	void EnsureSocketCreated();
	void BindSocketHandlers();
	void SendJsonObject(const TSharedPtr<class FJsonObject>& Payload);
	void FlushOutboundQueue();
	void ScheduleReconnect();
	void AttemptReconnect();
	void HandleSocketClosedOrError();

	void TickFocusKeepalive();
	void TickSovereignTelemetry();

	void TryStartSovereignTelemetryTimer();
	void StopSovereignTelemetryTimer();

	FString CachedWsUrl;
	TSharedPtr<IWebSocket> Socket;

	FTimerHandle FocusTimer;
	FTimerHandle ReconnectTimer;
	FTimerHandle SovereignTelemetryTimer;
	FTimerHandle SovereignDeferTimer;

	static constexpr float SovereignTelemetryIntervalSeconds = 0.1f;

	bool bKeepaliveEnabled = false;
	float KeepaliveInterval = 0.5f;

	bool bAutoReconnect = true;
	float ReconnectDelaySeconds = 3.f;
	int32 MaxReconnectAttempts = 0;
	int32 ReconnectAttemptCount = 0;

	bool bDeinitializing = false;
	bool bSovereignHandshakeLoggedThisMap = false;

	static constexpr int32 MaxPendingOutbound = 128;
	TArray<FString> PendingOutboundMessages;
};
