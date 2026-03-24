#include "FE_LabManager.h"

#include "ArenaActor.h"
#include "EngineUtils.h"
#include "FE_GameInstance.h"

AFE_LabManager::AFE_LabManager()
{
    PrimaryActorTick.bCanEverTick = false;
}

void AFE_LabManager::BeginPlay()
{
    Super::BeginPlay();

    SyncFromGameInstance();

    if (bApplyArenaThemeOnBeginPlay)
    {
        SetGameMode(CurrentMode);
    }
}

void AFE_LabManager::SetGameMode(EGameModeId NewMode)
{
    CurrentMode = NewMode;

    if (ArenaActor == nullptr)
    {
        UWorld* World = GetWorld();
        if (IsValid(World))
        {
            for (TActorIterator<AArenaActor> It(World); It; ++It)
            {
                ArenaActor = *It;
                break;
            }
        }
    }

    if (ArenaActor != nullptr)
    {
        ArenaActor->ApplyTheme(CurrentMode);
    }
}

void AFE_LabManager::StartLabSession()
{
    SyncFromGameInstance();
    SetGameMode(CurrentMode);
}

void AFE_LabManager::SyncFromGameInstance()
{
    UFE_GameInstance* GI = Cast<UFE_GameInstance>(GetGameInstance());
    if (GI == nullptr)
    {
        return;
    }

    CurrentShards = GI->EvolutionShards;
    CurrentPRQ = GI->PRQScore;
    CurrentAttributes = GI->PlayerAttributes;
}
