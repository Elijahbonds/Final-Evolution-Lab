// Copyright (c) Final Evolution Lab.
// Unreal HTTP client for DeepMotion Animate 3D REST — mirrors Python SDK auth (GET /session/auth + Basic header).
// Do not embed Client ID / Secret in C++; use environment variables (CI / device) or secure vault.

#pragma once

#include "CoreMinimal.h"
#include "HttpModule.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELDeepMotionSessionSubsystem.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFELDeepMotionSessionReady, bool, bSuccess);

/**
 * Session cookie (dmsess) is required for POST /process, GET /upload, etc. (see DeepMotion REST README).
 * Python SDK handles this internally; this subsystem exposes the same first step for native pipelines.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELDeepMotionSessionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;

	/** Reads DEEPMOTION_CLIENT_ID / DEEPMOTION_CLIENT_SECRET from the process environment (set in Xcode scheme or shell). */
	UFUNCTION(BlueprintCallable, Category = "FEL|DeepMotion")
	void RefreshCredentialsFromEnvironment();

	/** GET {ApiHost}/session/auth with Authorization: Basic Base64(clientId:clientSecret). */
	UFUNCTION(BlueprintCallable, Category = "FEL|DeepMotion")
	void RequestSessionAuth();

	UFUNCTION(BlueprintPure, Category = "FEL|DeepMotion")
	bool HasValidSessionCookie() const { return !SessionCookieValue.IsEmpty(); }

	UFUNCTION(BlueprintPure, Category = "FEL|DeepMotion")
	FString GetCookieHeaderValue() const;

	UPROPERTY(BlueprintAssignable, Category = "FEL|DeepMotion")
	FOnFELDeepMotionSessionReady OnSessionAuthComplete;

	/** Default matches Python SDK (dm-animate3d-api). Override if DeepMotion assigns a different host. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|DeepMotion")
	FString ApiHost = TEXT("https://service.deepmotion.com");

protected:
	void OnAuthResponse(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bConnectedSuccessfully);

	UPROPERTY()
	FString ClientId;

	UPROPERTY()
	FString ClientSecret;

	/** Raw Set-Cookie header fragment used for subsequent API calls. */
	UPROPERTY()
	FString SessionCookieValue;
};
