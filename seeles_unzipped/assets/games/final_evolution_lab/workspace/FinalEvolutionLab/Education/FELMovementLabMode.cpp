// FELMovementLabMode.cpp — Movement Lab / Anatomy Academy Implementation
#include "FELMovementLabMode.h"

// ─── Initialize ──────────────────────────────────────────────────────
void UFELMovementLabMode::Initialize(FSubsystemCollectionBase& Collection)
{
    Super::Initialize(Collection);
    SeedAnatomyNodes();
    SeedQuizQuestions();
}

void UFELMovementLabMode::Deinitialize()
{
    Super::Deinitialize();
}

// ─── Source Type Label Injection ─────────────────────────────────────
// DemoSynthetic content MUST show "EDUCATION DEMO" in UI — never claim PRQ medical truth
FString UFELMovementLabMode::GetSourceTypeLabel(EFELAnatomySourceType SourceType) const
{
    switch (SourceType)
    {
    case EFELAnatomySourceType::DemoSynthetic:
        return TEXT("EDUCATION DEMO");
    case EFELAnatomySourceType::HealthKitReadiness:
        return TEXT("HealthKit Readiness");
    case EFELAnatomySourceType::MeasuredPose:
        return TEXT("Measured Pose");
    case EFELAnatomySourceType::MeasuredLumaOrARKit:
        return TEXT("Measured (Luma/ARKit)");
    case EFELAnatomySourceType::VerifiedAssessment:
        return TEXT("Verified Assessment");
    default:
        return TEXT("EDUCATION DEMO");
    }
}

// ─── Section Navigation ──────────────────────────────────────────────
void UFELMovementLabMode::EnterSection(EFELEducationSection Section)
{
    ActiveSection = Section;
    OnSectionEntered.Broadcast(Section);
}

void UFELMovementLabMode::ExitSection(EFELEducationSection Section)
{
    // Persist partial progress; full credit on MarkSectionComplete
}

void UFELMovementLabMode::MarkSectionComplete(EFELEducationSection Section)
{
    if (!Progress.CompletedSections.Contains(Section))
    {
        Progress.CompletedSections.Add(Section);
        OnSectionCompleted.Broadcast(Section);
    }
}

// ─── Anatomy Explorer ────────────────────────────────────────────────
TArray<FFELAnatomyNode> UFELMovementLabMode::GetAnatomyNodesForRegion(const FString& BodyRegion) const
{
    return AnatomyNodes.FilterByPredicate([&](const FFELAnatomyNode& N){
        return N.BodyRegion.Equals(BodyRegion, ESearchCase::IgnoreCase);
    });
}

// ─── Quiz ────────────────────────────────────────────────────────────
FFELEducationQuizQuestion UFELMovementLabMode::GetNextQuizQuestion()
{
    if (QuizQuestions.Num() == 0) return {};
    const FFELEducationQuizQuestion& Q = QuizQuestions[QuizQuestionCursor % QuizQuestions.Num()];
    QuizQuestionCursor++;
    return Q;
}

bool UFELMovementLabMode::SubmitQuizAnswer(const FString& QuestionId, int32 AnswerIndex)
{
    Progress.QuizAttempts++;

    const FFELEducationQuizQuestion* Q = QuizQuestions.FindByPredicate([&](const FFELEducationQuizQuestion& Q){
        return Q.QuestionId == QuestionId;
    });

    if (!Q) return false;

    bool bCorrect = (AnswerIndex == Q->CorrectIndex);
    if (bCorrect) Progress.QuizScore += 100;

    OnQuizAnswered.Broadcast(bCorrect, Q->Explanation);
    return bCorrect;
}

