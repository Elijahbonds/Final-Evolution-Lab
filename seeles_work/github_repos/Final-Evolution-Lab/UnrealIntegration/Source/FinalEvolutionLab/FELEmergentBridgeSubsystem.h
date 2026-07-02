// Copy into your game's Source/FinalEvolutionLab/ module — add WebSockets + Json to *.Build.cs.
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Engine/TimerHandle.h"

#include "FELBridgeSubsystem.generated.h"

class IWebSocket;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FFELWebSocketRawMessage, FString, Message);

/**
 * Emergent backend bridge: outbound JSON (match scores, focus keepalive) over WebSocket.
 *
 * Configure full URL (ws:// or wss:// + path + room id) via DefaultGame.ini [FELBridge] GameWebSocketUrl,
 * FEL_GAME_WS_URL env (overrides ini), or SetGameWebSocketUrl from Blueprint/C++.
 *
 * While disconnected, outbound payloads are queued and flushed after OnConnected (bounded queue).
 * Optional auto-reconnect after close/error. Inbound text frames are logged (Verbose) and broadcast on OnRawMessage.
 */
UCLASS()
class UFELBridgeSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** Full URL including path and room id, e.g. wss://tunnel.example.com/ws/game/my-room — empty disconnects and clears queue */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SetGameWebSocketUrl(const FString& FullWsUrl);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendMatchScoreToWebSocket(int32 ScoreA, int32 ScoreB, const FString& ExtraJsonFields);

	/** Sends JSON focus_keepalive every IntervalSeconds (default 0.5) when socket connected. */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SetFocusKeepaliveEnabled(bool bEnable, float IntervalSeconds = 0.5f);

	/** Emitted after a level finishes loading (see FELEmergentDeepLinkSubsystem). Sent over the Emergent WebSocket when connected. */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void BroadcastMapLoaded(const FString& MapTokenOrPackage, const FString& ModeId);

	/** Rich session snapshot (PRQ, combo, arena id) after GameState is ready — called deferred from map load. */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void EmitVaultSessionSnapshot(UWorld* World);

	/** Deferred emit so GameState / arena id are populated after AFELBasketballGameMode::StartPlay. */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void ScheduleVaultSessionSnapshotDeferred(float DelaySeconds = 0.15f);

	/** Raw UTF-8 text frame from server (JSON or plain text per your backend). */
	UPROPERTY(BlueprintAssignable, Category = "FELBridge")
	FFELWebSocketRawMessage OnRawMessage;

private:
	void LoadBridgeDefaultsFromIni();

	/** Replace localhost in ws/wss URLs using FEL_HUB_HOST, ini, or LAN candidate probes. */
	void ApplyDynamicHubResolution(FString& InOutUrl);
	bool FelProbeTcpHost(const FString& Host, int32 Port) const;
	/** Scan each private IPv4 adapter's /24 for an open TCP port (Vault / WS). */
	FString FelDiscoverHubViaSubnetScan(int32 Port) const;
	int32 FelExtractPortFromWsUrl(const FString& Url) const;

	void EnsureSocketCreated();
	void BindSocketHandlers();
	void SendJsonObject(const TSharedPtr<class FJsonObject>& Payload);
	void FlushOutboundQueue();
	void ScheduleReconnect();
	void AttemptReconnect();
	void HandleSocketClosedOrError();

	void TickFocusKeepalive();
	void TickVaultTelemetry();

	void TryStartVaultTelemetryTimer();
	void StopVaultTelemetryTimer();

	FString CachedWsUrl;
	TSharedPtr<IWebSocket> Socket;

	FString VaultHubHostIni;
	bool bProbeCandidateHosts = false;
	bool bScanLocalSubnet = true;
	TArray<FString> CandidateLanHosts;
	int32 DiscoveryPortOverride = 0;

	FTimerHandle FocusTimer;
	FTimerHandle ReconnectTimer;
	FTimerHandle VaultTelemetryTimer;
	FTimerHandle VaultDeferTimer;

	static constexpr float VaultTelemetryIntervalSeconds = 0.1f;

	bool bKeepaliveEnabled = false;
	float KeepaliveInterval = 0.5f;

	bool bAutoReconnect = true;
	float ReconnectDelaySeconds = 3.f;
	int32 MaxReconnectAttempts = 0;
	int32 ReconnectAttemptCount = 0;

	bool bDeinitializing = false;
	bool bVaultHandshakeLoggedThisMap = false;

	static constexpr int32 MaxPendingOutbound = 128;
	TArray<FString> PendingOutboundMessages;
};
