// Copyright (c) Final Evolution Lab.
// Retail application shell: startup flow, profile save, quit, scalability presets.

#pragma once

#include "CoreMinimal.h"
#include "Engine/GameInstance.h"
#include "FELArenaModeDefinitions.h"
#include "UFELGameInstance.generated.h"

class AFELBasketballGameMode;
class UFELPlayerProfileSave;

UENUM(BlueprintType)
enum class EFELRetailStartupPhase : uint8
{
	None,
	Splash,
	MainMenu,
	Complete
};

/**
 * GameInstance for packaged / PS5-tier flow: splash → menu → arena, persistent profile, clean exit.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELGameInstance : public UGameInstance
{
	GENERATED_BODY()

public:
	virtual void Init() override;
	virtual void Shutdown() override;

	UFUNCTION(BlueprintCallable, Category = "FEL|Retail")
	UFELPlayerProfileSave* GetPlayerProfile() const { return PlayerProfile.Get(); }

	UFUNCTION(BlueprintCallable, Category = "FEL|Retail")
	void SavePlayerProfile();

	/** Apply profile + GameUserSettings to disk (GameUserSettings.ini). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Retail")
	void PersistUserSettingsAndProfile();

	UFUNCTION(BlueprintCallable, Category = "FEL|Retail")
	FString GetPreferredArenaModeId() const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Retail")
	void SetPreferredArenaFromMode(EFELArenaMode Mode);

	/** Called when a match ends with a new best bucket count. */
	void MaybeUpdateHighScore(int32 BucketScore);

	/** Splash + main menu before first match (skipped in PIE if disabled). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Retail")
	bool ShouldShowRetailStartup() const;

	/** GameMode calls this at end of StartPlay when startup is needed. */
	void BeginRetailStartupFlow(APlayerController* PC, AFELBasketballGameMode* GameMode);

	UFUNCTION(BlueprintCallable, Category = "FEL|Retail")
	void OnRetailStartupPlaySelected();

	UFUNCTION(BlueprintCallable, Category = "FEL|Retail")
	void OnRetailStartupQuitSelected();

	/** Quality vs Performance — persists via profile + GameUserSettings. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Retail|Graphics")
	void ApplyQualityPreset(bool bPerformanceMode);

	UFUNCTION(BlueprintPure, Category = "FEL|Retail|Graphics")
	bool IsPerformanceModePreferred() const;

	/** End session gracefully: save profile, optional last_session flush. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Retail")
	void RequestQuitToDesktop(bool bFlushSessionSnapshot = true);

	EFELRetailStartupPhase GetStartupPhase() const { return StartupPhase; }

	/** Called after UFELPlatformManager applies platform defaults so Performance profile can override Epic. */
	void ApplyProfileScalabilityToGameUserSettings();

protected:
	void LoadPlayerProfile();

	UPROPERTY()
	TObjectPtr<UFELPlayerProfileSave> PlayerProfile = nullptr;

	UPROPERTY()
	TWeakObjectPtr<AFELBasketballGameMode> PendingStartupGameMode;

	EFELRetailStartupPhase StartupPhase = EFELRetailStartupPhase::None;

	UPROPERTY(EditAnywhere, Category = "FEL|Retail")
	bool bEnableRetailStartupInPIE = true;
};
