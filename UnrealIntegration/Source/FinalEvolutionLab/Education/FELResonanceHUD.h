// FELResonanceHUD.h
// Resonance HUD Widget — displays sine-wave breath-movement coupling state
// Phase 9 Education: toggleable Tutorial Overlay (does NOT touch game physics)
// UI MUST display "EDUCATION DEMO" badge when SourceState == demo_synthetic.
#pragma once
#include "CoreMinimal.h"
#include "CommonActivatableWidget.h"
#include "FELMovementCue.h"
#include "FELResonanceHUD.generated.h"

UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API UFELResonanceHUD : public UCommonActivatableWidget
{
    GENERATED_BODY()

public:
    // ── Resonance State ──────────────────────────────────────────────────────

    /** Normalized resonance score 0.0 (no coupling) – 1.0 (perfect resonance) */
    UPROPERTY(BlueprintReadOnly, Category="FEL|Resonance")
    float CurrentResonanceScore = 0.f;

    /** Current breath-movement coupling phase */
    UPROPERTY(BlueprintReadOnly, Category="FEL|Resonance")
    EFELOscillationPhase CurrentPhase = EFELOscillationPhase::Unknown;

    /** Age-appropriate coaching cue text for current movement */
    UPROPERTY(BlueprintReadOnly, Category="FEL|Resonance")
    FText CoachingText;

    /** IAP lock status text (e.g. "IAP integrity confirmed" or leak warning) */
    UPROPERTY(BlueprintReadOnly, Category="FEL|Resonance")
    FText IAP_StatusText;

    /**
     * Resonance color coding:
     *   Resonant   → green  (0.0, 0.9, 0.3, 1.0)
     *   InPhase    → yellow (1.0, 0.85, 0.0, 1.0)
     *   OutOfPhase → red    (0.9, 0.15, 0.0, 1.0)
     *   Unknown    → grey   (0.4, 0.4, 0.4, 1.0)
     */
    UPROPERTY(BlueprintReadOnly, Category="FEL|Resonance")
    FLinearColor ResonanceColor = FLinearColor(0.4f, 0.4f, 0.4f, 1.f);

    /** Whether IAP pressure cylinder is currently locked */
    UPROPERTY(BlueprintReadOnly, Category="FEL|Resonance")
    bool bIAPLocked = false;

    /** Whether education demo badge should be shown (always true for demo_synthetic content) */
    UPROPERTY(BlueprintReadOnly, Category="FEL|Resonance")
    bool bShowEducationDemoBadge = true;

    // ── C++ Callable API ─────────────────────────────────────────────────────

    /**
     * Update the resonance display with new score, phase, and coaching cue.
     * Automatically resolves ResonanceColor from Phase.
     * Fires OnResonanceWaveUpdate after updating state.
     */
    UFUNCTION(BlueprintCallable, Category="FEL|Resonance")
    void UpdateResonanceDisplay(float Score, EFELOscillationPhase Phase, FText Cue);

    /**
     * Update the IAP status text and lock state.
     * Fires OnIAPStatusChange after updating state.
     */
    UFUNCTION(BlueprintCallable, Category="FEL|Resonance")
    void SetIAPStatus(FText StatusText, bool bLocked);

    // ── Blueprint Implementation Events ─────────────────────────────────────

    /**
     * Fires every tick — Blueprint drives sine-wave visualization.
     * Use CurrentResonanceScore to control wave amplitude.
     * Use CurrentPhase to drive color and pulse speed.
     */
    UFUNCTION(BlueprintImplementableEvent, Category="FEL|Resonance")
    void OnResonanceWaveUpdate();

    /**
     * Fires when IAP lock state changes.
     * Blueprint should animate the IAP corset ring overlay.
     */
    UFUNCTION(BlueprintImplementableEvent, Category="FEL|Resonance")
    void OnIAPStatusChange();

protected:
    /** Resolve FLinearColor from oscillation phase */
    FLinearColor ResolvePhaseColor(EFELOscillationPhase Phase) const;
};
