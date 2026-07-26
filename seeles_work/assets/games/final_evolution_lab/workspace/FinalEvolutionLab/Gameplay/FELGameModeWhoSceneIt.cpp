// FELGameModeWhoSceneIt.cpp — Who Scene It: Media / Recognition / Quiz
// Show media clip → player identifies scene/athlete/play → speed bonus
// Session result: rounds_played, correct, accuracy_pct
#include "FELGameModeBase.h"
#include "Kismet/GameplayStatics.h"

// ─── Media Entry ─────────────────────────────────────────────────────
USTRUCT()
struct FFELMediaEntry
{
    GENERATED_BODY()
    FString MediaId;
    FString MediaType;   // "image" | "video_clip" | "highlight"
    FString MediaUrl;    // served from CDN
    TArray<FString> AnswerChoices;
    FString CorrectAnswerId;   // server-authoritative; client receives empty string
    FString Category;          // "play", "athlete", "venue", "sport_moment"
};

// MOCK media bank (MOCK_DATA label — swap for server-fetched entries)
static TArray<FFELMediaEntry> BuildMockMediaBank()
{
    TArray<FFELMediaEntry> Bank;
    Bank.Add({"m_01","image","https://finalevolutiongroup.com/media/mock_dunk.jpg",
              {"Baseline Dunk","Alley-oop","Fade-away","Windmill"}, "", "play"});
    Bank.Add({"m_02","video_clip","https://finalevolutiongroup.com/media/mock_sprint.mp4",
              {"100m Sprint","Long Jump","400m Hurdles","Triple Jump"}, "", "sport_moment"});
    Bank.Add({"m_03","image","https://finalevolutiongroup.com/media/mock_court.jpg",
              {"Venice Beach Court","Zen Dojo","Neuro Arena","Gridiron Stadium"}, "", "venue"});
    return Bank;
}

static TArray<FFELMediaEntry> GMockMediaBank = BuildMockMediaBank();

// ─── Constructor ─────────────────────────────────────────────────────
AFELGameMode_WhoSceneIt::AFELGameMode_WhoSceneIt()
{
    bScoringEnabled = true;
    DefaultMatchDuration = 0.f;
    RoundTimeLimit = 20.0f;
}

// ─── Round Logic ─────────────────────────────────────────────────────
void AFELGameMode_WhoSceneIt::OnMediaPresented(const FString& MediaId)
{
    // Called when HUD shows a media item to the player
    // Starts per-round timer managed by caller
}

void AFELGameMode_WhoSceneIt::OnIdentificationSubmitted(const FString& AnswerId, float ResponseTime)
{
    if (!bMatchActive) return;

    RoundsPlayed++;

    // Speed bonus: up to 0.5x extra for answering in < half the time limit
    float TimeFraction = FMath::Clamp(ResponseTime / RoundTimeLimit, 0.f, 1.f);
    float RoundSpeedBonus = (1.f - TimeFraction) * 0.5f;

    // Server determines correctness via POST /games/session (embedded in session payload)
    // Client submits answer — server validates at session-complete POST
    // For client-side flow continuity, we optimistically track locally
    // and reconcile at EndMatch when server-verified result arrives.
    // Optimistic tracking (not economy-eligible until server confirmed):
    bool bOptimisticCorrect = !AnswerId.IsEmpty();
    if (bOptimisticCorrect)
    {
        CorrectIdentifications++;
        SpeedBonus += RoundSpeedBonus;
    }

    AccuracyPct = (RoundsPlayed > 0)
                 ? (static_cast<float>(CorrectIdentifications) / RoundsPlayed) * 100.f
                 : 0.f;

    // After a set number of rounds, end match
    const int32 TotalRounds = FMath::Min(GMockMediaBank.Num(), 10);
    if (RoundsPlayed >= TotalRounds)
    {
        EFELMatchOutcome Outcome = (AccuracyPct >= 70.f) ? EFELMatchOutcome::Win :
                                   (AccuracyPct >= 50.f) ? EFELMatchOutcome::Draw :
                                                            EFELMatchOutcome::Loss;
        EndMatch(Outcome);
    }
}

// ─── Session Result ──────────────────────────────────────────────────
FFELSessionResult AFELGameMode_WhoSceneIt::BuildSessionResult_Implementation(EFELMatchOutcome Outcome)
{
    FFELSessionResult R;
    R.ModeId = TEXT("who_scene_it");
    R.Score = static_cast<float>(CorrectIdentifications) * 100.f + SpeedBonus * 50.f;
    R.DurationSeconds = ElapsedTime;
    R.bCompleted = (RoundsPlayed > 0);
    R.ResultType = (Outcome == EFELMatchOutcome::Win) ? TEXT("win") :
                   (Outcome == EFELMatchOutcome::Draw) ? TEXT("draw") : TEXT("loss");

    const float ModeWeight = 1.1f;
    R.XpCandidate = FMath::Min(R.Score * 0.4f, 500.f);
    R.ShardsCandidate = (Outcome == EFELMatchOutcome::Win) ? 50.f :
                        (Outcome == EFELMatchOutcome::Draw) ? 25.f : 15.f;
    R.PrqDeltaCandidate = (Outcome == EFELMatchOutcome::Win) ? 2.0f * ModeWeight :
                          (Outcome == EFELMatchOutcome::Draw) ? 0.5f * ModeWeight : 0.2f * ModeWeight;

    R.ReplayMetadata = FString::Printf(
        TEXT("{\"rounds_played\":%d,\"correct\":%d,\"accuracy_pct\":%.1f,\"speed_bonus\":%.2f}"),
        RoundsPlayed, CorrectIdentifications, AccuracyPct, SpeedBonus
    );

    return R;
}