// ─── Workout Plan Link ───────────────────────────────────────────────
void UFELMovementLabMode::LinkWorkoutPlan(const FString& WorkoutPlanId)
{
    Progress.WorkoutPlanId = WorkoutPlanId;
    Progress.bWorkoutPlanLinked = true;
    MarkSectionComplete(EFELEducationSection::WorkoutPlanLink);
    // Handoff to backend: POST /api/athlete/workout_plan_link with { plan_id: WorkoutPlanId }
}

// ─── Progress Summary ────────────────────────────────────────────────
FFELMovementLabProgress UFELMovementLabMode::GetProgressSummary() const
{
    return Progress;
}

// ─── Seed Anatomy Nodes ──────────────────────────────────────────────
void UFELMovementLabMode::SeedAnatomyNodes()
{
    // All seeded as DemoSynthetic — label "EDUCATION DEMO" in UI
    // Athlete-specific nodes set bIsAthleteSpecific=true only when source is Measured/Verified

    AnatomyNodes.Add({"an_iap_01", "Core", "IAP Corset: diaphragm, pelvic floor, TVA, and multifidus create intra-abdominal pressure.",
        TEXT(""), false, EFELAnatomySourceType::DemoSynthetic});

    AnatomyNodes.Add({"an_iap_02", "Core", "Replace the Up with the Down: breathe out and tuck the pelvis to engage IAP correctly.",
        TEXT(""), false, EFELAnatomySourceType::DemoSynthetic});

    AnatomyNodes.Add({"an_pelvis_01", "Pelvis", "Staggered V Stance: feet shoulder-width, slight toe-out, rear-leg internal rotation cue.",
        TEXT(""), false, EFELAnatomySourceType::DemoSynthetic});

    AnatomyNodes.Add({"an_hip_01", "Hip", "Rear-leg internal rotation activates glute medius for lateral stability.",
        TEXT(""), false, EFELAnatomySourceType::DemoSynthetic});

    AnatomyNodes.Add({"an_ribcage_01", "Ribcage", "Ribcage depression during exhalation engages intercostals and improves IAP.",
        TEXT(""), false, EFELAnatomySourceType::DemoSynthetic});

    AnatomyNodes.Add({"an_kl_01", "KineticChain", "Kinetic leakage occurs when force escapes through weak IAP — visible as trunk collapse during sprint.",
        TEXT(""), false, EFELAnatomySourceType::DemoSynthetic});

    AnatomyNodes.Add({"an_ms_01", "MovementSnack", "Movement Snack: 2-minute IAP activation drill — inhale through nose, brace core, exhale slowly.",
        TEXT(""), false, EFELAnatomySourceType::DemoSynthetic});
}

// ─── Seed Quiz Questions ─────────────────────────────────────────────
void UFELMovementLabMode::SeedQuizQuestions()
{
    QuizQuestions.Add({"eq_01",
        "Which four structures form the IAP corset?",
        {"Diaphragm, pelvic floor, TVA, multifidus",
         "Rectus abdominis, obliques, lats, traps",
         "Hip flexors, glutes, hamstrings, quads",
         "Erector spinae, rhomboids, serratus, pecs"},
        0,
        "The IAP corset is formed by: diaphragm (top), pelvic floor (bottom), transverse abdominis (front), and multifidus (back)."
    });

    QuizQuestions.Add({"eq_02",
        "What does 'kinetic leakage' describe in movement science?",
        {"Energy lost as heat during exercise",
         "Force escaping through a weak IAP or unstable joint",
         "Muscle fatigue during sustained contraction",
         "Blood flow restriction during isometric holds"},
        1,
        "Kinetic leakage = force escaping through a structurally weak point (often collapsed IAP), reducing transfer efficiency."
    });

    QuizQuestions.Add({"eq_03",
        "In the Staggered V Stance, what cue activates the rear-leg glute medius?",
        {"Toe-in the rear foot",
         "Internal rotation of the rear leg",
         "Externally rotating both feet",
         "Locking the rear knee"},
        1,
        "Rear-leg internal rotation engages glute medius, improving lateral stability in athletic stance."
    });
}
