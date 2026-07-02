// FELEducationEngine.cpp
// RTN/pFRG Kernel + IAP Modulation — Oscillation Literacy Framework
// Phase 9 Education: Tutorial Overlay (separate from game physics)
#include "FELEducationEngine.h"
#include "Math/UnrealMathUtility.h"

void UFELEducationEngine::Initialize(FSubsystemCollectionBase& Collection)
{
    Super::Initialize(Collection);
    PreloadDefaultCues();
    UE_LOG(LogTemp, Log, TEXT("[FEL|Education] Engine initialized — %d movement cues loaded"), CueLibrary.Num());
}

void UFELEducationEngine::SetAthleteAgeGroup(EFELAgeGroup AgeGroup)
{
    CurrentAgeGroup = AgeGroup;
}

// ─────────────────────────────────────────────────────────────────────────────
// ComputeResonanceScore
// Score = 1.0 - clamp(|BreathHz - MovementHz| / MovementHz, 0, 1)
// Returns 0 if MovementHz == 0 (undefined)
// ─────────────────────────────────────────────────────────────────────────────
float UFELEducationEngine::ComputeResonanceScore(float BreathHz, float MovementHz) const
{
    if (FMath::IsNearlyZero(MovementHz)) return 0.f;
    float Deviation = FMath::Abs(BreathHz - MovementHz) / MovementHz;
    return 1.f - FMath::Clamp(Deviation, 0.f, 1.f);
}

// ─────────────────────────────────────────────────────────────────────────────
// AnalyzeMovementPhase
// Thresholds: Resonant >0.85 | InPhase >0.50 | OutOfPhase >0.20 | Unknown <=0.20
// ─────────────────────────────────────────────────────────────────────────────
EFELOscillationPhase UFELEducationEngine::AnalyzeMovementPhase(
    const FString& ModeId,
    float BreathHz,
    float MovementHz)
{
    LastResonanceScore = ComputeResonanceScore(BreathHz, MovementHz);

    EFELOscillationPhase Phase;
    if      (LastResonanceScore > 0.85f) Phase = EFELOscillationPhase::Resonant;
    else if (LastResonanceScore > 0.50f) Phase = EFELOscillationPhase::InPhase;
    else if (LastResonanceScore > 0.20f) Phase = EFELOscillationPhase::OutOfPhase;
    else                                 Phase = EFELOscillationPhase::Unknown;

    BroadcastResonanceHUDUpdate(LastResonanceScore, Phase);
    return Phase;
}

