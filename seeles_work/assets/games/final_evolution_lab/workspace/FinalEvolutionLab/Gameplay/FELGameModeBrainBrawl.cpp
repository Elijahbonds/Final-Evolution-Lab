// FELGameModeBrainBrawl.cpp — Cognitive Arena
// 7 categories | Mock Q-bank (MOCK_DATA) | 15s timer | Streak bonus (3x → +25%)
// CorrectIndex = -1 always on client (server-authoritative: POST /games/brainstorm/verify)
#include "FELGameModeBase.h"
#include "Kismet/GameplayStatics.h"
#include "HttpModule.h"
#include "Interfaces/IHttpRequest.h"
#include "Interfaces/IHttpResponse.h"
#include "Serialization/JsonWriter.h"
#include "Policies/CondensedJsonPrintPolicy.h"

// ─── Category Definitions ────────────────────────────────────────────
static const TArray<FString> GBrainBrawlCategories = {
    TEXT("SportsIQ"),
    TEXT("BodyIQ"),
    TEXT("STEM"),
    TEXT("CommonCore"),
    TEXT("CollegePrep"),
    TEXT("AppliedKinesiology"),
    TEXT("StrategyDecision")
};

// ─── MOCK Question Bank (labeled MOCK_DATA — CorrectIndex ALWAYS -1 client-side) ───
USTRUCT()
struct FFELBrainBrawlQuestion
{
    GENERATED_BODY()
    FString QuestionId;
    FString Category;
    FString QuestionText;
    TArray<FString> Choices;
    int32 CorrectIndex = -1;   // ALWAYS -1: server-authoritative
    FString Explanation;
};

// MOCK_DATA: Replace with server-fetched questions before production
static TArray<FFELBrainBrawlQuestion> BuildMockQuestionBank()
{
    TArray<FFELBrainBrawlQuestion> Bank;

    // SportsIQ
    Bank.Add({"q_si_01", "SportsIQ", "How many points is a 3-pointer worth in basketball?",
              {"1", "2", "3", "4"}, -1, "MOCK_DATA: server-verified"});
    Bank.Add({"q_si_02", "SportsIQ", "In soccer, how many players are on each team?",
              {"9", "10", "11", "12"}, -1, "MOCK_DATA"});

    // BodyIQ
    Bank.Add({"q_bi_01", "BodyIQ", "Which muscle is primarily activated during a sprint start?",
              {"Quadriceps", "Hamstrings", "Glutes", "Calves"}, -1, "MOCK_DATA"});
    Bank.Add({"q_bi_02", "BodyIQ", "The IAP corset primarily involves which structures?",
              {"Spine and ribcage", "Diaphragm, pelvic floor, TVA, multifidus", "Hip flexors", "Lats and traps"}, -1, "MOCK_DATA"});

    // STEM
    Bank.Add({"q_st_01", "STEM", "What is the formula for kinetic energy?",
              {"mgh", "0.5mv^2", "F*d", "ma"}, -1, "MOCK_DATA"});

    // CommonCore
    Bank.Add({"q_cc_01", "CommonCore", "Solve: if a player scores 24 points in 8 quarters, what is the average per quarter?",
              {"2", "3", "4", "6"}, -1, "MOCK_DATA"});

    // CollegePrep
    Bank.Add({"q_cp_01", "CollegePrep", "In physics, what does 'torque' measure?",
              {"Speed of rotation", "Rotational force", "Linear momentum", "Centripetal acceleration"}, -1, "MOCK_DATA"});

    // AppliedKinesiology
    Bank.Add({"q_ak_01", "AppliedKinesiology", "What type of muscle contraction occurs when a muscle lengthens under load?",
              {"Isometric", "Concentric", "Eccentric", "Plyometric"}, -1, "MOCK_DATA"});

    // StrategyDecision
    Bank.Add({"q_sd_01", "StrategyDecision", "With 5 seconds left and down by 2, which play maximizes win probability in basketball?",
              {"Drive for layup", "Full-court heave", "3-point attempt", "Foul immediately"}, -1, "MOCK_DATA"});

    return Bank;
}

static TArray<FFELBrainBrawlQuestion> GMockQuestionBank = BuildMockQuestionBank();

// ─── Constructor ─────────────────────────────────────────────────────
AFELGameMode_BrainBrawl::AFELGameMode_BrainBrawl()
{
    bScoringEnabled = true;
    DefaultMatchDuration = 0.f;   // question-count driven, not timer
    PrimaryActorTick.bCanEverTick = false;
    QuestionTimeLimit = 15.0f;
    StreakBonusThreshold = 3;
}

