// Copyright (c) Final Evolution Lab.

#include "UFELGameInstance.h"
#include "FELClinicalUIPolicy.h"
#include "Engine/Engine.h"
#include "FELArenaModeDefinitions.h"
#include "FELArenaModePresentation.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FELSessionExport.h"
#include "UFELPlayerProfileSave.h"
#include "UFELRetailStartupWidget.h"
#include "GameFramework/GameUserSettings.h"
#include "GameFramework/PlayerController.h"
#include "HAL/PlatformMisc.h"
#include "Kismet/GameplayStatics.h"
#include "GameFramework/SaveGame.h"

namespace
{
	static void FEL_SetScalabilityFromPreset(const bool bPerformance)
	{
		if (!GEngine)
		{
			return;
		}
		UGameUserSettings* S = GEngine->GetGameUserSettings();
		if (!S)
		{
			return;
		}
		const int32 Level = bPerformance ? 1 : 4;
		S->SetOverallScalabilityLevel(Level);
		S->SetViewDistanceQuality(Level);
		S->SetAntiAliasingQuality(Level);
		S->SetShadowQuality(Level);
		S->SetGlobalIlluminationQuality(Level);
		S->SetReflectionQuality(Level);
		S->SetPostProcessingQuality(Level);
		S->SetTextureQuality(Level);
		S->SetVisualEffectQuality(Level);
		S->SetFoliageQuality(Level);
		S->SetShadingQuality(Level);
		S->ApplySettings(true);
	}
} // namespace

void UFELGameInstance::Init()
{
	Super::Init();
	LoadPlayerProfile();
	FString PolicyErr;
	if (!FELClinicalUIPolicyLoader::TryLoadFromContent(ClinicalUIPolicy, &PolicyErr))
	{
#if !UE_BUILD_SHIPPING
		if (!PolicyErr.IsEmpty())
		{
			UE_LOG(LogTemp, Warning, TEXT("FEL Clinical UI policy: %s"), *PolicyErr);
		}
#endif
	}
}

void UFELGameInstance::Shutdown()
{
	SavePlayerProfile();
	Super::Shutdown();
}

void UFELGameInstance::LoadPlayerProfile()
{
	if (UGameplayStatics::DoesSaveGameExist(UFELPlayerProfileSave::GetSlotName(), UFELPlayerProfileSave::UserSlotIndex))
	{
		if (USaveGame* Loaded = UGameplayStatics::LoadGameFromSlot(UFELPlayerProfileSave::GetSlotName(), UFELPlayerProfileSave::UserSlotIndex))
		{
			PlayerProfile = Cast<UFELPlayerProfileSave>(Loaded);
		}
	}
	if (!PlayerProfile)
	{
		PlayerProfile = Cast<UFELPlayerProfileSave>(UGameplayStatics::CreateSaveGameObject(UFELPlayerProfileSave::StaticClass()));
	}
}

void UFELGameInstance::SavePlayerProfile()
{
	if (!PlayerProfile)
	{
		LoadPlayerProfile();
	}
	if (PlayerProfile)
	{
		UGameplayStatics::SaveGameToSlot(PlayerProfile, UFELPlayerProfileSave::GetSlotName(), UFELPlayerProfileSave::UserSlotIndex);
	}
}

void UFELGameInstance::PersistUserSettingsAndProfile()
{
	SavePlayerProfile();
	if (GEngine)
	{
		if (UGameUserSettings* S = GEngine->GetGameUserSettings())
		{
			S->ApplySettings(true);
		}
	}
}

void UFELGameInstance::ApplyProfileScalabilityToGameUserSettings()
{
	if (!PlayerProfile)
	{
		LoadPlayerProfile();
	}
	if (!PlayerProfile)
	{
		return;
	}
	FEL_SetScalabilityFromPreset(PlayerProfile->bPerformanceMode);
}

FString UFELGameInstance::GetPreferredArenaModeId() const
{
	if (PlayerProfile && !PlayerProfile->PreferredArenaModeId.IsEmpty())
	{
		return PlayerProfile->PreferredArenaModeId;
	}
	return TEXT("basketball_h2h");
}

