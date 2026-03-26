// Copyright (c) Final Evolution Lab.
// Invisible collision hulls — block character vs Luma mesh gaps / thin photogrammetry walls.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FELInvisibleBlockingVolume.generated.h"

class UBoxComponent;

/** Designer-placed invisible box; hidden in-game, blocks WorldDynamic / Pawn by default. */
UCLASS()
class FINALEVOLUTIONLAB_API AFELInvisibleBlockingVolume : public AActor
{
	GENERATED_BODY()

public:
	AFELInvisibleBlockingVolume();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Collision")
	TObjectPtr<UBoxComponent> BlockBox;
};
