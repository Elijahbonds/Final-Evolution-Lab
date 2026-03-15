#pragma once

#include "GameFramework/SaveGame.h"
#include "FinalEvolutionTypes.h"
#include "FE_SaveGame.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFE_SaveGame : public USaveGame
{
    GENERATED_BODY()

public:
    UPROPERTY()
    int32 SavedShards;

    UPROPERTY()
    float SavedPRQ;

    UPROPERTY()
    FGameAttributes SavedAttributes;
};
