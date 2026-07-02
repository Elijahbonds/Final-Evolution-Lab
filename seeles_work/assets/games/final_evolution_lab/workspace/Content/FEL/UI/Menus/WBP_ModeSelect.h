// WBP_ModeSelect.h — 19-mode grid picker
#pragma once
#include "CoreMinimal.h"
#include "CommonActivatableWidget.h"
#include "WBP_ModeSelect.generated.h"

USTRUCT(BlueprintType)
struct FFELModeEntry
{
    GENERATED_BODY()
    UPROPERTY(BlueprintReadOnly) FString ModeId;
    UPROPERTY(BlueprintReadOnly) FString DisplayName;
    UPROPERTY(BlueprintReadOnly) FString VenueId;
    UPROPERTY(BlueprintReadOnly) FString ThumbnailPath;
    UPROPERTY(BlueprintReadOnly) bool bLocked = false;
};

UCLASS()
class FINALEVOLUTIONLAB_API UWBP_ModeSelect : public UCommonActivatableWidget
{
    GENERATED_BODY()
public:
    UPROPERTY(BlueprintReadOnly, Category = "FEL|Modes")
    TArray<FFELModeEntry> ModeEntries;

    /** Called when user taps a mode tile — navigates to WBP_ModeDetail */
    UFUNCTION(BlueprintCallable, Category = "FEL|Menu")
    void OnModeTileSelected(const FString& ModeId);

protected:
    virtual void NativeOnActivated() override;
    void PopulateModeEntries();
};
