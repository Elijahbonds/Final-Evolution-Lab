#include "FE_GameInstance.h"

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
