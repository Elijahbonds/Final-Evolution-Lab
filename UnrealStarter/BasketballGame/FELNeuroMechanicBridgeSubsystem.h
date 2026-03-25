// Copyright (c) Final Evolution Lab.
// GameInstance subsystem: central entry for Swift-exported readiness → character + ball (NEURO_MECHANIC_BRIDGE.md).

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELArenaRulesTypes.h"
#include "FELGameModeDefinitions.h"
#include "FELReadinessTypes.h"
#include "TimerManager.h"
#include "FELNeuroMechanicBridgeSubsystem.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFELReadinessApplied, const FFELReadinessSnapshot&, Snapshot);

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnFELNeuroHUDStatsRefresh);

/**
 * Persists for the lifetime of the UGameInstance (survives level transitions).
 * Uses FELReadinessIO JSON keys (camelCase) and forwards to AFELBasketballCharacter::ApplyReadiness / AFELBasketballActor::ApplyReadiness.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELNeuroMechanicBridgeSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** Load readiness_snapshot.json (Documents/FEL on iOS, then Saved, then Content — see FELReadinessIO). Does not apply to pawns. */
	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	bool TryLoadSnapshot(FFELReadinessSnapshot& OutSnapshot, FString& OutError);

	/** Load snapshot from disk into cache only (no ApplyReadiness). Used by AFELBasketballGameMode::PostInitializeComponents before the match applies physics. */
	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	bool TryLoadSnapshotIntoCacheOnly(FString& OutError);

	/** Merged rules for `CachedSnapshot.ActiveArenaMode` + ArenaSettings.json (factory defaults when JSON missing). */
	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	void GetCurrentArenaSettings(FFELArenaRules& OutRules) const;

	/** Explicit mode query (e.g. Swift shell preview) — does not require cached snapshot. */
	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	void GetArenaSettingsForMode(EFELArenaMode Mode, FFELArenaRules& OutRules) const;

	/**
	 * Apply snapshot to player character (if FEL basketball pawn) and all AFELBasketballActor in the world. Updates cache and broadcasts OnReadinessApplied.
	 * When `bDeferActorApplyBecauseTravelQueued` is true (e.g. `ParseSnapshotJsonString` just issued `OpenLevel`), skips touching actors until the new map loads and `ReapplyCachedToCurrentWorld` / GameMode runs.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	void ApplyReadiness(const FFELReadinessSnapshot& Snapshot, bool bDeferActorApplyBecauseTravelQueued = false);

	/** TryLoadSnapshot from disk, then ApplyReadiness. Primary one-shot for GameMode BeginPlay or shell handoff. */
	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	bool ReloadSnapshotFromDiskAndApply(FString& OutError);

	/** Parse Swift/PRQ JSON string (same keys as file). Then ApplyReadiness. */
	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	bool ApplySnapshotFromJsonString(const FString& JsonString, FString& OutError);

	/**
	 * Brain Brawl / mental–physical link: add PRQ points for a limited time (quiz correct answer).
	 * Re-applies readiness; GameMode neuro fields stay in sync.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	void ApplyTemporaryPRQBoost(double DeltaPoints, float DurationSeconds);

	/** Brain Brawl boosts during InProgress match only (see AFELBasketballGameMode). */
	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	void SetBrainBrawlBoostCountingEnabled(bool bEnabled);

	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	void ResetBrainBrawlBoostCountForActivePhase();

	UFUNCTION(BlueprintPure, Category = "FEL|NeuroMechanic")
	int32 GetBrainBrawlBoostCountThisSession() const { return BrainBrawlBoostCountThisSession; }

	/** Re-apply CachedSnapshot after a new map loads (pawn/ball actors are respawned). */
	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	void ReapplyCachedToCurrentWorld();

	UFUNCTION(BlueprintPure, Category = "FEL|NeuroMechanic")
	bool HasCachedSnapshot() const { return bHasCachedSnapshot; }

	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	void GetCachedSnapshot(FFELReadinessSnapshot& OutSnapshot) const { OutSnapshot = CachedSnapshot; }

	/** If true, first game/PIE world init attempts ReloadSnapshotFromDiskAndApply when no cache exists yet (delayed so pawns/balls exist). Keep false when AFELBasketballGameMode calls ReloadSnapshotFromDiskAndApply (single disk read). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|NeuroMechanic")
	bool bAutoLoadFromDiskOnFirstWorldInit = false;

	/**
	 * If true, after OnPostWorldInitialization (0.08s delay) re-applies CachedSnapshot to pawns/balls.
	 * Disable when GameMode always calls ReloadSnapshotFromDiskAndApply after spawning (avoids a redundant apply on the same match start).
	 * Enable for OpenLevel / travel flows where StartPlay may not reload the file but actors respawned.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|NeuroMechanic")
	bool bReapplyCachedOnWorldInit = false;

	UPROPERTY(BlueprintAssignable, Category = "FEL|NeuroMechanic")
	FOnFELReadinessApplied OnReadinessApplied;

	/** Fired immediately after OnReadinessApplied (same frame) so debug HUD / tuning UI can refresh without parsing JSON again. */
	UPROPERTY(BlueprintAssignable, Category = "FEL|NeuroMechanic")
	FOnFELNeuroHUDStatsRefresh OnNeuroHUDStatsRefresh;

private:
	UPROPERTY()
	FFELReadinessSnapshot CachedSnapshot;

	bool bHasCachedSnapshot = false;
	FDelegateHandle WorldInitDelegateHandle;

	/** World for the pending delayed apply after PostWorldInitialization (pawns may not exist yet on the same frame). */
	TWeakObjectPtr<UWorld> PendingPostWorldInitWorld;

	FTimerHandle PostWorldInitApplyTimer;

	FTimerHandle PRQBoostResetTimerHandle;

	/** Sum of pending PRQ boost to remove when the timer fires (supports stacked boosts). */
	double PendingPRQBoostTotal = 0.0;

	/** Quiz correct answers while match is InProgress (Neuro-Performance / session_results). */
	int32 BrainBrawlBoostCountThisSession = 0;

	bool bBrainBrawlBoostCountingEnabled = false;

	void HandlePostWorldInit(UWorld* World, const UWorld::InitializationValues& IVS);
	void ExecuteDelayedPostWorldInitApply();
	void ApplyReadinessToActors(UWorld* World, const FFELReadinessSnapshot& Snapshot);

	void SyncAuthGameModeNeuroFromCache();

	UFUNCTION()
	void ExpirePendingPRQBoost();

	/** Dev-only: bound in Initialize to log + on-screen readout when readiness applies. */
	UFUNCTION()
	void OnReadinessAppliedDebugPIE(const FFELReadinessSnapshot& Snapshot);
};