// ─── Answer Submission ───────────────────────────────────────────────
void AFELGameMode_BrainBrawl::OnAnswerSubmitted(int32 AnswerIndex, float ResponseTimeSeconds)
{
    if (!bMatchActive) return;

    QuestionsAttempted++;

    // Pick current question from bank (cyclic for mock)
    const FFELBrainBrawlQuestion& Q = GMockQuestionBank[
        (QuestionsAttempted - 1) % GMockQuestionBank.Num()
    ];

    // POST to server for authoritative verification
    // Endpoint: POST /games/brainstorm/verify
    // Body: { session_id, question_id, answer_index }
    // Response: { correct: bool, score_delta: float, explanation: string }
    FString Url = TEXT("https://finalevolutiongroup.com/games/brainstorm/verify");
    TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Req = FHttpModule::Get().CreateRequest();
    Req->SetVerb(TEXT("POST"));
    Req->SetURL(Url);
    Req->SetHeader(TEXT("Content-Type"), TEXT("application/json"));

    FString Body = FString::Printf(
        TEXT("{\"session_id\":\"%s\",\"question_id\":\"%s\",\"answer_index\":%d,\"response_time\":%.2f}"),
        *FGuid::NewGuid().ToString(), *Q.QuestionId, AnswerIndex, ResponseTimeSeconds
    );
    Req->SetContentAsString(Body);

    Req->OnProcessRequestComplete().BindLambda(
        [this](FHttpRequestPtr, FHttpResponsePtr Resp, bool bSuccess)
        {
            // Server returns { correct: bool, score_delta: float }
            // Update score locally after server confirmation
            if (bSuccess && Resp.IsValid() && Resp->GetResponseCode() == 200)
            {
                // Parse: mock assumes correct if score_delta > 0
                bool bCorrect = Resp->GetContentAsString().Contains(TEXT("\"correct\":true"));
                if (bCorrect)
                {
                    CorrectAnswers++;
                    CurrentStreak++;
                    PeakStreak = FMath::Max(PeakStreak, CurrentStreak);

                    // Streak bonus: 3 consecutive correct → +25% multiplier
                    if (CurrentStreak >= StreakBonusThreshold)
                        StreakMultiplier = 1.25f;

                    // Base cognitive score: 100 pts per correct, scaled by speed bonus
                    float SpeedBonus = FMath::Clamp(1.f - (ResponseTimeSeconds / QuestionTimeLimit), 0.f, 0.5f);
                    CognitiveScore += (100.f + SpeedBonus * 50.f) * StreakMultiplier;
                }
                else
                {
                    CurrentStreak = 0;
                    StreakMultiplier = 1.0f;
                }
            }
        }
    );
    Req->ProcessRequest();
}

// ─── Session Result ──────────────────────────────────────────────────
FFELSessionResult AFELGameMode_BrainBrawl::BuildSessionResult_Implementation(EFELMatchOutcome Outcome)
{
    FFELSessionResult R;
    R.ModeId = TEXT("brain_brawl");
    R.Score = CognitiveScore;
    R.DurationSeconds = ElapsedTime;
    R.bCompleted = (QuestionsAttempted > 0);
    R.ResultType = (CognitiveScore >= 500.f) ? TEXT("win") :
                   (CognitiveScore >= 300.f) ? TEXT("draw") : TEXT("loss");

    // Mode weight = 1.0 for brain_brawl
    const float ModeWeight = 1.0f;
    const float Accuracy = (QuestionsAttempted > 0)
                          ? static_cast<float>(CorrectAnswers) / QuestionsAttempted
                          : 0.f;

    R.XpCandidate = FMath::Min(CognitiveScore * 0.5f, 500.f);
    R.ShardsCandidate = (Outcome == EFELMatchOutcome::Win) ? 50.f :
                        (Outcome == EFELMatchOutcome::Draw) ? 25.f : 15.f;
    R.PrqDeltaCandidate = (Outcome == EFELMatchOutcome::Win) ? 2.0f * ModeWeight :
                          (Outcome == EFELMatchOutcome::Draw) ? 0.5f * ModeWeight : 0.2f * ModeWeight;

    R.ReplayMetadata = FString::Printf(
        TEXT("{\"questions_attempted\":%d,\"correct_answers\":%d,\"streak_peak\":%d,"
             "\"cognitive_score\":%.1f,\"accuracy_pct\":%.2f,\"current_category\":\"%s\"}"),
        QuestionsAttempted, CorrectAnswers, PeakStreak,
        CognitiveScore, Accuracy * 100.f, *CurrentCategory
    );

    return R;
}
