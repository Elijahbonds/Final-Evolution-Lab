// Copy into your game's Source/FinalEvolutionLab/ module — add WebSockets + Json to *.Build.cs.
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Engine/TimerHandle.h"
#include "FELCreatorCardTypes.h"
#include "FELVaultTypes.h"
#include "FELPartyTypes.h"
#include "FELVaultDatabase.h"

#include "FELBridgeSubsystem.generated.h"

class IWebSocket;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FFELWebSocketRawMessage, FString, Message);

/**
 * FELBridge backend bridge: outbound JSON (match scores, focus keepalive) over WebSocket.
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

	/** Emitted after a level finishes loading (see FELDeepLinkSubsystem). Sent over the FELBridge WebSocket when connected. */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void BroadcastMapLoaded(const FString& MapTokenOrPackage, const FString& ModeId);

	/** Rich session snapshot (PRQ, combo, arena id) after GameState is ready — called deferred from map load. */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void EmitVaultSessionSnapshot(UWorld* World);

	/** Deferred emit so GameState / arena id are populated after AFELBasketballGameMode::StartPlay. */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void ScheduleVaultSessionSnapshotDeferred(float DelaySeconds = 0.15f);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendSceneItBuzzToHub(const FString& RoundId, const FString& ClipId, const FString& PlayerId, double ClientMonotonicMs);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendSceneItAnswerToHub(const FString& RoundId, const FString& ClipId, const FString& PlayerId, bool bCorrect, int32 ChosenIndex, int32 EvolutionShardsAwarded, float DistorterResolveAtBuzz);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	bool TryQueryDraftActivations(int32 OptionalDraftYear, const FString& OptionalPathwaySubstring, int32 MaxRows, TArray<FFELDraftCardRow>& OutRows) const;

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	bool TryQueryVaultRecentSessions(int32 MaxRows, TArray<FFELVaultRow>& OutRows) const;

	UFUNCTION(BlueprintPure, Category = "FELBridge")
	bool TryGetLocalEvolutionShardTotal(int64& OutTotal) const;

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	bool InsertLocalDraftActivation(const FString& CardId, int32 DraftYear, const FString& Pathway, const FString& SerialId, const FString& SignatureHex, bool bCommissionerMint);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	bool AddLocalEvolutionShards(int32 Delta, const FString& Reason, const FString& RefMealId, bool bRecommendedPick);

	UFUNCTION(BlueprintPure, Category = "FELBridge")
	bool IsFullySecure() const;

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendFuelConciergeOrderToHub(const FString& MealIdOrdered, bool bOrderedRecommendedMeal, int32 Shards, int32 TrainingPhase, float PRQScore);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void GrantEvolutionShardsLocal(int32 Delta, const FString& Reason, const FString& RefMealId, bool bRecommendedPick);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SetCommissionerSessionActive(bool bActive);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendCommissionerMintVerifyToHub(const FString& CardId, const FString& SerialId, int32 DraftYear, const FString& PathwayStr);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendDraftOwnerCertifiedToHub(const FString& CardId, const FString& SerialId, int32 DraftYear, const FString& PathwayStr, bool bCommissionerOk);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendJukeboxHostToHub(const FString& EquippedDjCardId, const FString& ActiveSpotifyPlaylistId, const FString& MenuPlaylistId);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendDesignBlitzSubmitToHub(const FString& SessionId, int32 RoundIndex, const FString& JsonMetadataSnapshot);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendPartyBoardStateToHub(const FString& BoardId, int32 Phase, int32 SessionType, int32 ActivePlayerIndex, const TArray<FFELPartyPlayerSlot>& Players, const FString& PendingMinigameModeId, const FString& SubType);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void PersistDraftCardToVault(const FString& CardId, int32 DraftYear, const FString& PathwayStr, const FString& SerialId, const FString& Sig, bool bCommissionerOk);

	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void PersistMatchEndSample(const AFELBasketballGameState* GS);

	UPROPERTY(BlueprintReadOnly, Category = "FELBridge")
	bool bImuSensorReady = false;

	UPROPERTY(BlueprintReadOnly, Category = "FELBridge")
	bool bImuHudIntegrityOk = false;

	UPROPERTY(BlueprintReadOnly, Category = "FELBridge")
	bool bIsHardwareAuthenticated = false;

	UPROPERTY(BlueprintReadOnly, Category = "FELBridge")
	bool bMonotonicClockTrusted = false;

	UPROPERTY(BlueprintReadOnly, Category = "FELBridge")
	bool bIsCommissionerSessionActive = false;

	UPROPERTY(BlueprintReadWrite, Category = "FELBridge")
	float LastPlayerVertVelCm = 0.0f;

	/** Raw UTF-8 text frame from server (JSON or plain text per your backend). */
	UPROPERTY(BlueprintAssignable, Category = "FELBridge")
	FFELWebSocketRawMessage OnRawMessage;

private:
	void LoadBridgeDefaultsFromIni();

	/** Replace localhost in ws/wss URLs using FEL_VAULT_HOST, ini, or LAN candidate probes. */
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

	TUniquePtr<class FELVaultDatabase> VaultDb;
};
