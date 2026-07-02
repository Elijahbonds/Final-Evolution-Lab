// FELGameModeBase.h — Final Evolution Lab
// All 19 game mode subclasses. UTF-8 no-BOM. Module: FINALEVOLUTIONLAB_API
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "FELTypes.h"
#include "FELGameModeBase.generated.h"


UCLASS(Abstract)
class FINALEVOLUTIONLAB_API AFELGameModeBase : public AGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameModeBase();

    UPROPERTY(EditDefaultsOnly, BlueprintReadWrite, Category="FEL|Match")
    bool bScoringEnabled = true;

    UPROPERTY(EditDefaultsOnly, BlueprintReadWrite, Category="FEL|Match")
    float DefaultMatchDuration = 300.0f;

    UPROPERTY(BlueprintReadOnly, Category="FEL|Match")
    float ElapsedTime = 0.f;

    UPROPERTY(BlueprintReadOnly, Category="FEL|Match")
    bool bMatchActive = false;

    UFUNCTION(BlueprintCallable, Category="FEL|Match")
    virtual void StartMatch();

    UFUNCTION(BlueprintCallable, Category="FEL|Match")
    virtual void EndMatch(EFELMatchOutcome Outcome);

    UFUNCTION(BlueprintNativeEvent, Category="FEL|Match")
    FFELSessionResult BuildSessionResult(EFELMatchOutcome Outcome);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome);

    virtual void Tick(float DeltaTime) override;

protected:
    FTimerHandle MatchTimerHandle;
    float MatchStartTime = 0.f;
};

// ─────────────────────────────────────────
//  PRODUCTION MODES (14)
// ─────────────────────────────────────────

