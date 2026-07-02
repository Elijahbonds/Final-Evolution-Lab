// FELTypes.h — Canonical shared types for Final Evolution Lab
// Phase 9 QA fix: eliminates duplicate FFELSessionResult + enum name conflict
//   • FELGameModeBase.h defined EFELMatchOutcome + FFELSessionResult (fields named *Candidate)
//   • FELGameplayManager.h re-defined EFELOutcome + FFELSessionResult (fields named *Earned)
//   Resolution: canonical names are *Candidate (economy values are unverified until backend confirms).
//   EFELMatchOutcome is canonical. EFELOutcome is kept as a typedef for transition only.
#pragma once
#include "CoreMinimal.h"
#include "FELTypes.generated.h"

// ─── Outcome Enum ─────────────────────────────────────────────────────────────
UENUM(BlueprintType)
enum class EFELMatchOutcome : uint8
{
    Win     UMETA(DisplayName="Win"),
    Draw    UMETA(DisplayName="Draw"),
    Loss    UMETA(DisplayName="Loss"),
    Forfeit UMETA(DisplayName="Forfeit")  // early exit / connectivity drop
};

// Transition typedef — FELGameplayManager.cpp used EFELOutcome; resolves via this alias
// Do NOT add new code using EFELOutcome; use EFELMatchOutcome in all new code.
typedef EFELMatchOutcome EFELOutcome;

// ─── Session Result Struct ─────────────────────────────────────────────────────
// Canonical field names are *Candidate (client-computed; backend verifies before rewarding).
// Note: USTRUCT cannot contain C++ reference members — removed aliases from prior draft.
// FELGameplayManager.cpp has been updated to use XpCandidate / ShardsCandidate / PrqDeltaCandidate.
USTRUCT(BlueprintType)
struct FINALEVOLUTIONLAB_API FFELSessionResult
{
    GENERATED_BODY()

    // Identity
    UPROPERTY(BlueprintReadWrite, Category="FEL|Session") FString UserId;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Session") FString SessionId;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Session") FString ModeId;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Session") FString VenueId;

    // Match outcome
    UPROPERTY(BlueprintReadWrite, Category="FEL|Session") EFELMatchOutcome Outcome = EFELMatchOutcome::Loss;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Session") float Score          = 0.f;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Session") float OpponentScore  = 0.f;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Session") float DurationSeconds = 0.f;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Session") bool  bCompleted     = false;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Session") FString ResultType;

    // MRI inputs (client-sent for backend re-computation)
    UPROPERTY(BlueprintReadWrite, Category="FEL|MRI") float ARV         = 0.f;
    UPROPERTY(BlueprintReadWrite, Category="FEL|MRI") float ESI         = 0.f;
    UPROPERTY(BlueprintReadWrite, Category="FEL|MRI") float PacingScore = 0.f;
    UPROPERTY(BlueprintReadWrite, Category="FEL|MRI") float MRIScore    = 0.f;

    // Economy candidates — unverified until backend confirms
    UPROPERTY(BlueprintReadWrite, Category="FEL|Economy") float XpCandidate      = 0.f;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Economy") float ShardsCandidate  = 0.f;
    UPROPERTY(BlueprintReadWrite, Category="FEL|Economy") float PrqDeltaCandidate = 0.f;
};
