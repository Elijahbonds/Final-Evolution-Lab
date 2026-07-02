// FELAnatomyExplorer.h
// Interactive 3D Anatomy Academy — Education Module
// Separates: general education vs athlete-specific scan findings vs demo/synthetic
// CRITICAL: bIsAthleteSpecific=false on all default callouts.
//           Never imply biomechanical diagnosis unless SourceState="verified_assessment".
#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FELAnatomyExplorer.generated.h"

// ─────────────────────────────────────────────────────────────────────────────
// Anatomy Layer Enum — 6 primary education systems
// ─────────────────────────────────────────────────────────────────────────────
UENUM(BlueprintType)
enum class EFELAnatomyLayer : uint8
{
    IAP_Corset   UMETA(DisplayName = "IAP Pressure Cylinder"),
    Diaphragm    UMETA(DisplayName = "Diaphragm / RTN-pFRG"),
    PelvicFloor  UMETA(DisplayName = "Pelvic Floor"),
    RibCage      UMETA(DisplayName = "Rib Cage / Kinetic Anchor"),
    HipComplex   UMETA(DisplayName = "Hip Complex"),
    KineticChain UMETA(DisplayName = "Full Kinetic Chain")
};

// ─────────────────────────────────────────────────────────────────────────────
// Anatomy Callout Data
// ─────────────────────────────────────────────────────────────────────────────
USTRUCT(BlueprintType)
struct FINALEVOLUTIONLAB_API FFELAnatomyCallout
{
    GENERATED_BODY()

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Anatomy")
    EFELAnatomyLayer Layer = EFELAnatomyLayer::IAP_Corset;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Anatomy")
    FString Title;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Anatomy")
    FString Description;

    /**
     * Source classification — UI must show "EDUCATION DEMO" badge for demo_synthetic.
     * Values: "demo_synthetic" | "healthkit_readiness" | "measured_pose" |
     *         "measured_luma_or_arkit" | "verified_assessment"
     */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Anatomy")
    FString SourceState = TEXT("demo_synthetic");

    /**
     * If true, this callout is derived from athlete scan data.
     * MUST be false for all default callouts.
     * Only Antigravity/backend can set this to true with verified data.
     */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category="FEL|Anatomy")
    bool bIsAthleteSpecific = false;
};

// ─────────────────────────────────────────────────────────────────────────────
// Anatomy Layer Selection Delegate
// ─────────────────────────────────────────────────────────────────────────────
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(
    FFELOnAnatomyLayerSelected,
    EFELAnatomyLayer, Layer);

// ─────────────────────────────────────────────────────────────────────────────
// AFELAnatomyExplorer — Interactive 3D Education Space Actor
// ─────────────────────────────────────────────────────────────────────────────
UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API AFELAnatomyExplorer : public AActor
{
    GENERATED_BODY()

public:
    AFELAnatomyExplorer();

    // ── State ────────────────────────────────────────────────────────────────

    /**
     * Callout library pre-populated with 6 anatomy layer definitions.
     * All default to demo_synthetic + bIsAthleteSpecific=false.
     */
    UPROPERTY(BlueprintReadOnly, Category="FEL|Anatomy")
    TMap<EFELAnatomyLayer, FFELAnatomyCallout> CalloutLibrary;

    /**
     * If true, all content is demo/general education.
     * If false, athlete-specific scan data may be displayed when AthleteId is set.
     */
    UPROPERTY(EditDefaultsOnly, BlueprintReadWrite, Category="FEL|Anatomy")
    bool bEducationMode = true;

    /**
     * Athlete ID for scan-specific callout override.
     * Empty string = no athlete context = always demo_synthetic.
     */
    UPROPERTY(BlueprintReadWrite, Category="FEL|Anatomy")
    FString AthleteId;

    /** Fires when player selects or focuses an anatomy layer */
    UPROPERTY(BlueprintAssignable, Category="FEL|Anatomy")
    FFELOnAnatomyLayerSelected OnAnatomyLayerSelected;

    // ── Interaction API ──────────────────────────────────────────────────────

    /** Activates post-process highlight on the selected anatomy layer */
    UFUNCTION(BlueprintCallable, Category="FEL|Anatomy")
    void HighlightLayer(EFELAnatomyLayer Layer);

    /** Returns the callout for a layer (or default empty callout if not found) */
    UFUNCTION(BlueprintPure, Category="FEL|Anatomy")
    FFELAnatomyCallout ShowCallout(EFELAnatomyLayer Layer) const;

    /** Triggers a Movement Snack education mini-clip by ID */
    UFUNCTION(BlueprintCallable, Category="FEL|Anatomy")
    void TriggerMovementSnack(const FString& SnackId);

    /** Activates IAP corset ring overlay visualization */
    UFUNCTION(BlueprintCallable, Category="FEL|Anatomy")
    void ShowIAPCorsetVisualization();

    /**
     * Places a kinetic leakage marker at a world position.
     * @param WorldLocation  Location of the joint/segment with leakage
     * @param LeakageType    e.g. "rib_flare" | "anterior_tilt" | "valgus_collapse"
     */
    UFUNCTION(BlueprintCallable, Category="FEL|Anatomy")
    void ShowKineticLeakageMarker(FVector WorldLocation, const FString& LeakageType);

    /**
     * "Replace the Up with the Down" — posterior pelvic tuck education moment.
     * Activates tuck cue visualization overlay.
     * SourceState: demo_synthetic. Not a diagnosis.
     */
    UFUNCTION(BlueprintCallable, Category="FEL|Anatomy")
    void ShowTuckEducationMoment();

    /**
     * Staggered V stance education — rear-foot external rotation + front-knee alignment.
     * SourceState: demo_synthetic.
     */
    UFUNCTION(BlueprintCallable, Category="FEL|Anatomy")
    void ShowStaggeredVStance();

    /**
     * Rear-leg internal rotation cue — hip-knee-ankle alignment for force transfer.
     * SourceState: demo_synthetic.
     */
    UFUNCTION(BlueprintCallable, Category="FEL|Anatomy")
    void ShowRearLegRotationCue();

    /** Returns explorer to default neutral anatomy view */
    UFUNCTION(BlueprintCallable, Category="FEL|Anatomy")
    void ResetToDefaultView();

private:
    void BuildDefaultCalloutLibrary();
};
