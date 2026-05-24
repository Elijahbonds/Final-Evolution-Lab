// Copyright (c) Final Evolution Lab.
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Engine/TimerHandle.h"

#include "FELOverlaySubsystem.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FFELOverlayMessageSignature, FString, Payload);

/**
 * Unified FEL OS overlay: native iOS WKWebView "curtain" above the Unreal viewport.
 *
 * JS -> Native:
 *   window.webkit.messageHandlers.FELBridge.postMessage({ action: "launchGame", modeId: "basketball_h2h" })
 *
 * Native -> JS:
 *   Subsystem->SendJsonToOverlay("{...}")
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELOverlaySubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Overlay")
	FFELOverlayMessageSignature OnOverlayMessageReceived;

	UFUNCTION(BlueprintCallable, Category = "FEL|Overlay")
	void ShowOverlay();

	UFUNCTION(BlueprintCallable, Category = "FEL|Overlay")
	void HideOverlay();

	UFUNCTION(BlueprintCallable, Category = "FEL|Overlay")
	void LoadOverlayUrl(const FString& Url);

	/** Sends raw JS to the overlay (advanced). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Overlay")
	void EvalOverlayJS(const FString& JavaScript);

	/** Sends a JSON object string to overlay as `window.FELNativeReceive(json)` if that function exists. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Overlay")
	void SendJsonToOverlay(const FString& Json);

private:
	void HandleOverlayMessage(const FString& Payload);
	void HandleOverlayJsonObject(const TSharedPtr<class FJsonObject>& Root);
	void PrewarmFromJson(const TSharedPtr<class FJsonObject>& Root);

	UFUNCTION()
	void HandleMapLoaded(FString MapTokenOrName, FString ModeId);

	void TickOverlayHeartbeat();

	FString DashboardUrl;
	FString OverlayBridgeToken;
	FString OverlaySessionId;
	TSet<FString> AllowedDashboardHosts;
	bool bPendingHideOnMapLoad = false;
	FTimerHandle HeartbeatTimer;

	static FString HostFromHttpUrl(const FString& Url);
	void BuildAllowedHosts(TArray<FString>& OutHosts) const;
	bool IsHostAllowedForDashboard(const FString& Url) const;
};

