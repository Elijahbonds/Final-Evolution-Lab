// FELMovementCue.h
// FEL Movement Education Module — RTN/pFRG + IAP Modulation System
// Phase 9: Oscillation Literacy Framework
// SourceState must be checked before displaying athlete-specific data.
// All content defaults to demo_synthetic unless explicitly measured.
#pragma once
#include "CoreMinimal.h"
#include "FELMovementCue.generated.h"

// ─────────────────────────────────────────────────────────────────────────────
// Breathing Pattern Archetypes (RTN/pFRG output states)
// ─────────────────────────────────────────────────────────────────────────────
UENUM(BlueprintType)
enum class EFELBreathingPattern : uint8
{
    Exhale_Stacked      UMETA(DisplayName = "Exhale Stacked"),       // IAP locked on exhale — concentric peak
    Rhythmic_Oscillation UMETA(DisplayName = "Rhythmic Oscillation"), // Phasic RTN output — locomotion sync
    Sustained_Bracing   UMETA(DisplayName = "Sustained Bracing"),    // Tonic IAP — isometric holds
    Recovery_Rhythm     UMETA(DisplayName = "Recovery Rhythm")       // Parasympathetic downregulation
};

// ─────────────────────────────────────────────────────────────────────────────
// Oscillation Phase — Breath-Movement Coupling State
// ─────────────────────────────────────────────────────────────────────────────
UENUM(BlueprintType)
enum class EFELOscillationPhase : uint8
{
    Resonant    UMETA(DisplayName = "Resonant"),     // Score > 0.85 — standing wave achieved
    InPhase     UMETA(DisplayName = "In Phase"),     // Score > 0.50 — coupled but not optimal
    OutOfPhase  UMETA(DisplayName = "Out of Phase"), // Score > 0.20 — mismatch detected
    Unknown     UMETA(DisplayName = "Unknown")       // Score <= 0.20 — insufficient data
};

// ─────────────────────────────────────────────────────────────────────────────
// Movement Cue — maps a movement pattern to resonant breathing parameters
// ─────────────────────────────────────────────────────────────────────────────
USTRUCT(BlueprintType)
struct FINALEVOLUTIONLAB_API FFELMovementCue
{
    GENERATED_BODY()

    /** Unique movement pattern key (e.g. "squat", "sprint") */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Education")
    FString MovementPattern;

    /** Target breath frequency in Hz for optimal resonance with this movement */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Education")
    float ResonantFrequencyHz = 0.3f;

    /** Primary RTN/pFRG output pattern required for this movement */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Education")
    EFELBreathingPattern PrimaryPattern = EFELBreathingPattern::Exhale_Stacked;

    /** Whether this movement requires an active IAP pressure stack */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Education")
    bool IAP_StackRequired = true;

    /** Age-appropriate coaching cue — ages 7–11 ("The Body Balloon" frame) */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Education")
    FString CoachingCue_Child;

    /** Age-appropriate coaching cue — ages 12–17 ("The Pressure Engine" frame) */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Education")
    FString CoachingCue_Teen;

    /** Age-appropriate coaching cue — ages 18+ ("Systemic Resonance" frame) */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Education")
    FString CoachingCue_Adult;

    /** Movement phase context: "concentric" | "eccentric" | "isometric" | "ballistic" */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Education")
    FString MovementPhase = TEXT("concentric");

    /**
     * Data source classification — UI MUST display "EDUCATION DEMO" badge
     * for demo_synthetic. Never claim PRQ medical truth from demo content.
     * Values: "demo_synthetic" | "healthkit_readiness" | "measured_pose" |
     *         "measured_luma_or_arkit" | "verified_assessment"
     */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Education")
    FString SourceState = TEXT("demo_synthetic");
};
