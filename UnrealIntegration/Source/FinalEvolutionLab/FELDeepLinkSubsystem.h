// Copy into your game's Source/FinalEvolutionLab/ module alongside FELFELBridgeSubsystem.
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Engine/TimerHandle.h"

#include "FELDeepLinkSubsystem.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FFELMapLoadedSignature, FString, MapToken, FString, ModeId);

/**
 * Handles finalevolution:// deep links (iOS URL scheme) and coordinates map travel + FELBridge WebSocket feedback.
 * Pair with DefaultEngine.FEL_iOS_URL_scheme.snippet.ini (CFBundleURLTypes) and Pixel Streaming / local WS on 8888.
 */
UCLASS()
class UFELDeepLinkSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/**
	 * Parses and processes a deep link URL (e.g. finalevolution://launch?map=Zen_Dojo&mode=karate_h2h).
	 * Triggers level load travel if the scheme is valid.
	 *
	 * @param Url The raw deep link URL to parse and process.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|DeepLink")
	void ProcessDeepLinkUrl(const FString& Url);

	/**
	 * Requests map travel from the FEL dashboard or play button. Resolves the play key / mode
	 * to a packaged package path and initiates the travel sequence.
	 *
	 * @param ButtonOrModeKey The logical dashboard button key or game mode key.
	 * @param OptionalExplicitPackagePath An optional explicit asset package path (/Game/FEL/Venues/...) to load.
	 * @param OptionalArenaGameMode The target arena game mode ID to configure.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|DeepLink")
	void RequestPlayFromFEL(
		const FString& ButtonOrModeKey,
		const FString& OptionalExplicitPackagePath,
		const FString& OptionalArenaGameMode);

	/** Delegate broadcasted when a map finishes loading and registers with the deep link subsystem. */
	UPROPERTY(BlueprintAssignable, Category = "FEL|DeepLink")
	FFELMapLoadedSignature OnFELMapLoaded;

private:
	void BindDelegates();
	void UnbindDelegates();

	void OnStartupArguments(const TArray<FString>& Args);
	void OnPostLoadMapWithWorld(UWorld* World);

	void TryConsumeLaunchURL();
	void OpenMapFromTokens(const FString& MapPackagePath, const FString& ModeId);
	void TryDeferredOpenLevel();
	static FString ResolveModeToMapToken(const FString& ModeId);
	void ReloadFELPlayMapsFromIni();
	void ReloadFELButtonArenaModesFromIni();

	FString ResolvePackagePathForPlayKey(const FString& MapOrButtonKey) const;
	FString ResolveArenaModeForButton(const FString& ButtonKey, const FString& FallbackModeHint) const;
	static void ParseQueryString(const FString& Query, TMap<FString, FString>& OutParams);
	static FString StripSchemeAndHost(const FString& Url);
	FDelegateHandle StartupArgumentsHandle;
	FDelegateHandle PostLoadMapHandle;

	FString LastRequestedMapToken;
	FString LastRequestedModeId;

	FString PendingOpenPackage;
	FString PendingOpenOptions;
	FTimerHandle DeferredOpenTimer;
	FTimerHandle RetryLaunchUrlTimer;
	int32 DeferredOpenAttempts = 0;

	/** [FELPlayMap] keys from DefaultGame.ini (dashboard button ids + aliases). */
	TMap<FString, FString> FELPlayMapIni;

	/** [FELButtonArenaMode] optional: dashboard button -> native arena_game_mode_id (e.g. basketball_dunk). */
	TMap<FString, FString> FELButtonArenaModeIni;
};
