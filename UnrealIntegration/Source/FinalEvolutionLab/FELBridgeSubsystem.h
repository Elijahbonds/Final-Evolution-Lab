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

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FFELActiveVenueChangedSignature, FString, NewVenueToken, FString, NewModeId);

/**
 * FELBridge backend bridge: outbound JSON (match scores, focus keepalive) over WebSocket.
 *
 * Configure full URL (ws:// or wss:// + path) via DefaultGame.ini [FELBridge] GameWebSocketUrl,
 * FEL_GAME_WS_URL env (overrides ini), or SetGameWebSocketUrl from Blueprint/C++.
 *
 * Phase 1 backend: ws://host:8787/ws/vault (not /ws/game). Legacy sovereign hub accepts `type`;
 * Phase 1 vault channel reads `event`. SendJsonObject emits both fields (see ApplyDualVaultEnvelope).
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

	/**
	 * Configures and updates the WebSocket URL for the game hub connection.
	 * Passing an empty string will close any active connection and clear the outbound queue.
	 *
	 * @param FullWsUrl The full target WebSocket URL (e.g. ws://127.0.0.1:8888/ws/vault).
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SetGameWebSocketUrl(const FString& FullWsUrl);

	/**
	 * Sends the final match score payload to the WebSocket server.
	 *
	 * @param ScoreA The score of Team/Player A.
	 * @param ScoreB The score of Team/Player B.
	 * @param ExtraJsonFields Optional JSON string containing extra custom metadata fields.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendMatchScoreToWebSocket(int32 ScoreA, int32 ScoreB, const FString& ExtraJsonFields);

	/**
	 * Enables or disables focus keepalive heartbeats.
	 *
	 * @param bEnable If true, periodic keepalive frames will be transmitted when connected.
	 * @param IntervalSeconds The time interval in seconds between keepalive frames (clamped to >= 0.05s).
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SetFocusKeepaliveEnabled(bool bEnable, float IntervalSeconds = 0.5f);

	/**
	 * Broadcasts a map loaded notification event to the WebSocket server.
	 * Typically called by the DeepLinkSubsystem after traveling to a map.
	 *
	 * @param MapTokenOrPackage Logical map name token or the full package path.
	 * @param ModeId The game mode identifier associated with the map.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void BroadcastMapLoaded(const FString& MapTokenOrPackage, const FString& ModeId);

	/**
	 * Emits a rich session snapshot of current GameState values to the Vault.
	 *
	 * @param World The current game UWorld.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void EmitVaultSessionSnapshot(UWorld* World);

	/**
	 * Schedules a deferred session snapshot emit. Used during level load to ensure the GameState
	 * and game mode properties have fully initialized on the game thread.
	 *
	 * @param DelaySeconds The delay duration in seconds before the snapshot is emitted.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void ScheduleVaultSessionSnapshotDeferred(float DelaySeconds = 0.15f);

	/**
	 * Sends a SceneIt buzz event payload to the hub server.
	 *
	 * @param RoundId Unique identifier of the current round.
	 * @param ClipId The media clip identifier being played.
	 * @param PlayerId The player who buzzed.
	 * @param ClientMonotonicMs Client-side monotonic time in milliseconds when the buzz occurred.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendSceneItBuzzToHub(const FString& RoundId, const FString& ClipId, const FString& PlayerId, double ClientMonotonicMs);

	/**
	 * Submits a SceneIt answer validation payload to the hub server.
	 *
	 * @param RoundId Unique identifier of the current round.
	 * @param ClipId The media clip identifier being answered.
	 * @param PlayerId The player answering.
	 * @param bCorrect True if the chosen answer index is correct.
	 * @param ChosenIndex The zero-based index of the option chosen by the player.
	 * @param EvolutionShardsAwarded The number of economy shards earned for this answer.
	 * @param DistorterResolveAtBuzz The distorter resolving percentage at the moment of the buzz.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendSceneItAnswerToHub(const FString& RoundId, const FString& ClipId, const FString& PlayerId, bool bCorrect, int32 ChosenIndex, int32 EvolutionShardsAwarded, float DistorterResolveAtBuzz);

	/**
	 * Queries the local SQLite Vault database for draft activation records.
	 *
	 * @param OptionalDraftYear If > 0, filters records by the specific draft year.
	 * @param OptionalPathwaySubstring If not empty, filters records where the pathway contains this substring.
	 * @param MaxRows The maximum number of database rows to retrieve.
	 * @param OutRows Output array containing the matching draft card rows.
	 * @return True if the query completed successfully.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	bool TryQueryDraftActivations(int32 OptionalDraftYear, const FString& OptionalPathwaySubstring, int32 MaxRows, TArray<FFELDraftCardRow>& OutRows) const;

	/**
	 * Queries the local SQLite Vault database for recent session telemetry records.
	 *
	 * @param MaxRows The maximum number of database rows to retrieve.
	 * @param OutRows Output array containing the matching session records.
	 * @return True if the query completed successfully.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	bool TryQueryVaultRecentSessions(int32 MaxRows, TArray<FFELVaultRow>& OutRows) const;

	/**
	 * Sums the local SQLite ledger to calculate the current total Evolution Shards for the player.
	 *
	 * @param OutTotal Output variable for the calculated total shards sum.
	 * @return True if the sum was calculated successfully.
	 */
	UFUNCTION(BlueprintPure, Category = "FELBridge")
	bool TryGetLocalEvolutionShardTotal(int64& OutTotal) const;

	/**
	 * Inserts a draft activation entry into the local SQLite database.
	 *
	 * @param CardId The unique identifier of the draft card.
	 * @param DraftYear The draft class year.
	 * @param Pathway The developmental pathway associated with the card.
	 * @param SerialId The individual serial number of the card.
	 * @param SignatureHex Cryptographic verification signature in hexadecimal.
	 * @param bCommissionerMint True if minted directly under commissioner authorization.
	 * @return True if the insert succeeded.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	bool InsertLocalDraftActivation(const FString& CardId, int32 DraftYear, const FString& Pathway, const FString& SerialId, const FString& SignatureHex, bool bCommissionerMint);

	/**
	 * Adds an Evolution Shard transaction ledger entry to the local SQLite database.
	 *
	 * @param Delta The positive or negative shard change value.
	 * @param Reason Description / source of the transaction.
	 * @param RefMealId Optional associated bio-fuel meal identifier.
	 * @param bRecommendedPick True if the action matched a recommended plan choice.
	 * @return True if the entry was written successfully.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	bool AddLocalEvolutionShards(int32 Delta, const FString& Reason, const FString& RefMealId, bool bRecommendedPick);

	/**
	 * Checks if the local player and client environment meet all security and clock integrity standards.
	 *
	 * @return True if IMU, clock, and hardware authentication gates pass.
	 */
	UFUNCTION(BlueprintPure, Category = "FELBridge")
	bool IsFullySecure() const;

	/**
	 * Dispatches a biofuel concierge meal order payload to the hub server.
	 *
	 * @param MealIdOrdered The identifier of the meal.
	 * @param bOrderedRecommendedMeal True if the user selected a recommended recipe choice.
	 * @param Shards Shards awarded for completing the fueling target.
	 * @param TrainingPhase Current progression phase of the user's plan.
	 * @param PRQScore Current Performance Readiness Quotient.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendFuelConciergeOrderToHub(const FString& MealIdOrdered, bool bOrderedRecommendedMeal, int32 Shards, int32 TrainingPhase, float PRQScore);

	/**
	 * Local helper wrapper to add shards locally.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void GrantEvolutionShardsLocal(int32 Delta, const FString& Reason, const FString& RefMealId, bool bRecommendedPick);

	/**
	 * Toggles the commissioner session state.
	 *
	 * @param bActive True if the active session is commissioner-managed.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SetCommissionerSessionActive(bool bActive);

	/**
	 * Sends a verification request for a commissioner-minted card to the hub.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendCommissionerMintVerifyToHub(const FString& CardId, const FString& SerialId, int32 DraftYear, const FString& PathwayStr);

	/**
	 * Submits a draft certification payload to the hub.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendDraftOwnerCertifiedToHub(const FString& CardId, const FString& SerialId, int32 DraftYear, const FString& PathwayStr, bool bCommissionerOk);

	/**
	 * Syncs the active Jukebox music host configuration to the hub.
	 *
	 * @param EquippedDjCardId The active DJ character card.
	 * @param ActiveSpotifyPlaylistId User's current Spotify playlist.
	 * @param MenuPlaylistId Default tracklist identifier.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendJukeboxHostToHub(const FString& EquippedDjCardId, const FString& ActiveSpotifyPlaylistId, const FString& MenuPlaylistId);

	/**
	 * Submits a design blitz creation metadata snapshot to the hub.
	 *
	 * @param SessionId Active customization session ID.
	 * @param RoundIndex Current editing round index.
	 * @param JsonMetadataSnapshot Serialized custom styles/skins JSON payload.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendDesignBlitzSubmitToHub(const FString& SessionId, int32 RoundIndex, const FString& JsonMetadataSnapshot);

	/**
	 * Synchronizes the local party board state to all connected hub clients.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void SendPartyBoardStateToHub(const FString& BoardId, int32 Phase, int32 SessionType, int32 ActivePlayerIndex, const TArray<FFELPartyPlayerSlot>& Players, const FString& PendingMinigameModeId, const FString& SubType);

	/**
	 * Writes a draft card to the local SQLite database.
	 */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void PersistDraftCardToVault(const FString& CardId, int32 DraftYear, const FString& PathwayStr, const FString& SerialId, const FString& Sig, bool bCommissionerOk);

	/**
	 * Helper function to dump the match end telemetry statistics to the local SQLite database.
	 *
	 * @param GS The active GameState containing scores and duration.
	 */
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

	/** Broadcasts when the player transitions between training environments on the unified map. */
	UPROPERTY(BlueprintAssignable, Category = "FELBridge")
	FFELActiveVenueChangedSignature OnActiveVenueChanged;

	/** Called by venue trigger volumes to initiate mode/UI travel transitions. */
	UFUNCTION(BlueprintCallable, Category = "FELBridge")
	void NotifyVenueTravel(const FString& VenueToken, const FString& ModeId);

	UFUNCTION(BlueprintPure, Category = "FELBridge")
	FString GetActiveVenueToken() const { return ActiveVenueToken; }

	UFUNCTION(BlueprintPure, Category = "FELBridge")
	FString GetActiveArenaGameModeId() const { return ActiveArenaGameModeId; }

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

	FString ActiveVenueToken;
	FString ActiveArenaGameModeId;

	static constexpr int32 MaxPendingOutbound = 128;
	TArray<FString> PendingOutboundMessages;

	TUniquePtr<class FELVaultDatabase> VaultDb;
};
