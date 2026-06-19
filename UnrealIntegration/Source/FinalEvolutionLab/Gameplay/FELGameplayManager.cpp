// FELGameplayManager.cpp
// Phase 7 — Gameplay Logic Implementation
// Phase 9 QA fix: EFELOutcome → EFELMatchOutcome (via typedef in FELTypes.h — both compile)
//                 XPEarned/ShardsEarned/PRQDelta → XpCandidate/ShardsCandidate/PrqDeltaCandidate

#include "FELGameplayManager.h"
#include "FELBackendConfig.h"
#include "HttpModule.h"
#include "Http.h"
#include "JsonObjectConverter.h"
#include "Kismet/GameplayStatics.h"

void UFELGameplayManager::Initialize(FSubsystemCollectionBase& Collection) {
    Super::Initialize(Collection);
    UE_LOG(LogTemp, Log, TEXT("[FEL] GameplayManager initialized — 19 modes armed"));
}

float UFELGameplayManager::GetModeWeight(const FString& ModeId) const {
    const float* W = ModeWeights.Find(ModeId);
    return W ? *W : 1.0f;
}

int32 UFELGameplayManager::ComputeXP(EFELMatchOutcome Outcome, float MRIScore, float Weight) const {
    float Base  = (Outcome == EFELMatchOutcome::Win)  ? 200.f
                : (Outcome == EFELMatchOutcome::Draw) ? 100.f : 50.f;
    float Bonus = FMath::Clamp(MRIScore / 100.f, 0.f, 1.f) * 100.f;
    return FMath::Min((int32)((Base + Bonus) * Weight), XP_CAP);
}

int32 UFELGameplayManager::ComputeShards(EFELMatchOutcome Outcome, float PacingScore) const {
    int32 Base = (Outcome == EFELMatchOutcome::Win)  ? SHARD_WIN
               : (Outcome == EFELMatchOutcome::Draw) ? SHARD_DRAW : SHARD_LOSS;
    float Mul  = (PacingScore >= 75.f) ? 1.05f : 1.0f;
    return (int32)(Base * Mul);
}

float UFELGameplayManager::ComputePRQDelta(EFELMatchOutcome Outcome, float MRIScore, float Weight) const {
    float PRQBase = (Outcome == EFELMatchOutcome::Win)  ? PRQ_WIN
                  : (Outcome == EFELMatchOutcome::Draw) ? PRQ_DRAW : PRQ_LOSS;
    return PRQBase * Weight * FMath::Clamp(MRIScore / 100.f + 0.5f, 0.5f, 1.5f);
}

FFELSessionResult UFELGameplayManager::ComputeSessionResult(
    const FString& ModeId, EFELMatchOutcome Outcome,
    float MRIScore, float ARV, float ESI, float PacingScore)
{
    FFELSessionResult R;
    R.ModeId          = ModeId;
    R.Outcome         = Outcome;
    R.ARV             = ARV;
    R.ESI             = ESI;
    R.PacingScore     = PacingScore;
    R.MRIScore        = ARV * 0.40f + (100.f - ESI) * 0.35f + PacingScore * 0.25f;
    R.bCompleted      = true;
    float W           = GetModeWeight(ModeId);
    R.XpCandidate     = ComputeXP(Outcome, MRIScore, W);
    R.ShardsCandidate = ComputeShards(Outcome, PacingScore);
    R.PrqDeltaCandidate = ComputePRQDelta(Outcome, MRIScore, W);
    R.SessionId       = FGuid::NewGuid().ToString();
    R.ResultType      = (Outcome == EFELMatchOutcome::Win)  ? TEXT("win")
                      : (Outcome == EFELMatchOutcome::Draw) ? TEXT("draw") : TEXT("loss");
    return R;
}

void UFELGameplayManager::OnMatchEnd(
    const FString& ModeId, float PlayerScore, float OpponentScore,
    float MRIScore, float ARV, float ESI, float PacingScore)
{
    EFELMatchOutcome Outcome = (PlayerScore > OpponentScore) ? EFELMatchOutcome::Win
                             : (PlayerScore < OpponentScore) ? EFELMatchOutcome::Loss
                             : EFELMatchOutcome::Draw;
    FFELSessionResult Result = ComputeSessionResult(ModeId, Outcome, MRIScore, ARV, ESI, PacingScore);
    Result.Score         = PlayerScore;
    Result.OpponentScore = OpponentScore;
    DispatchSessionReceipt(Result);
}

void UFELGameplayManager::DispatchSessionReceipt(const FFELSessionResult& Result) {
    TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Req = FHttpModule::Get().CreateRequest();
    Req->SetURL(FELBackendConfig::ResolveSessionReceiptUrl());
    Req->SetVerb(TEXT("POST"));
    Req->SetHeader(TEXT("Content-Type"), TEXT("application/json"));

    FString Body = FString::Printf(
        TEXT("{\"user_id\":\"%s\",\"mode_id\":\"%s\",\"outcome\":\"%s\","
             "\"score\":%.1f,\"opponent_score\":%.1f,"
             "\"mri_score\":%.2f,\"arv\":%.2f,\"esi\":%.2f,\"pacing_score\":%.2f,"
             "\"xp_candidate\":%.0f,\"shards_candidate\":%.0f,\"prq_delta_candidate\":%.3f,"
             "\"session_id\":\"%s\"}"),
        *Result.UserId, *Result.ModeId, *Result.ResultType,
        Result.Score, Result.OpponentScore,
        Result.MRIScore, Result.ARV, Result.ESI, Result.PacingScore,
        Result.XpCandidate, Result.ShardsCandidate, Result.PrqDeltaCandidate,
        *Result.SessionId);
    Req->SetContentAsString(Body);
    Req->OnProcessRequestComplete().BindLambda([](FHttpRequestPtr, FHttpResponsePtr Resp, bool bOk){
        if (bOk && Resp.IsValid())
            UE_LOG(LogTemp, Log, TEXT("[FEL] Session receipt: %d"), Resp->GetResponseCode());
        else
            UE_LOG(LogTemp, Warning, TEXT("[FEL] Session receipt dispatch FAILED"));
    });
    Req->ProcessRequest();
}

