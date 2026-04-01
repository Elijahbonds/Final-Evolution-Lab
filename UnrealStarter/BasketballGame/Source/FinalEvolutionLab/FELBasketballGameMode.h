// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaRulesTypes.h"
#include "FELArenaModeDefinitions.h"
#include "FELBasketballModes.h"
#include "FELGameModeDefinitions.h"
#include "FELReadinessTypes.h"
#include "FELMatchTypes.h"
#include "FELQuizWidget.h"
#include "FELOnboardingWidget.h"
#include "FELMatchResultsWidget.h"
#include "FELBiometricTypes.h"
#include "FELLabGameMode.h"
#include "UFELArenaModeData.h"
#include "UFELDemoManager.h"
#include "Engine/StreamableManager.h"
#include "Templates/SharedPointer.h"
#include "FELBasketballGameMode.generated.h"

class AFELBasketballActor;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFELMatchComplete, FFELMatchResultSummary, Result);

/**
 * All modes share the same pawn, ball, HUD, and hoop volumes; rules differ via GameState.
 */
UCLASS()
class FINALEVOLUTIONLAB_API AFELBasketballGameMode : public AFELLabGameMode
{
	GENERATED_BODY()

public:
	AFELBasketballGameMode();

	/** 12-mode manager: from `readiness_snapshot.json` → `active_mode` + `ArenaSettings.json`. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Arena")
	EFELArenaMode CurrentMode = EFELArenaMode::BasketballHeadToHead;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Arena")
	FFELArenaRules CurrentArenaRules;

	/** Async-loaded Primary Data Asset for CurrentMode (null until load or if asset missing). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Arena")
	TObjectPtr<UFELArenaModeData> LoadedArenaModeData = nullptr;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Demonstration")
	TObjectPtr<UFELDemoManager> DemoManager = nullptr;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Mode")
	EFELBasketballPlayMode PlayMode = EFELBasketballPlayMode::StreetBall;

	/** Used when PlayMode == TimedBlitz. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Mode", meta = (ClampMin = "5", UIMin = "5"))
	float TimedBlitzSeconds = 120.f;

	/** Used when PlayMode == HalfCourtShootout. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Mode", meta = (ClampMin = "1", UIMin = "1"))
	int32 ShootoutTargetBuckets = 11;

	/** Used when PlayMode == FirstToTwentyOne (override if you duplicate mode in Blueprint). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Mode", meta = (ClampMin = "1", UIMin = "1"))
	int32 FirstToNTargetBuckets = 21;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL")
	TSubclassOf<AFELBasketballActor> BallClass;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL")
	FVector BallSpawnOffset = FVector(120.f, 0.f, 40.f);

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL")
	FVector SecondBallSpawnOffset = FVector(120.f, 140.f, 40.f);

	/** Optional WBP subclass of UFELQuizWidget; defaults to native C++ layout. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|BrainBrawl")
	TSubclassOf<UFELQuizWidget> BrainBrawlQuizWidgetClass;

	/** First Lab visit: dismiss writes lab_onboarding_completed.flag (PROJECT_FLOWS). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Onboarding")
	TSubclassOf<UFELOnboardingWidget> LabOnboardingWidgetClass;

	/** Victory / Bonds Bounce screen; optional WBP subclass of UFELMatchResultsWidget. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Match")
	TSubclassOf<UFELMatchResultsWidget> MatchResultsWidgetClass;

	/** Get Ready countdown before InProgress (seconds). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Match", meta = (ClampMin = "0", UIMin = "0"))
	float CountdownToStartSeconds = 3.f;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Match")
	EFELMatchPhase MatchPhase = EFELMatchPhase::WaitingToStart;

	/** Fired when GameState reports match end; includes Shards/XP/neuro summary. */
	UPROPERTY(BlueprintAssignable, Category = "FEL|Match")
	FOnFELMatchComplete OnMatchComplete;

	/** Canonical arena mode id string for session export / HUD (matches readiness active_mode). */
	UFUNCTION(BlueprintCallable, Category = "FEL")
	FString GetArenaGameModeId() const;

	/** Mirror subsystem cache into Blueprint-readable Neuro* (call after hot-reload or external ApplyReadiness). */
	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	void SyncNeuroFieldsFromSnapshot(const FFELReadinessSnapshot& Snap);

	/** C++ / demo: read cached PRQ without friending subsystems. */
	UFUNCTION(BlueprintPure, Category = "FEL|NeuroMechanic")
	float GetNeuroPRQScoreFloat() const { return static_cast<float>(NeuroPRQScore); }

	UFUNCTION(BlueprintPure, Category = "FEL|NeuroMechanic")
	float GetNeuroKineticLeakageMultiplierFloat() const { return static_cast<float>(NeuroKineticLeakageMultiplier); }

