// Copy into your game's Source/FinalEvolutionLab/ module alongside FELEmergentBridgeSubsystem.
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Engine/TimerHandle.h"

#include "FELEmergentDeepLinkSubsystem.generated.h"

/**
 * Handles finalevolution:// deep links (iOS URL scheme) and coordinates map travel + Emergent WebSocket feedback.
 * Pair with DefaultEngine.FEL_iOS_URL_scheme.snippet.ini (CFBundleURLTypes) and Pixel Streaming / local WS on 8888.
 */
UCLASS()
class UFELEmergentDeepLinkSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** Parse and act on a full URL (e.g. finalevolution://launch?map=Zen_Dojo&mode=karate_h2h). Callable from Blueprint tests. */
	UFUNCTION(BlueprintCallable, Category = "Emergent|DeepLink")
	void ProcessDeepLinkUrl(const FString& Url);

private:
	void BindDelegates();
	void UnbindDelegates();

	void OnStartupArguments(const TArray<FString>& Args);
	void OnPostEngineInit();
	void OnPostLoadMapWithWorld(UWorld* World);

	void TryConsumeLaunchURL();
	void OpenMapFromTokens(const FString& MapToken, const FString& ModeId);
	void TryDeferredOpenLevel();
	static FString ResolveModeToMapToken(const FString& ModeId);
	static void ParseQueryString(const FString& Query, TMap<FString, FString>& OutParams);
	static FString StripSchemeAndHost(const FString& Url);
	static FString PackagePathFromMapToken(const FString& MapToken);

	FDelegateHandle StartupArgumentsHandle;
	FDelegateHandle PostLoadMapHandle;

	FString LastRequestedMapToken;
	FString LastRequestedModeId;

	FString PendingOpenPackage;
	FTimerHandle DeferredOpenTimer;
	FTimerHandle RetryLaunchUrlTimer;
	int32 DeferredOpenAttempts = 0;
};
