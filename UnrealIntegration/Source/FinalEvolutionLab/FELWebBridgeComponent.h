// Copyright (c) Final Evolution Lab.
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "FELWebBridgeComponent.generated.h"

/**
 * Parsed payload containing the fields from Creator Cards / WebView token.
 */
USTRUCT(BlueprintType)
struct FFELWebBridgeTokenPayload
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|WebBridge")
	TArray<FString> CreatorCardIds;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|WebBridge")
	float VerticalDisplacement = 0.0f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|WebBridge")
	TArray<FString> MovementCues;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|WebBridge")
	FString RawJson;
};

// Blueprint Assignable Delegate for gameplay systems to react to token payload
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FFELWebBridgeTokenReceivedSignature, const FFELWebBridgeTokenPayload&, Payload);

/**
 * Custom Actor Component UFELWebBridgeComponent
 * Interfaces with Unreal's WebBrowser (CEF) and native iOS WKWebView via FELOverlaySubsystem.
 * Exposes 'sendTokenToUnreal' to Javascript.
 */
UCLASS(ClassGroup=(Custom), meta=(BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELWebBridgeComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UFELWebBridgeComponent();

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

public:
	/** Broadcast when a token is received and successfully parsed from JS / WKWebView */
	UPROPERTY(BlueprintAssignable, Category = "FEL|WebBridge")
	FFELWebBridgeTokenReceivedSignature OnTokenReceived;

	/**
	 * JavaScript binding entry point: window.ue.felbridge.sendtokentounreal(jsonPayload)
	 * Automatically handles camelCase conversion on the JS side and redirects on iOS.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|WebBridge")
	void sendTokenToUnreal(const FString& jsonPayload);

	/**
	 * Binds this UObject component instance to a UWebBrowser widget instance.
	 * Registers under the javascript binding name "felbridge".
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|WebBridge")
	void BindToWebBrowserWidget(class UWebBrowser* WebBrowserWidget);

private:
	/** Handler to receive routed WKWebView messages from the FELOverlaySubsystem */
	UFUNCTION()
	void HandleOverlayMessage(FString Payload);

	/** Reference to the bound WebBrowser widget (held for GC protection) */
	UPROPERTY()
	TObjectPtr<class UWebBrowser> BoundWebBrowserWidget;
};
