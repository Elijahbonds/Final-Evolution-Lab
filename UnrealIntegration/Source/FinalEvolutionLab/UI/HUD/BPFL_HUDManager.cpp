// BPFL_HUDManager.cpp

#include "BPFL_HUDManager.h"
#include "FELHudRelaySubsystem.h"
#include "Engine/Engine.h"
#include "Engine/GameInstance.h"
#include "WebBrowser.h"
#include "WebBrowserModule.h"
#include "IWebBrowserSingleton.h"

namespace
{
	UFELHudRelaySubsystem* ResolveHudRelay()
	{
		if (!GEngine)
		{
			return nullptr;
		}
		for (const FWorldContext& Context : GEngine->GetWorldContexts())
		{
			if (Context.WorldType != EWorldType::Game && Context.WorldType != EWorldType::PIE)
			{
				continue;
			}
			if (UGameInstance* GI = Context.OwningGameInstance)
			{
				return GI->GetSubsystem<UFELHudRelaySubsystem>();
			}
		}
		return nullptr;
	}
}

void UBPFL_HUDManager::LoadFELHud(UWebBrowser* WebBrowserWidget, const FString& HudUrl)
{
	if (!WebBrowserWidget)
	{
		return;
	}

	FString Url = HudUrl;
	if (Url.IsEmpty())
	{
		Url = TEXT("http://localhost:3000/hud");
	}
	WebBrowserWidget->LoadURL(Url);
}

void UBPFL_HUDManager::BroadcastHUDMessage(const FString& MessageType, const FString& PayloadJson)
{
	if (UFELHudRelaySubsystem* Relay = ResolveHudRelay())
	{
		Relay->BroadcastMessage(MessageType, PayloadJson);
		return;
	}

	UE_LOG(LogTemp, Warning,
		TEXT("[FEL HUD] BroadcastHUDMessage dropped (no relay subsystem) type=%s payload=%s"),
		*MessageType, *PayloadJson);
}

void UBPFL_HUDManager::SetHUDVisible(UWebBrowser* WebBrowserWidget, bool bVisible)
{
	if (!WebBrowserWidget)
	{
		return;
	}
	WebBrowserWidget->SetVisibility(bVisible ? ESlateVisibility::Visible : ESlateVisibility::Hidden);
}
