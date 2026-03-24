#include "FE_CoachingPortalWidget.h"

#include "FE_GameInstance.h"

void UFE_CoachingPortalWidget::RefreshFromGameInstance()
{
    UFE_GameInstance* GI = GetWorld() ? GetWorld()->GetGameInstance<UFE_GameInstance>() : nullptr;
    if (GI == nullptr)
    {
        return;
    }

    DisplayShards = GI->EvolutionShards;
    DisplayPRQ = GI->PRQScore;
    DisplayAttributes = GI->PlayerAttributes;
    OnPortalStateUpdated();
}

bool UFE_CoachingPortalWidget::SpendShardsFromPortal(int32 Amount)
{
    UFE_GameInstance* GI = GetWorld() ? GetWorld()->GetGameInstance<UFE_GameInstance>() : nullptr;
    if (GI == nullptr)
    {
        return false;
    }

    const bool bSpent = GI->SpendShards(Amount);
    if (bSpent)
    {
        GI->SavePlayerState();
    }

    RefreshFromGameInstance();
    return bSpent;
}

void UFE_CoachingPortalWidget::ApplySessionReward(int32 ShardReward, float PRQDelta)
{
    UFE_GameInstance* GI = GetWorld() ? GetWorld()->GetGameInstance<UFE_GameInstance>() : nullptr;
    if (GI == nullptr)
    {
        return;
    }

    GI->EvolutionShards = FMath::Max(0, GI->EvolutionShards + ShardReward);
    GI->PRQScore = FMath::Clamp(GI->PRQScore + PRQDelta, 0.0f, 100.0f);
    GI->SavePlayerState();
    RefreshFromGameInstance();
}
