// FELGameModeCourtCarnival.cpp — Court Carnival: Around the World (shot-station route)
// 10 stations | Miss=+1-4pts | Make=+5-9pts | Cyan M_ShotRing markers
// Session complete: emits route_score, shots_made, shots_attempted, stations_completed
#include "FELGameModeBase.h"
#include "Kismet/GameplayStatics.h"
#include "Math/UnrealMathUtility.h"

// ─── Station Registry ───────────────────────────────────────────────
static const TArray<FName> GCourtCarnivalStations = {
    TEXT("Baseline_Left"),
    TEXT("Wing_Left"),
    TEXT("TopOfKey"),
    TEXT("Wing_Right"),
    TEXT("Baseline_Right"),
    TEXT("HalfCourtLogo"),
    TEXT("VeniceMural"),
    TEXT("BoardwalkEdge"),
    TEXT("BleacherCorner"),
    TEXT("DunkLane")
};

// Camera zone names aligned to station indices (set in Level Blueprint)
static const TArray<FName> GCourtCarnivalCameraZones = {
    TEXT("Cam_BaselineLeft"),
    TEXT("Cam_WingLeft"),
    TEXT("Cam_TopOfKey"),
    TEXT("Cam_WingRight"),
    TEXT("Cam_BaselineRight"),
    TEXT("Cam_HalfCourt"),
    TEXT("Cam_VeniceMural"),
    TEXT("Cam_BoardwalkEdge"),
    TEXT("Cam_BleacherCorner"),
    TEXT("Cam_DunkLane")
};

// Material path for shot-ring markers (cyan emissive)
static const TCHAR* SHOT_RING_MATERIAL = TEXT("/Game/FEL/Materials/M_ShotRing");

// ─── Constructor ────────────────────────────────────────────────────
AFELGameMode_CourtCarnival::AFELGameMode_CourtCarnival()
{
    bScoringEnabled = true;
    DefaultMatchDuration = 0.f;   // route-complete triggers end, not timer
    PrimaryActorTick.bCanEverTick = false;
}

const TArray<FName>& AFELGameMode_CourtCarnival::GetStationNames()
{
    return GCourtCarnivalStations;
}

// ─── Shot Attempt ────────────────────────────────────────────────────
void AFELGameMode_CourtCarnival::OnShotAttempt(bool bMade)
{
    if (!bMatchActive || !bScoringEnabled) return;

    ShotsAttempted++;

    int32 Points = 0;
    if (bMade)
    {
        ShotsMade++;
        // Make: uniform +5..+9
        Points = FMath::RandRange(5, 9);
    }
    else
    {
        // Miss: uniform +1..+4
        Points = FMath::RandRange(1, 4);
    }

    RouteScore += Points;

    // Advance to next station after each shot
    AdvanceToNextStation();
}

// ─── Station Advance ─────────────────────────────────────────────────
void AFELGameMode_CourtCarnival::AdvanceToNextStation()
{
    StationsCompleted = FMath::Min(StationsCompleted + 1, TOTAL_STATIONS);
    CurrentStationIndex++;

    if (CurrentStationIndex >= TOTAL_STATIONS)
    {
        // Route complete
        EndMatch(ShotsMade >= ShotsAttempted / 2 ? EFELMatchOutcome::Win : EFELMatchOutcome::Loss);
        return;
    }

    // Notify HUD: new station + camera zone
    // Broadcast via UFELSessionReceiptComponent (handled in GameplayManager)
}

// ─── Session Result ──────────────────────────────────────────────────
FFELSessionResult AFELGameMode_CourtCarnival::BuildSessionResult_Implementation(EFELMatchOutcome Outcome)
{
    FFELSessionResult R;
    R.ModeId = TEXT("court_carnival");
    R.Score = static_cast<float>(RouteScore);
    R.DurationSeconds = ElapsedTime;
    R.bCompleted = (StationsCompleted >= TOTAL_STATIONS);
    R.ResultType = (Outcome == EFELMatchOutcome::Win) ? TEXT("win") :
                   (Outcome == EFELMatchOutcome::Loss) ? TEXT("loss") : TEXT("draw");

    // P1 economy candidates (resolved server-side via POST /games/session)
    // Mode weight = 1.0 (court_carnival)
    const float ModeWeight = 1.0f;
    const float NormalizedScore = FMath::Clamp(RouteScore / 60.f, 0.f, 1.f);
    R.XpCandidate = NormalizedScore * 500.f;
    R.ShardsCandidate = (Outcome == EFELMatchOutcome::Win) ? 50.f :
                        (Outcome == EFELMatchOutcome::Draw) ? 25.f : 15.f;
    R.PrqDeltaCandidate = (Outcome == EFELMatchOutcome::Win) ? 2.0f * ModeWeight :
                          (Outcome == EFELMatchOutcome::Draw) ? 0.5f * ModeWeight : 0.2f * ModeWeight;

    // Extended stats packed into ReplayMetadata JSON string
    R.ReplayMetadata = FString::Printf(
        TEXT("{\"route_score\":%d,\"shots_made\":%d,\"shots_attempted\":%d,\"stations_completed\":%d}"),
        RouteScore, ShotsMade, ShotsAttempted, StationsCompleted
    );

    return R;
}
