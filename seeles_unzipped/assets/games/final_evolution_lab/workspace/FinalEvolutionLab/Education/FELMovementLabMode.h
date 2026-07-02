// FELMovementLabMode.h — Movement Lab / Anatomy Academy
// Interactive education space: 8 sections, source-type labeling, no PRQ medical truth claims
// EDUCATION DEMO label required for DemoSynthetic content
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELMovementLabMode.generated.h"

// ─── Source Type Enum ────────────────────────────────────────────────
UENUM(BlueprintType)
enum class EFELAnatomySourceType : uint8
{
    // MUST show "EDUCATION DEMO" label in UI — never claim PRQ medical truth
    DemoSynthetic           UMETA(DisplayName="Education Demo"),
    HealthKitReadiness      UMETA(DisplayName="HealthKit Readiness"),
    MeasuredPose            UMETA(DisplayName="Measured Pose"),
    MeasuredLumaOrARKit     UMETA(DisplayName="Measured (Luma/ARKit)"),
    VerifiedAssessment      UMETA(DisplayName="Verified Assessment")
};

// ─── Education Section Enum ──────────────────────────────────────────
UENUM(BlueprintType)
enum class EFELEducationSection : uint8
{
    AnatomyExplorer             UMETA(DisplayName="Anatomy Explorer"),
    BiomechanicsDemo            UMETA(DisplayName="Biomechanics Demo"),
    IAPCorsetViz                UMETA(DisplayName="IAP Corset Visualization"),
    KineticLeakageViz           UMETA(DisplayName="Kinetic Leakage Visualization"),
    CorePelvisRibHipEducation   UMETA(DisplayName="Core / Pelvis / Rib / Hip Education"),
    MovementSnackArea           UMETA(DisplayName="Movement Snack Presentation"),
    AssessmentQuiz              UMETA(DisplayName="Assessment Quiz"),
    WorkoutPlanLink             UMETA(DisplayName="Workout Plan Link")
};

// ─── Anatomy Node ────────────────────────────────────────────────────
USTRUCT(BlueprintType)
struct FINALEVOLUTIONLAB_API FFELAnatomyNode
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadWrite) FString NodeId;
    UPROPERTY(BlueprintReadWrite) FString BodyRegion;   // e.g. "Pelvis", "Ribcage", "Hip"
    UPROPERTY(BlueprintReadWrite) FString EducationText;
    UPROPERTY(BlueprintReadWrite) FString AudioCueAsset;
    UPROPERTY(BlueprintReadWrite) bool bIsAthleteSpecific = false;
    UPROPERTY(BlueprintReadWrite) EFELAnatomySourceType SourceType = EFELAnatomySourceType::DemoSynthetic;
};

// ─── Quiz Question ───────────────────────────────────────────────────
USTRUCT(BlueprintType)
struct FINALEVOLUTIONLAB_API FFELEducationQuizQuestion
{
    GENERATED_BODY()
    UPROPERTY(BlueprintReadWrite) FString QuestionId;
    UPROPERTY(BlueprintReadWrite) FString QuestionText;
    UPROPERTY(BlueprintReadWrite) TArray<FString> Choices;
    UPROPERTY(BlueprintReadWrite) int32 CorrectIndex = 0;   // local-correct for education (not economy-gated)
    UPROPERTY(BlueprintReadWrite) FString Explanation;
};

// ─── Progress Summary ────────────────────────────────────────────────
USTRUCT(BlueprintType)
struct FINALEVOLUTIONLAB_API FFELMovementLabProgress
{
    GENERATED_BODY()
    UPROPERTY(BlueprintReadWrite) TArray<EFELEducationSection> CompletedSections;
    UPROPERTY(BlueprintReadWrite) int32 QuizScore = 0;
    UPROPERTY(BlueprintReadWrite) int32 QuizAttempts = 0;
    UPROPERTY(BlueprintReadWrite) FString WorkoutPlanId;   // linked via WorkoutPlanLink section
    UPROPERTY(BlueprintReadWrite) bool bWorkoutPlanLinked = false;
};

// ─── Subsystem ───────────────────────────────────────────────────────
UCLASS()
class FINALEVOLUTIONLAB_API UFELMovementLabMode : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;
    virtual void Deinitialize() override;

    // ── Section Navigation ───────────────────────────────────────────
    UFUNCTION(BlueprintCallable, Category="FEL|MovementLab")
    void EnterSection(EFELEducationSection Section);

    UFUNCTION(BlueprintCallable, Category="FEL|MovementLab")
    void ExitSection(EFELEducationSection Section);

    UFUNCTION(BlueprintCallable, Category="FEL|MovementLab")
    void MarkSectionComplete(EFELEducationSection Section);

    // ── Anatomy Explorer ─────────────────────────────────────────────
    UFUNCTION(BlueprintCallable, Category="FEL|MovementLab|Anatomy")
    TArray<FFELAnatomyNode> GetAnatomyNodesForRegion(const FString& BodyRegion) const;

    UFUNCTION(BlueprintCallable, Category="FEL|MovementLab|Anatomy")
    FString GetSourceTypeLabel(EFELAnatomySourceType SourceType) const;

    // ── Quiz ─────────────────────────────────────────────────────────
    UFUNCTION(BlueprintCallable, Category="FEL|MovementLab|Quiz")
    FFELEducationQuizQuestion GetNextQuizQuestion();

    UFUNCTION(BlueprintCallable, Category="FEL|MovementLab|Quiz")
    bool SubmitQuizAnswer(const FString& QuestionId, int32 AnswerIndex);

    // ── Workout Plan ─────────────────────────────────────────────────
    UFUNCTION(BlueprintCallable, Category="FEL|MovementLab|Workout")
    void LinkWorkoutPlan(const FString& WorkoutPlanId);

    // ── Progress ─────────────────────────────────────────────────────
    UFUNCTION(BlueprintCallable, Category="FEL|MovementLab")
    FFELMovementLabProgress GetProgressSummary() const;

    // ── Delegates ────────────────────────────────────────────────────
    DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnSectionEntered, EFELEducationSection, Section);
    DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnSectionCompleted, EFELEducationSection, Section);
    DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnQuizAnswered, bool, bCorrect, FString, Explanation);

    UPROPERTY(BlueprintAssignable) FOnSectionEntered OnSectionEntered;
    UPROPERTY(BlueprintAssignable) FOnSectionCompleted OnSectionCompleted;
    UPROPERTY(BlueprintAssignable) FOnQuizAnswered OnQuizAnswered;

private:
    TArray<FFELAnatomyNode> AnatomyNodes;
    TArray<FFELEducationQuizQuestion> QuizQuestions;
    FFELMovementLabProgress Progress;
    EFELEducationSection ActiveSection = EFELEducationSection::AnatomyExplorer;
    int32 QuizQuestionCursor = 0;

    void SeedAnatomyNodes();
    void SeedQuizQuestions();
};
