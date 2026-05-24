// BPFL_HUDManager.h — Blueprint Function Library
// Manages the WebBrowserWidget overlay for FEL HUD
// Calls LoadURL to point the WebBrowserWidget at the React FELHud bundle.

#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "BPFL_HUDManager.generated.h"

class UWebBrowser;

UCLASS()
class FINALEVOLUTIONLAB_API UBPFL_HUDManager : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    /** Load the React FEL HUD overlay into a WebBrowserWidget.
     *  URL defaults to the local HUD dev server (ws://localhost:8080/ws/hud).
     *  In shipping builds, point this at the bundled HTML asset. */
    UFUNCTION(BlueprintCallable, Category = "FEL|HUD")
    static void LoadFELHud(UWebBrowser* WebBrowserWidget, const FString& HudUrl = TEXT("http://localhost:3000/hud"));

    /** Send a JSON message to the HUD WebSocket server from C++.
     *  Used by gameplay subsystems to push score/economy/MRI updates. */
    UFUNCTION(BlueprintCallable, Category = "FEL|HUD")
    static void BroadcastHUDMessage(const FString& MessageType, const FString& PayloadJson);

    /** Show / hide the entire HUD overlay. */
    UFUNCTION(BlueprintCallable, Category = "FEL|HUD")
    static void SetHUDVisible(UWebBrowser* WebBrowserWidget, bool bVisible);
};
