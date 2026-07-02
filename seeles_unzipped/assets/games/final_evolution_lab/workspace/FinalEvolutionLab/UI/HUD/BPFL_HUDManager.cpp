// BPFL_HUDManager.cpp

#include "BPFL_HUDManager.h"
#include "WebBrowser.h"
#include "WebBrowserModule.h"
#include "IWebBrowserSingleton.h"

void UBPFL_HUDManager::LoadFELHud(UWebBrowser* WebBrowserWidget, const FString& HudUrl)
{
    if (!WebBrowserWidget) return;
    WebBrowserWidget->LoadURL(HudUrl);
}

void UBPFL_HUDManager::BroadcastHUDMessage(const FString& MessageType, const FString& PayloadJson)
{
    // In a full implementation this sends via the backend WS relay.
    // For in-process use, execute JS in the browser widget directly.
    UE_LOG(LogTemp, Log, TEXT("[FEL HUD] BroadcastHUDMessage type=%s payload=%s"), *MessageType, *PayloadJson);
}

void UBPFL_HUDManager::SetHUDVisible(UWebBrowser* WebBrowserWidget, bool bVisible)
{
    if (!WebBrowserWidget) return;
    WebBrowserWidget->SetVisibility(bVisible ? ESlateVisibility::Visible : ESlateVisibility::Hidden);
}
