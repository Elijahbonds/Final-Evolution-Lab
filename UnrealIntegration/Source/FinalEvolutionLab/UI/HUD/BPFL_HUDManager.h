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
     *  Default page URL is http://localhost:3000/hud (WebBrowser cannot load ws://).
     *  Live updates go through UFELHudRelaySubsystem → backend /ws/hud relay. */
    UFUNCTION(BlueprintCallable, Category = "FEL|HUD")
    static void LoadFELHud(UWebBrowser* WebBrowserWidget, const FString& HudUrl = TEXT("http://localhost:3000/hud"));

    /** Push a HUD frame to the backend /ws/hud relay (legacy type + phase1 event envelope).
     *  Configure relay URL via [FELBackend] HudWebSocketUrl or FEL_HUD_WS_URL. */
    UFUNCTION(BlueprintCallable, Category = "FEL|HUD")
    static void BroadcastHUDMessage(const FString& MessageType, const FString& PayloadJson);

    /** Show / hide the entire HUD overlay. */
    UFUNCTION(BlueprintCallable, Category = "FEL|HUD")
    static void SetHUDVisible(UWebBrowser* WebBrowserWidget, bool bVisible);
};
