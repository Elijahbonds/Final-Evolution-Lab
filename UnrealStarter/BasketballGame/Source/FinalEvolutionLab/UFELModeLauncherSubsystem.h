// Copyright (c) Final Evolution Lab.
// Central mode launcher — receives mode selection from app (Pixel Streaming data channel or native bridge),
// loads venue, configures rules, and transitions to gameplay.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELArenaModeDefinitions.h"
#include "UFELModeLauncherSubsystem.generated.h"

class AFELBasketballGameMode;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnFELModeLaunched, EFELArenaMode, Mode, const FString&, ModeKey);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFELModeExited, EFELArenaMode, Mode);

UCLASS()
class FINALEVOLUTIONLAB_API UFELModeLauncherSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** Launch a game mode by string key (from Pixel Streaming data channel or native bridge). */
	UFUNCTION(BlueprintCallable, Category = "FEL|ModeLauncher")
	bool LaunchModeByKey(const FString& ModeKey);

	/** Launch a game mode by enum. */
	UFUNCTION(BlueprintCallable, Category = "FEL|ModeLauncher")
	bool LaunchMode(EFELArenaMode Mode);

	/** Exit current mode and return to lobby / menu. */
	UFUNCTION(BlueprintCallable, Category = "FEL|ModeLauncher")
	void ExitCurrentMode();

	/** Get current active mode. */
	UFUNCTION(BlueprintPure, Category = "FEL|ModeLauncher")
	EFELArenaMode GetCurrentMode() const { return CurrentActiveMode; }

	/** Check if a mode is currently active. */
	UFUNCTION(BlueprintPure, Category = "FEL|ModeLauncher")
	bool IsModeActive() const { return bModeActive; }

	/** Returns all available mode keys for the app UI. */
	UFUNCTION(BlueprintCallable, Category = "FEL|ModeLauncher")
	TArray<FString> GetAllAvailableModeKeys() const;

	/** Returns JSON string of all mode metadata for the streaming frontend. */
	UFUNCTION(BlueprintCallable, Category = "FEL|ModeLauncher")
	FString GetModeManifestJSON() const;

	UPROPERTY(BlueprintAssignable, Category = "FEL|ModeLauncher")
	FOnFELModeLaunched OnModeLaunched;

	UPROPERTY(BlueprintAssignable, Category = "FEL|ModeLauncher")
	FOnFELModeExited OnModeExited;

private:
	EFELArenaMode CurrentActiveMode = EFELArenaMode::Unknown;
	bool bModeActive = false;

	void WriteReadinessSnapshot(const FString& ModeKey);
	void TravelToVenue(const FString& LevelPackage);
};
