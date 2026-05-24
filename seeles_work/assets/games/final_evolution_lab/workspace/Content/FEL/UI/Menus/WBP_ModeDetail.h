// WBP_ModeDetail.h — Venue hero image, mode description, START MATCH
#pragma once
#include "CoreMinimal.h"
#include "CommonActivatableWidget.h"
#include "WBP_ModeDetail.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UWBP_ModeDetail : public UCommonActivatableWidget
{
    GENERATED_BODY()
public:
    UPROPERTY(BlueprintReadWrite, Category = "FEL|Mode")
    FString SelectedModeId;

    UPROPERTY(BlueprintReadWrite, Category = "FEL|Mode")
    FString SelectedVenueId;

    /** Fire deep link: finalevolution://launch?map={venue}&mode={mode_id}&session={uuid} */
    UFUNCTION(BlueprintCallable, Category = "FEL|Menu")
    void OnStartMatchPressed();

    UFUNCTION(BlueprintCallable, Category = "FEL|Menu")
    void OnBackPressed();

protected:
    virtual void NativeOnActivated() override;

private:
    FString GenerateSessionUUID() const;
};