void UFELGameInstance::SetPreferredArenaFromMode(const EFELArenaMode Mode)
{
	if (!PlayerProfile)
	{
		LoadPlayerProfile();
	}
	if (!PlayerProfile)
	{
		return;
	}
	PlayerProfile->PreferredArenaModeId = FELArenaModeToIdString(Mode);
	PlayerProfile->SelectedInspirationTag = FELGetArenaModeInspirationTag(Mode);
	SavePlayerProfile();
}

void UFELGameInstance::MaybeUpdateHighScore(const int32 BucketScore)
{
	if (!PlayerProfile)
	{
		LoadPlayerProfile();
	}
	if (!PlayerProfile || BucketScore <= PlayerProfile->BestBucketHighScore)
	{
		return;
	}
	PlayerProfile->BestBucketHighScore = BucketScore;
	SavePlayerProfile();
}

bool UFELGameInstance::ShouldShowRetailStartup() const
{
#if WITH_EDITOR
	if (!bEnableRetailStartupInPIE)
	{
		return false;
	}
#endif
	const UFELPlayerProfileSave* P = GetPlayerProfile();
	if (P && P->bHasCompletedRetailStartup)
	{
		return false;
	}
	return true;
}

void UFELGameInstance::BeginRetailStartupFlow(APlayerController* PC, AFELBasketballGameMode* GameMode)
{
	if (!PC || !GameMode)
	{
		return;
	}
	PendingStartupGameMode = GameMode;
	StartupPhase = EFELRetailStartupPhase::Splash;
	PC->SetIgnoreMoveInput(true);
	PC->SetIgnoreLookInput(true);
	const TSubclassOf<UFELRetailStartupWidget> Cls = TSubclassOf<UFELRetailStartupWidget>(UFELRetailStartupWidget::StaticClass());
	if (UFELRetailStartupWidget* W = CreateWidget<UFELRetailStartupWidget>(PC, Cls))
	{
		W->InitializeRetailFlow(this);
		W->AddToViewport(1000);
		FInputModeUIOnly Mode;
		Mode.SetWidgetToFocus(W->TakeWidget());
		PC->SetInputMode(Mode);
		PC->SetShowMouseCursor(false);
	}
}

void UFELGameInstance::OnRetailStartupPlaySelected()
{
	StartupPhase = EFELRetailStartupPhase::Complete;
	if (PlayerProfile)
	{
		PlayerProfile->bHasCompletedRetailStartup = true;
		SavePlayerProfile();
	}
	if (APlayerController* PC = GetFirstLocalPlayerController())
	{
		PC->SetIgnoreMoveInput(false);
		PC->SetIgnoreLookInput(false);
		FInputModeGameOnly Input;
		PC->SetInputMode(Input);
	}
	if (AFELBasketballGameMode* GM = PendingStartupGameMode.Get())
	{
		GM->OnRetailStartupFlowComplete();
	}
	PendingStartupGameMode = nullptr;
}

void UFELGameInstance::OnRetailStartupQuitSelected()
{
	RequestQuitToDesktop(true);
}

void UFELGameInstance::ApplyQualityPreset(const bool bPerformanceMode)
{
	if (!PlayerProfile)
	{
		LoadPlayerProfile();
	}
	if (PlayerProfile)
	{
		PlayerProfile->bPerformanceMode = bPerformanceMode;
		SavePlayerProfile();
	}
	FEL_SetScalabilityFromPreset(bPerformanceMode);
}

bool UFELGameInstance::IsPerformanceModePreferred() const
{
	return PlayerProfile && PlayerProfile->bPerformanceMode;
}

void UFELGameInstance::RequestQuitToDesktop(const bool bFlushSessionSnapshot)
{
	SavePlayerProfile();
	if (bFlushSessionSnapshot)
	{
		if (UWorld* W = GetWorld())
		{
			if (AFELBasketballGameState* GS = W->GetGameState<AFELBasketballGameState>())
			{
				if (!GS->HasMatchEnded())
				{
					FELSessionExport::WriteLastSession(GS, W, nullptr);
				}
			}
		}
	}
	FGenericPlatformMisc::RequestExit(false);
}
