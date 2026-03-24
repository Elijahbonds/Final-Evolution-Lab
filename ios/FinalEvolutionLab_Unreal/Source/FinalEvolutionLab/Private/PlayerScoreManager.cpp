#include "PlayerScoreManager.h"

#include "EngineUtils.h"

TWeakObjectPtr<APlayerScoreManager> APlayerScoreManager::Instance = nullptr;

APlayerScoreManager::APlayerScoreManager()
{
    PrimaryActorTick.bCanEverTick = false;
}

void APlayerScoreManager::BeginPlay()
{
    Super::BeginPlay();

    if (Instance.IsValid() && Instance.Get() != this)
    {
        UE_LOG(LogTemp, Warning, TEXT("[PlayerScoreManager] Duplicate manager found. Destroying duplicate."));
        Destroy();
        return;
    }

    Instance = this;
}

void APlayerScoreManager::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (Instance.Get() == this)
    {
        Instance = nullptr;
    }

    Super::EndPlay(EndPlayReason);
}

int32 APlayerScoreManager::GetPlayerScore() const
{
    return Score;
}

void APlayerScoreManager::UpdatePlayerScore(int32 NewScore)
{
    Score = NewScore;
    UE_LOG(LogTemp, Log, TEXT("[PlayerScoreManager] Local score updated: %d"), Score);
    OnPlayerScoreUpdated.Broadcast(Score);
}

APlayerScoreManager* APlayerScoreManager::Get(UObject* WorldContextObject)
{
    if (Instance.IsValid())
    {
        return Instance.Get();
    }

    if (!IsValid(WorldContextObject))
    {
        return nullptr;
    }

    UWorld* World = WorldContextObject->GetWorld();
    if (!IsValid(World))
    {
        return nullptr;
    }

    for (TActorIterator<APlayerScoreManager> It(World); It; ++It)
    {
        Instance = *It;
        return *It;
    }

    return nullptr;
}