// MAP: /Game/FEL/Maps/MAP_VeniceBeach — H2H street basketball
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_BasketballH2H : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_BasketballH2H();
    UPROPERTY(BlueprintReadWrite, Category="FEL|Basketball") int32 PlayerScore = 0;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Basketball") int32 OpponentScore = 0;
    UPROPERTY(EditDefaultsOnly, Category="FEL|Basketball") int32 TargetScore = 21;
    UFUNCTION(BlueprintCallable) void OnBasketScored(bool bByPlayer, int32 Points);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_VeniceBeach — solo dunk contest
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_BasketballDunk : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_BasketballDunk();
    UPROPERTY(BlueprintReadWrite, Category="FEL|Dunk") float JudgeScore = 0.f;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Dunk") int32 AttemptsRemaining = 3;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Dunk") float BestDunkScore = 0.f;
    UFUNCTION(BlueprintCallable) void OnDunkAttempt(float TrickScore, bool bCleanLanding);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_VeniceBeach — 3v3 possession/team
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_Basketball3V3 : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_Basketball3V3();
    UPROPERTY(BlueprintReadWrite) int32 TeamScore = 0;
    UPROPERTY(BlueprintReadWrite) int32 OpponentTeamScore = 0;
    UPROPERTY(EditDefaultsOnly) int32 TargetScore = 21;
    UPROPERTY(BlueprintReadWrite) int32 Assists = 0;
    UFUNCTION(BlueprintCallable) void OnTeamScore(bool bPlayerTeam, int32 Points);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_ZenDojo — karate H2H strike/block
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_KarateH2H : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_KarateH2H();
    UPROPERTY(BlueprintReadWrite) float PlayerHP = 100.f;
    UPROPERTY(BlueprintReadWrite) float OpponentHP = 100.f;
    UPROPERTY(BlueprintReadWrite) int32 HitsLanded = 0;
    UPROPERTY(BlueprintReadWrite) int32 HitsBlocked = 0;
    UFUNCTION(BlueprintCallable) void OnStrike(bool bByPlayer, float Damage, bool bBlocked);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_ZenDojo — endless survival waves
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_KarateEndless : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_KarateEndless();
    UPROPERTY(BlueprintReadWrite) int32 WaveNumber = 1;
    UPROPERTY(BlueprintReadWrite) float PlayerHP = 100.f;
    UPROPERTY(BlueprintReadWrite) int32 EnemiesDefeated = 0;
    UFUNCTION(BlueprintCallable) void OnWaveComplete();
    UFUNCTION(BlueprintCallable) void OnPlayerDeath();
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_BaseballPark — pitch/swing timing
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_Baseball : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_Baseball();
    UPROPERTY(BlueprintReadWrite) int32 Inning = 1;
    UPROPERTY(BlueprintReadWrite) int32 Outs = 0;
    UPROPERTY(BlueprintReadWrite) int32 PlayerRuns = 0;
    UPROPERTY(BlueprintReadWrite) int32 OpponentRuns = 0;
    UPROPERTY(BlueprintReadWrite) float ContactQuality = 0.f;
    UFUNCTION(BlueprintCallable) void OnSwing(float TimingAccuracy);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_GridironStadium — route/target challenge
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_Football : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_Football();
    UPROPERTY(BlueprintReadWrite) int32 PlayerScore = 0;
    UPROPERTY(BlueprintReadWrite) int32 OpponentScore = 0;
    UPROPERTY(BlueprintReadWrite) int32 CompletedPasses = 0;
    UPROPERTY(BlueprintReadWrite) int32 YardsGained = 0;
    UFUNCTION(BlueprintCallable) void OnTouchdown(bool bByPlayer);
    UFUNCTION(BlueprintCallable) void OnPassComplete(int32 Yards);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_SoccerStadium — dribble/pass/shoot
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_Soccer : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_Soccer();
    UPROPERTY(BlueprintReadWrite) int32 PlayerGoals = 0;
    UPROPERTY(BlueprintReadWrite) int32 OpponentGoals = 0;
    UPROPERTY(BlueprintReadWrite) int32 Assists = 0;
    UPROPERTY(BlueprintReadWrite) int32 Shots = 0;
    UFUNCTION(BlueprintCallable) void OnGoal(bool bByPlayer);
    UFUNCTION(BlueprintCallable) void OnShot(bool bOnTarget);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_LinksGolfCourse — aim/power/accuracy
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_Golf : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_Golf();
    UPROPERTY(EditDefaultsOnly) int32 TotalHoles = 9;
    UPROPERTY(BlueprintReadWrite) int32 CurrentHole = 1;
    UPROPERTY(BlueprintReadWrite) int32 TotalStrokes = 0;
    UPROPERTY(BlueprintReadWrite) int32 ParTotal = 0;
    UPROPERTY(BlueprintReadWrite) int32 StrokesThisHole = 0;
    UFUNCTION(BlueprintCallable) void OnStroke(float PowerPct, float AccuracyPct, float DistanceToPin);
    UFUNCTION(BlueprintCallable) void OnHoleComplete(int32 Par);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_TennisCourt — serve/rally/target
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_Tennis : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_Tennis();
    UPROPERTY(BlueprintReadWrite) int32 PlayerSets = 0;
    UPROPERTY(BlueprintReadWrite) int32 OpponentSets = 0;
    UPROPERTY(BlueprintReadWrite) int32 PlayerGames = 0;
    UPROPERTY(BlueprintReadWrite) int32 OpponentGames = 0;
    UPROPERTY(BlueprintReadWrite) int32 RallyLength = 0;
    UPROPERTY(BlueprintReadWrite) int32 Aces = 0;
    UFUNCTION(BlueprintCallable) void OnPointWon(bool bByPlayer, bool bAce);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_SandCourt — serve/bump/set/spike
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_Volleyball : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_Volleyball();
    UPROPERTY(BlueprintReadWrite) int32 PlayerPoints = 0;
    UPROPERTY(BlueprintReadWrite) int32 OpponentPoints = 0;
    UPROPERTY(EditDefaultsOnly) int32 PointsToWinSet = 25;
    UPROPERTY(BlueprintReadWrite) int32 Spikes = 0;
    UPROPERTY(BlueprintReadWrite) int32 Blocks = 0;
    UFUNCTION(BlueprintCallable) void OnSpike(bool bSuccess);
    UFUNCTION(BlueprintCallable) void OnPoint(bool bByPlayer);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_VeniceBeachSurf — balance/line/wave
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_Surfing : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_Surfing();
    static constexpr float GOLD_THRESHOLD = 75.0f;
    UPROPERTY(BlueprintReadWrite) float BalanceScore = 0.f;
    UPROPERTY(BlueprintReadWrite) float LineScore = 0.f;
    UPROPERTY(BlueprintReadWrite) float TrickBonus = 0.f;
    UPROPERTY(BlueprintReadWrite) int32 WavesRidden = 0;
    UPROPERTY(BlueprintReadWrite) int32 WipedOut = 0;
    UFUNCTION(BlueprintCallable) void OnWaveRidden(float BalanceQuality, float LineQuality, float TrickScore);
    UFUNCTION(BlueprintCallable) void OnWipeout();
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_TrainingFloor — routine/timing/form
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_Gymnastics : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_Gymnastics();
    static constexpr float GOLD_THRESHOLD = 85.0f;
    UPROPERTY(BlueprintReadWrite) float DifficultyScore = 0.f;
    UPROPERTY(BlueprintReadWrite) float ExecutionScore = 0.f;
    UPROPERTY(BlueprintReadWrite) float ArtistryScore = 0.f;
    UPROPERTY(BlueprintReadWrite) int32 ElementsCompleted = 0;
    UPROPERTY(BlueprintReadWrite) int32 Deductions = 0;
    UFUNCTION(BlueprintCallable) void OnElementCompleted(float Difficulty, float Execution);
    UFUNCTION(BlueprintCallable) void OnDeduction(float Value);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_NeuroArena — cognitive Q&A with streak
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_BrainBrawl : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_BrainBrawl();
    UPROPERTY(EditDefaultsOnly) float QuestionTimeLimit = 15.0f;
    UPROPERTY(EditDefaultsOnly) int32 StreakBonusThreshold = 3;
    UPROPERTY(BlueprintReadWrite) float CognitiveScore = 0.f;
    UPROPERTY(BlueprintReadWrite) int32 CorrectAnswers = 0;
    UPROPERTY(BlueprintReadWrite) int32 QuestionsAttempted = 0;
    UPROPERTY(BlueprintReadWrite) int32 CurrentStreak = 0;
    UPROPERTY(BlueprintReadWrite) int32 PeakStreak = 0;
    UPROPERTY(BlueprintReadWrite) float StreakMultiplier = 1.0f;
    UPROPERTY(BlueprintReadWrite) FString CurrentCategory;
    // CorrectIndex is ALWAYS -1 on client. Server-authoritative at POST /games/brainstorm/verify
    static constexpr int32 CLIENT_CORRECT_INDEX = -1;
    UFUNCTION(BlueprintCallable) void OnAnswerSubmitted(int32 AnswerIndex, float ResponseTimeSeconds);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// ─────────────────────────────────────────