	/** Re-run after hot-reload or shell push (PIE): re-apply GameState rules from snapshot + registry. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Arena")
	void RefreshArenaConfigurationFromSnapshot(const FFELReadinessSnapshot& Snap);

	/** Bio-Sync / readiness handoff: async warm-up Digital Twin mesh + active venue (`UFELAssetRegistrySubsystem`). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Arena|Assets")
	void WarmUp3DAssets();

	/**
	 * Street / Practice (no automatic match end): write `last_session_result.json` from current score + duration.
	 * Exceeds QA_GAMEPLAY_AUDIT §6 S3 — bind from pause menu or console for retail QA.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Match|Export")
	bool ExportOpenPlaySessionToDisk(FString& OutError);

	/** UFELQuizWidget calls this when the timed parallel-path duel completes (EndMatch + results flow). */
	UFUNCTION(BlueprintCallable, Category = "FEL|BrainBrawl|Academy")
	void NotifyBrainBrawlAcademyDuelComplete();

	/** Ghost "Perfect Form" demonstrator while WaitingToStart (onboarding Watch Demo). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Demonstration")
	void TriggerExerciseDemo();

	/** Blend camera back to pawn and destroy demonstrator (call from onboarding dismiss). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Demonstration")
	void EndExerciseDemoIfActive();

	virtual void Tick(float DeltaSeconds) override;

	virtual void PostInitializeComponents() override;

	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	virtual void RestartPlayer(AController* NewPlayer) override;

	/** Called from UFELGameInstance after retail splash/menu Play — begins onboarding / countdown. */
	void OnRetailStartupFlowComplete();

protected:
	virtual void BeginPlay() override;

	virtual void StartPlay() override;

	/** Load readiness (cache only), parse `active_mode`, merge factory + ArenaSettings.json + async UFELArenaModeData. */
	void ConfigureArenaFromReadinessSnapshot(const FFELReadinessSnapshot& Snap);

	/** Data-driven hooks — override in Blueprint GameMode or C++ subclass. */
	UFUNCTION(BlueprintNativeEvent, Category = "FEL|Arena")
	void OnBrainBrawlModeActivated();

	UFUNCTION(BlueprintNativeEvent, Category = "FEL|Arena")
	void OnDunkContestModeActivated();

	void SpawnMatchBallAtOffset(const FVector& OffsetFromPlayerStart);
	void ApplyModeToGameState();
	/** Presentation hooks (quiz / dunk announce): only when PreviousMode != CurrentMode (avoids duplicate quiz on R reload). StartPlay passes Unknown so first activation still fires. */
	void ApplyModeSpecificBehaviors(EFELArenaMode PreviousMode);
	void LockPlayerInputIfMatchEnded();

	void MaybeStartMatchFlow();
	void StartMatchCountdown();
	void EnterMatchInProgressPhase();
	void BindGameStateMatchDelegate();

	UFUNCTION()
	void HandleGameStateMatchEnded();

	UFUNCTION()
	void OnLabOnboardingDismissed();

	FFELMatchResultSummary BuildMatchResultSummary() const;

	void ShowMatchResultsWidget(const FFELMatchResultSummary& Summary);

	/** Last snapshot from UFELNeuroMechanicBridgeSubsystem after StartPlay (single source of truth). */
	FFELReadinessSnapshot LoadedReadiness;

	/** Last snapshot passed to ConfigureArenaFromReadinessSnapshot — used to apply Karate sub-mode after async DA load. */
	FFELReadinessSnapshot PendingArenaConfigureSnap;

	bool bLockedInputOnMatchEnd = false;

	bool bMatchCompletionHandled = false;

	FTimerHandle MatchStartCountdownTimer;

	/** Loads only the active mode Data Asset + dependencies (M4-friendly). */
	FStreamableManager ArenaModeStreamableManager;
	TSharedPtr<FStreamableHandle> ArenaModeLoadHandle;

	void ApplyArenaRulesFromFactorySync();
	void ApplyKarateLabModeFromPendingSnap();
	void RequestArenaModeDataAsync();
	void OnArenaModeDataLoaded();
	void BroadcastBiometricToWorld();
	FFELBiometricContext BuildBiometricContext() const;

	/** Neuro-Mechanic globals for Blueprint/HUD (mirrors last loaded snapshot). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|NeuroMechanic")
	double NeuroVerticalEstimateInches = 0.0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|NeuroMechanic")
	double NeuroHangTimeScale = 1.0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|NeuroMechanic")
	double NeuroKineticLeakageMultiplier = 1.0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|NeuroMechanic")
	double NeuroPRQScore = 75.0;

	/** SFMA rotation screen — mirrored from `readiness_snapshot.json` → fascial congestion in Lab. */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|NeuroMechanic|SFMA")
	bool NeuroSFMA_SpiralRotationPass = true;
};
