// Copy into your game's Source/FinalEvolutionLab/ module alongside FELEmergentBridgeSubsystem.
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Engine/TimerHandle.h"

#include "FELEmergentDeepLinkSubsystem.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FFELMapLoadedSignature, FString, MapToken, FString, ModeId);

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

	/**
	 * Dashboard / WebSocket “Play Now”: resolve Emergent button id or native arena_mode (e.g. basketball_dunk) to a cooked map.
	 * OptionalExplicitPackagePath — full /Game/FEL/Venues/... path if the server sends it directly.
	 */
	UFUNCTION(BlueprintCallable, Category = "Emergent|DeepLink")
	void RequestPlayFromEmergent(
		const FString& ButtonOrModeKey,
		const FString& OptionalExplicitPackagePath,
		const FString& OptionalArenaGameMode);

	UPROPERTY(BlueprintAssignable, Category = "Emergent|DeepLink")
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
	void ReloadEmergentPlayMapsFromIni();
	void ReloadEmergentButtonArenaModesFromIni();

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

	/** [EmergentPlayMap] keys from DefaultGame.ini (dashboard button ids + aliases). */
	TMap<FString, FString> EmergentPlayMapIni;

	/** [EmergentButtonArenaMode] optional: dashboard button -> native arena_game_mode_id (e.g. basketball_dunk). */
	TMap<FString, FString> EmergentButtonArenaModeIni;
};
