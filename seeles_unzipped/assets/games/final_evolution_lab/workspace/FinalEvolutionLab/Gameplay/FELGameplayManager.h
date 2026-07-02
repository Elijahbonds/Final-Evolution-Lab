// FELGameplayManager.h
// Phase 7 — Gameplay Logic for all 19 FEL modes
// Phase 9 QA fix: EFELOutcome + FFELSessionResult moved to FELTypes.h (no more duplicate definitions)
#pragma once
#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELTypes.h"                            // ← canonical enum + struct (Phase 9 fix)
#include "FELGameplayManager.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFELGameplayManager : public UGameInstanceSubsystem {
    GENERATED_BODY()
public:
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;

    // Called when a match ends for any mode
    UFUNCTION(BlueprintCallable, Category="FEL|Gameplay")
    void OnMatchEnd(const FString& ModeId, float PlayerScore, float OpponentScore,
                    float MRIScore, float ARV, float ESI, float PacingScore);

    // Compute P1 economy rewards for a match result
    UFUNCTION(BlueprintPure, Category="FEL|Economy")
    FFELSessionResult ComputeSessionResult(const FString& ModeId, EFELMatchOutcome Outcome,
                                           float MRIScore, float ARV, float ESI, float PacingScore);

    // Dispatch session receipt to FastAPI backend
    UFUNCTION(BlueprintCallable, Category="FEL|Backend")
    void DispatchSessionReceipt(const FFELSessionResult& Result);

    // ── Production mode evaluators (14) ──────────────────────────────────────
    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateBasketballOutcome(float PlayerScore, float OpponentScore);

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateKarateOutcome(float PlayerHP, float OpponentHP, bool bTimeExpired);

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateBaseballOutcome(int32 PlayerRuns, int32 OpponentRuns, int32 Inning);

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateFootballOutcome(int32 PlayerTDs, int32 OpponentTDs);

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateSoccerOutcome(int32 PlayerGoals, int32 OpponentGoals);

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateGolfOutcome(int32 PlayerStrokes, int32 ParStrokes);

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateTennisOutcome(int32 PlayerSets, int32 OpponentSets);

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateVolleyballOutcome(int32 PlayerPoints, int32 OpponentPoints);

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateSurfingOutcome(float PlayerScore, float TopScoreThreshold);

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateGymnasticsOutcome(float JudgeScore, float GoldThreshold);

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateBrainBrawlOutcome(int32 PlayerCorrect, int32 OpponentCorrect);

    // ── Staging / Preview / Non-game evaluators (5) ──────────────────────────
    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateSkateboardingOutcome(int32 Score, int32 OpponentScore) const;

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateSnowboardingOutcome(int32 Score, int32 OpponentScore) const;

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateWhoSceneItOutcome(int32 Score, int32 OpponentScore) const;

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateCourtCarnivalOutcome(int32 Score, int32 OpponentScore) const;

    UFUNCTION(BlueprintPure, Category="FEL|Gameplay")
    EFELMatchOutcome EvaluateMarketBrowseOutcome(int32 Score, int32 OpponentScore) const;

private:
    // P1 Economy constants (source-of-truth: backend/core.py mirrors these)
    static constexpr float PRQ_WIN  = 2.0f;
    static constexpr float PRQ_DRAW = 0.5f;
    static constexpr float PRQ_LOSS = 0.2f;
    static constexpr int32 SHARD_WIN  = 50;
    static constexpr int32 SHARD_DRAW = 25;
    static constexpr int32 SHARD_LOSS = 15;
    static constexpr int32 XP_CAP    = 500;

    // All 19 modes registered (market_browse=0 → no economy payout)
    TMap<FString, float> ModeWeights = {
        // Production (14)
        {"football",1.5f},{"karate_h2h",1.4f},{"karate_endless",1.4f},
        {"basketball_3v3",1.3f},{"basketball_h2h",1.2f},{"volleyball",1.2f},
        {"soccer",1.1f},{"tennis",1.1f},{"surfing",1.05f},
        {"basketball_dunk",1.0f},{"baseball",1.0f},{"gymnastics",1.0f},
        {"brain_brawl",1.0f},{"golf",0.9f},
        // Staging / Preview / Non-game (5)
        {"who_scene_it",1.1f},{"court_carnival",1.0f},
        {"skateboarding",0.9f},{"snowboarding",0.9f},
        {"market_browse",0.0f}
    };

    float GetModeWeight(const FString& ModeId) const;
    int32 ComputeXP(EFELMatchOutcome Outcome, float MRIScore, float Weight) const;
    int32 ComputeShards(EFELMatchOutcome Outcome, float PacingScore) const;
    float ComputePRQDelta(EFELMatchOutcome Outcome, float MRIScore, float Weight) const;
};