// ─────────────────────────────────────────────────────────────────────────────
// GetCoachingCue — age-gated coaching language
// ─────────────────────────────────────────────────────────────────────────────
FString UFELEducationEngine::GetCoachingCue(const FString& MovementPattern, EFELAgeGroup AgeGroup) const
{
    const FFELMovementCue* Cue = CueLibrary.Find(MovementPattern);
    if (!Cue) return TEXT("Focus on your breath and keep moving.");
    switch (AgeGroup)
    {
        case EFELAgeGroup::Child: return Cue->CoachingCue_Child;
        case EFELAgeGroup::Teen:  return Cue->CoachingCue_Teen;
        default:                  return Cue->CoachingCue_Adult;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// GetIAPFeedback — tri-register IAP status feedback
// ─────────────────────────────────────────────────────────────────────────────
FString UFELEducationEngine::GetIAPFeedback(bool bStackDetected, EFELAgeGroup AgeGroup) const
{
    if (bStackDetected)
        return TEXT("IAP integrity confirmed — pressure cylinder locked.");

    switch (AgeGroup)
    {
        case EFELAgeGroup::Child:
            return TEXT("Try to keep your tummy balloon firm like a drum!");
        case EFELAgeGroup::Teen:
            return TEXT("Sync your exhale to the peak effort of the lift.");
        default:
            return TEXT("Your IAP stack is leaking; synchronize your diaphragm to the RTN/pFRG kernel to regain resonance.");
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// BroadcastResonanceHUDUpdate — fires delegate
// ─────────────────────────────────────────────────────────────────────────────
void UFELEducationEngine::BroadcastResonanceHUDUpdate(float ResonanceScore, EFELOscillationPhase Phase)
{
    OnResonanceUpdate.Broadcast(ResonanceScore, Phase);
}

// ─────────────────────────────────────────────────────────────────────────────
// GetMovementCue
// ─────────────────────────────────────────────────────────────────────────────
FFELMovementCue UFELEducationEngine::GetMovementCue(const FString& Pattern) const
{
    const FFELMovementCue* Found = CueLibrary.Find(Pattern);
    return Found ? *Found : FFELMovementCue{};
}

// ─────────────────────────────────────────────────────────────────────────────
// PreloadDefaultCues — 12 movement patterns for the Oscillation Literacy system
// ALL SourceState = "demo_synthetic" — never claim PRQ medical truth
// ─────────────────────────────────────────────────────────────────────────────
void UFELEducationEngine::PreloadDefaultCues()
{
    auto Add = [&](
        const TCHAR* Pattern,
        EFELBreathingPattern BPattern,
        float FreqHz,
        bool bIAP,
        const TCHAR* CueC,
        const TCHAR* CueT,
        const TCHAR* CueA,
        const TCHAR* Phase)
    {
        FFELMovementCue Cue;
        Cue.MovementPattern       = Pattern;
        Cue.PrimaryPattern        = BPattern;
        Cue.ResonantFrequencyHz   = FreqHz;
        Cue.IAP_StackRequired     = bIAP;
        Cue.CoachingCue_Child     = CueC;
        Cue.CoachingCue_Teen      = CueT;
        Cue.CoachingCue_Adult     = CueA;
        Cue.MovementPhase         = Phase;
        Cue.SourceState           = TEXT("demo_synthetic");
        CueLibrary.Add(Pattern, Cue);
    };

    // ── Exhale-Stacked patterns (IAP locked on exhale, concentric peak) ──────
    Add(TEXT("squat"),
        EFELBreathingPattern::Exhale_Stacked, 0.30f, true,
        TEXT("Keep balloon firm"),
        TEXT("Exhale at peak effort"),
        TEXT("IAP stack at concentric peak"),
        TEXT("concentric"));

    Add(TEXT("deadlift"),
        EFELBreathingPattern::Exhale_Stacked, 0.25f, true,
        TEXT("Big belly breath before lift"),
        TEXT("Brace and push the floor"),
        TEXT("Valsalva \u2192 RTN/pFRG transition at lockout"),
        TEXT("concentric"));

    Add(TEXT("vertical_jump"),
        EFELBreathingPattern::Exhale_Stacked, 0.50f, true,
        TEXT("Squeeze your tummy and jump!"),
        TEXT("Exhale explode!"),
        TEXT("IAP preload + pFRG burst"),
        TEXT("ballistic"));

    Add(TEXT("pushup"),
        EFELBreathingPattern::Exhale_Stacked, 0.50f, true,
        TEXT("Blow out on the way up"),
        TEXT("Exhale on push"),
        TEXT("IAP lock \u2014 diaphragm stacked on exhale"),
        TEXT("concentric"));

    Add(TEXT("row"),
        EFELBreathingPattern::Exhale_Stacked, 0.40f, true,
        TEXT("Pull and squeeze"),
        TEXT("Exhale as you row"),
        TEXT("Posterior chain activation \u2192 IAP integrity"),
        TEXT("concentric"));

    Add(TEXT("overhead_press"),
        EFELBreathingPattern::Exhale_Stacked, 0.35f, true,
        TEXT("Push the ceiling \u2014 blow out"),
        TEXT("Exhale drives the press"),
        TEXT("IAP stack \u2014 avoid rib flare"),
        TEXT("concentric"));

    Add(TEXT("broad_jump"),
        EFELBreathingPattern::Exhale_Stacked, 0.40f, true,
        TEXT("Swing and jump!"),
        TEXT("Load breath \u2192 explode!"),
        TEXT("Staggered V stance \u2192 IAP preload \u2192 RTN burst"),
        TEXT("ballistic"));

    // ── Rhythmic Oscillation patterns (phasic RTN output — locomotion sync) ─
    Add(TEXT("sprint"),
        EFELBreathingPattern::Rhythmic_Oscillation, 2.00f, false,
        TEXT("Run and hum a rhythm"),
        TEXT("Match your steps to your breath"),
        TEXT("Phasic RTN output \u2014 2-count oscillation"),
        TEXT("concentric"));

    Add(TEXT("lateral_cut"),
        EFELBreathingPattern::Rhythmic_Oscillation, 1.50f, true,
        TEXT("Stay low and breathe"),
        TEXT("Plant foot + exhale"),
        TEXT("Cross-patterned RTN phase coupling"),
        TEXT("concentric"));

    Add(TEXT("rotational_throw"),
        EFELBreathingPattern::Rhythmic_Oscillation, 1.00f, true,
        TEXT("Twist and throw with your tummy tight"),
        TEXT("Wind up \u2192 brace \u2192 release"),
        TEXT("pFRG burst \u2014 rotational momentum transfer"),
        TEXT("ballistic"));

    // ── Sustained Bracing (tonic IAP — isometric holds) ─────────────────────
    Add(TEXT("plank"),
        EFELBreathingPattern::Sustained_Bracing, 0.10f, true,
        TEXT("Make yourself stiff like a plank"),
        TEXT("Slow breathing \u2014 hold the pressure"),
        TEXT("Tonic IAP \u2014 RTN quiet mode"),
        TEXT("isometric"));

    // ── Recovery Rhythm (parasympathetic downregulation) ─────────────────────
    Add(TEXT("recovery_walk"),
        EFELBreathingPattern::Recovery_Rhythm, 0.20f, false,
        TEXT("Nice slow deep breaths"),
        TEXT("Deep belly breaths \u2014 reset"),
        TEXT("RTN parasympathetic downregulation"),
        TEXT("eccentric"));
}
