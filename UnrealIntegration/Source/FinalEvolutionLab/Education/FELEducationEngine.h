// FELEducationEngine.h
// FEL Respiratory-Entrained Movement Education Subsystem
// RTN/pFRG Kernel + IAP Modulation — Oscillation Literacy Framework
// Phase 9 Education: Tutorial Overlay — separate from game physics
#pragma once
#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELMovementCue.h"
#include "FELEducationEngine.generated.h"

// ─────────────────────────────────────────────────────────────────────────────
// Age Group — controls coaching language register
// ─────────────────────────────────────────────────────────────────────────────
UENUM(BlueprintType)
enum class EFELAgeGroup : uint8
{
    Child  UMETA(DisplayName = "Child (7-11)"),   // "The Body Balloon" framework
    Teen   UMETA(DisplayName = "Teen (12-17)"),   // "The Pressure Engine" framework
    Adult  UMETA(DisplayName = "Adult (18+)")     // "Systemic Resonance" framework
};

// ─────────────────────────────────────────────────────────────────────────────
// Resonance Update Delegate
// ─────────────────────────────────────────────────────────────────────────────
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(
    FOnResonanceUpdate,
    float, ResonanceScore,
    EFELOscillationPhase, Phase);

// ─────────────────────────────────────────────────────────────────────────────
// UFELEducationEngine — Game Instance Subsystem
// Teach athletes to become biological metronomes via breath-movement resonance.
// ─────────────────────────────────────────────────────────────────────────────
UCLASS()
class FINALEVOLUTIONLAB_API UFELEducationEngine : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;

    // ── Resonance Delegate ───────────────────────────────────────────────────

    /** Fires when resonance state changes — wire to FELResonanceHUD */
    UPROPERTY(BlueprintAssignable, Category="FEL|Education")
    FOnResonanceUpdate OnResonanceUpdate;

    // ── Athlete State ────────────────────────────────────────────────────────

    /** Current athlete age group — controls coaching language */
    UPROPERTY(BlueprintReadOnly, Category="FEL|Education")
    EFELAgeGroup CurrentAgeGroup = EFELAgeGroup::Adult;

    /** Pre-loaded movement cue library — 12 patterns by default */
    UPROPERTY(BlueprintReadOnly, Category="FEL|Education")
    TMap<FString, FFELMovementCue> CueLibrary;

    // ── Core API ─────────────────────────────────────────────────────────────

    /**
     * Set the athlete age group — updates coaching language register.
     * Call this after athlete profile is loaded.
     */
    UFUNCTION(BlueprintCallable, Category="FEL|Education")
    void SetAthleteAgeGroup(EFELAgeGroup AgeGroup);

    /**
     * Analyze the coupling state between breath and movement frequencies.
     * Returns EFELOscillationPhase based on computed resonance score.
     * @param ModeId          Current game mode (for contextual cuing)
     * @param BreathHz        Measured/reported breath frequency
     * @param MovementHz      Target movement frequency from cue library
     */
    UFUNCTION(BlueprintCallable, Category="FEL|Education")
    EFELOscillationPhase AnalyzeMovementPhase(
        const FString& ModeId,
        float BreathHz,
        float MovementHz);

    /**
     * Get the age-appropriate coaching cue for a movement pattern.
     * Always returns demo_synthetic content unless SourceState is overridden.
     */
    UFUNCTION(BlueprintPure, Category="FEL|Education")
    FString GetCoachingCue(const FString& MovementPattern, EFELAgeGroup AgeGroup) const;

    /**
     * Compute resonance score between actual breath rate and target movement rate.
     * Score = 1.0 - clamp(|BreathHz - MovementHz| / MovementHz, 0, 1)
     * Returns 0 if MovementHz is zero.
     */
    UFUNCTION(BlueprintPure, Category="FEL|Education")
    float ComputeResonanceScore(float BreathHz, float MovementHz) const;

    /**
     * Get IAP feedback text based on stack detection and age group.
     * Adult: RTN/pFRG technical language.
     * Teen: Mechanical coaching cue.
     * Child: Body Balloon metaphor.
     */
    UFUNCTION(BlueprintPure, Category="FEL|Education")
    FString GetIAPFeedback(bool bStackDetected, EFELAgeGroup AgeGroup) const;

    /**
     * Broadcast resonance HUD update — fires OnResonanceUpdate delegate.
     * Call this after each AnalyzeMovementPhase() result.
     */
    UFUNCTION(BlueprintCallable, Category="FEL|Education")
    void BroadcastResonanceHUDUpdate(float ResonanceScore, EFELOscillationPhase Phase);

    /**
     * Get a movement cue from the library by pattern key.
     * Returns default FFELMovementCue if key not found.
     */
    UFUNCTION(BlueprintPure, Category="FEL|Education")
    FFELMovementCue GetMovementCue(const FString& Pattern) const;

private:
    /** Pre-populate CueLibrary with 12 default movement patterns */
    void PreloadDefaultCues();

    /** Cached last resonance score */
    float LastResonanceScore = 0.f;
};
