// WBP_MainMenu.h — CommonUI activatable widget for Main Menu
#pragma once
#include "CoreMinimal.h"
#include "CommonActivatableWidget.h"
#include "WBP_MainMenu.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UWBP_MainMenu : public UCommonActivatableWidget
{
    GENERATED_BODY()
public:
    /** Navigate to Mode Select screen */
    UFUNCTION(BlueprintCallable, Category = "FEL|Menu")
    void OnPlayPressed();

    /** Navigate to Market Browse screen */
    UFUNCTION(BlueprintCallable, Category = "FEL|Menu")
    void OnMarketPressed();

    /** Navigate to Profile screen */
    UFUNCTION(BlueprintCallable, Category = "FEL|Menu")
    void OnProfilePressed();

protected:
    virtual void NativeOnActivated() override;
};