// ── Production mode evaluators ────────────────────────────────────────────────

EFELMatchOutcome UFELGameplayManager::EvaluateBasketballOutcome(float P, float O)
    { return P > O ? EFELMatchOutcome::Win : P < O ? EFELMatchOutcome::Loss : EFELMatchOutcome::Draw; }

EFELMatchOutcome UFELGameplayManager::EvaluateKarateOutcome(float PHP, float OHP, bool bTime)
    { if (PHP > OHP) return EFELMatchOutcome::Win;
      if (PHP < OHP) return EFELMatchOutcome::Loss;
      return EFELMatchOutcome::Draw; }

EFELMatchOutcome UFELGameplayManager::EvaluateBaseballOutcome(int32 PR, int32 OR_, int32 Inning)
    { if (Inning >= 9) return PR > OR_ ? EFELMatchOutcome::Win
                            : PR < OR_ ? EFELMatchOutcome::Loss : EFELMatchOutcome::Draw;
      return EFELMatchOutcome::Draw; }

EFELMatchOutcome UFELGameplayManager::EvaluateFootballOutcome(int32 PTD, int32 OTD)
    { return PTD > OTD ? EFELMatchOutcome::Win : PTD < OTD ? EFELMatchOutcome::Loss : EFELMatchOutcome::Draw; }

EFELMatchOutcome UFELGameplayManager::EvaluateSoccerOutcome(int32 PG, int32 OG)
    { return PG > OG ? EFELMatchOutcome::Win : PG < OG ? EFELMatchOutcome::Loss : EFELMatchOutcome::Draw; }

EFELMatchOutcome UFELGameplayManager::EvaluateGolfOutcome(int32 PStk, int32 Par)
    { if (PStk <= Par - 2) return EFELMatchOutcome::Win;
      if (PStk <= Par + 2) return EFELMatchOutcome::Draw;
      return EFELMatchOutcome::Loss; }

EFELMatchOutcome UFELGameplayManager::EvaluateTennisOutcome(int32 PS, int32 OS)
    { return PS > OS ? EFELMatchOutcome::Win : PS < OS ? EFELMatchOutcome::Loss : EFELMatchOutcome::Draw; }

EFELMatchOutcome UFELGameplayManager::EvaluateVolleyballOutcome(int32 PP, int32 OP)
    { return PP >= 25 && PP - OP >= 2 ? EFELMatchOutcome::Win
           : OP >= 25 && OP - PP >= 2 ? EFELMatchOutcome::Loss : EFELMatchOutcome::Draw; }

EFELMatchOutcome UFELGameplayManager::EvaluateSurfingOutcome(float PS, float Thresh)
    { return PS >= Thresh       ? EFELMatchOutcome::Win
           : PS >= Thresh * 0.7f ? EFELMatchOutcome::Draw : EFELMatchOutcome::Loss; }

EFELMatchOutcome UFELGameplayManager::EvaluateGymnasticsOutcome(float JS, float Gold)
    { return JS >= Gold        ? EFELMatchOutcome::Win
           : JS >= Gold * 0.85f ? EFELMatchOutcome::Draw : EFELMatchOutcome::Loss; }

EFELMatchOutcome UFELGameplayManager::EvaluateBrainBrawlOutcome(int32 PC, int32 OC)
    { return PC > OC ? EFELMatchOutcome::Win : PC < OC ? EFELMatchOutcome::Loss : EFELMatchOutcome::Draw; }

// ── Staging / Preview / Non-game evaluators ───────────────────────────────────

EFELMatchOutcome UFELGameplayManager::EvaluateSkateboardingOutcome(int32 Score, int32) const
    { return Score >= 50 ? EFELMatchOutcome::Win : EFELMatchOutcome::Loss; }

EFELMatchOutcome UFELGameplayManager::EvaluateSnowboardingOutcome(int32 Score, int32) const
    { return Score >= 50 ? EFELMatchOutcome::Win : EFELMatchOutcome::Loss; }

EFELMatchOutcome UFELGameplayManager::EvaluateWhoSceneItOutcome(int32 Score, int32) const
    { return Score >= 7 ? EFELMatchOutcome::Win : EFELMatchOutcome::Loss; }

EFELMatchOutcome UFELGameplayManager::EvaluateCourtCarnivalOutcome(int32 Score, int32 Opp) const
    { if (Score > Opp)  return EFELMatchOutcome::Win;
      if (Score == Opp) return EFELMatchOutcome::Draw;
      return EFELMatchOutcome::Loss; }

EFELMatchOutcome UFELGameplayManager::EvaluateMarketBrowseOutcome(int32, int32) const
    { return EFELMatchOutcome::Draw; }   // Non-game-module — always neutral
