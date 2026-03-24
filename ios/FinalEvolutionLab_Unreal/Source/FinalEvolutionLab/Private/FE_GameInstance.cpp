#include "FE_GameInstance.h"

#include "FE_SaveGame.h"
#include "Kismet/GameplayStatics.h"

UFE_GameInstance::UFE_GameInstance()
    : EvolutionShards(0)
    , PRQScore(50.0f)
    , StreakDays(0)
    , PlayerAttributes()
{
}

bool UFE_GameInstance::SpendShards(int32 Amount)
{
    if (Amount <= 0)
    {
        return false;
    }

    if (EvolutionShards >= Amount)
    {
        EvolutionShards -= Amount;
        return true;
    }
    return false;
}

bool UFE_GameInstance::SavePlayerState()
{
    UFE_SaveGame* SaveObject = Cast<UFE_SaveGame>(UGameplayStatics::CreateSaveGameObject(UFE_SaveGame::StaticClass()));
    if (SaveObject == nullptr)
    {
        return false;
    }

    SaveObject->SavedShards = EvolutionShards;
    SaveObject->SavedPRQ = PRQScore;
    SaveObject->SavedAttributes = PlayerAttributes;

    return UGameplayStatics::SaveGameToSlot(SaveObject, SaveSlotName, SaveUserIndex);
}

bool UFE_GameInstance::LoadPlayerState()
{
    if (!UGameplayStatics::DoesSaveGameExist(SaveSlotName, SaveUserIndex))
    {
        return false;
    }

    UFE_SaveGame* SaveObject = Cast<UFE_SaveGame>(UGameplayStatics::LoadGameFromSlot(SaveSlotName, SaveUserIndex));
    if (SaveObject == nullptr)
    {
        return false;
    }

    EvolutionShards = SaveObject->SavedShards;
    PRQScore = SaveObject->SavedPRQ;
    PlayerAttributes = SaveObject->SavedAttributes;
    return true;
}