//  STAGING MODES (2)
// ─────────────────────────────────────────

// MAP: /Game/FEL/Maps/MAP_SkatePark — line/trick/combo/landing
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_Skateboarding : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_Skateboarding();
    UPROPERTY(BlueprintReadWrite) float TrickScore = 0.f;
    UPROPERTY(BlueprintReadWrite) int32 ComboMultiplier = 1;
    UPROPERTY(BlueprintReadWrite) int32 TricksLanded = 0;
    UPROPERTY(BlueprintReadWrite) int32 TricksBailed = 0;
    UFUNCTION(BlueprintCallable) void OnTrickLanded(float Difficulty, int32 Combo);
    UFUNCTION(BlueprintCallable) void OnBail();
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_MountainSlope — slope/turn/trick/landing
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_Snowboarding : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_Snowboarding();
    UPROPERTY(BlueprintReadWrite) float RunScore = 0.f;
    UPROPERTY(BlueprintReadWrite) float TopSpeed = 0.f;
    UPROPERTY(BlueprintReadWrite) int32 GatesHit = 0;
    UPROPERTY(BlueprintReadWrite) int32 AirTricks = 0;
    UFUNCTION(BlueprintCallable) void OnGateCleared(bool bClean);
    UFUNCTION(BlueprintCallable) void OnAirTrick(float Score);
    UFUNCTION(BlueprintCallable) void OnRunComplete(float TotalTime);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// ─────────────────────────────────────────
//  PREVIEW MODES (2)  →  Promoted to production after Gate 1 fix
// ─────────────────────────────────────────

// MAP: /Game/FEL/Maps/MAP_NeuroArena — media/recognition/quiz
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_WhoSceneIt : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_WhoSceneIt();
    UPROPERTY(EditDefaultsOnly) float RoundTimeLimit = 20.0f;
    UPROPERTY(BlueprintReadWrite) int32 RoundsPlayed = 0;
    UPROPERTY(BlueprintReadWrite) int32 CorrectIdentifications = 0;
    UPROPERTY(BlueprintReadWrite) float AccuracyPct = 0.f;
    UPROPERTY(BlueprintReadWrite) float SpeedBonus = 0.f;
    UFUNCTION(BlueprintCallable) void OnMediaPresented(const FString& MediaId);
    UFUNCTION(BlueprintCallable) void OnIdentificationSubmitted(const FString& AnswerId, float ResponseTime);
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// MAP: /Game/FEL/Maps/MAP_VeniceBeach — Around the World shot-station route
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_CourtCarnival : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_CourtCarnival();
    static constexpr int32 TOTAL_STATIONS = 10;
    UPROPERTY(BlueprintReadWrite) int32 CurrentStationIndex = 0;
    UPROPERTY(BlueprintReadWrite) int32 RouteScore = 0;
    UPROPERTY(BlueprintReadWrite) int32 ShotsMade = 0;
    UPROPERTY(BlueprintReadWrite) int32 ShotsAttempted = 0;
    UPROPERTY(BlueprintReadWrite) int32 StationsCompleted = 0;
    // Station names indexed 0–9
    static const TArray<FName>& GetStationNames();
    // Miss = +1-4, Make = +5-9
    UFUNCTION(BlueprintCallable) void OnShotAttempt(bool bMade);
    UFUNCTION(BlueprintCallable) void AdvanceToNextStation();
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};

// ─────────────────────────────────────────
//  NON-GAME MODULE (1)
// ─────────────────────────────────────────

// MAP: /Game/FEL/Maps/MAP_LumaVeniceShop — market/browse surface
UCLASS()
class FINALEVOLUTIONLAB_API AFELGameMode_MarketBrowse : public AFELGameModeBase
{
    GENERATED_BODY()
public:
    AFELGameMode_MarketBrowse();
    // Non-game module: no scoring, no match timer, no session result economy
    virtual void StartMatch() override { bMatchActive = false; }
    virtual void EndMatch(EFELMatchOutcome Outcome) override {}
    virtual FFELSessionResult BuildSessionResult_Implementation(EFELMatchOutcome Outcome) override;
};
