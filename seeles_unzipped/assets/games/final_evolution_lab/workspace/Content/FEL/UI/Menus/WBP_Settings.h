// WBP_Settings.h — Audio, haptics, and FELFeatureFlags settings
#pragma once
#include "CoreMinimal.h"
#include "CommonActivatableWidget.h"
#include "WBP_Settings.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UWBP_Settings : public UCommonActivatableWidget
{
    GENERATED_BODY()
public:
    /** BGM volume 0.0–1.0, persisted to SaveGame */
    UPROPERTY(BlueprintReadWrite, Category = "FEL|Settings")
    float BGMVolume = 1.0f;

    /** SFX volume 0.0–1.0, persisted to SaveGame */
    UPROPERTY(BlueprintReadWrite, Category = "FEL|Settings")
    float SFXVolume = 1.0f;

    /** Haptic feedback on/off */
    UPROPERTY(BlueprintReadWrite, Category = "FEL|Settings")
    bool bHapticsEnabled = true;

    /** FELFeatureFlags.enableNeurocognitiveEngine — default false per spec */
    UPROPERTY(BlueprintReadWrite, Category = "FEL|Settings")
    bool bNeurocognitiveEngineEnabled = false;

    UFUNCTION(BlueprintCallable, Category = "FEL|Menu")
    void ApplySettings();

    UFUNCTION(BlueprintCallable, Category = "FEL|Menu")
    void ResetToDefaults();

protected:
    virtual void NativeOnActivated() override;
    void LoadSavedSettings();
    void PersistSettings();
};
