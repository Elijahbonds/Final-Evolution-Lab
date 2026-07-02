// Copyright (c) Final Evolution Lab.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Components/BoxComponent.h"
#include "FELVenueVolume.generated.h"

/**
 * Trigger boundary representing a training location (e.g. Venice Beach Court, Zen Dojo).
 * Automatically updates the active venue and game mode rules upon player entry.
 */
UCLASS()
class FINALEVOLUTIONLAB_API AFELVenueVolume : public AActor
{
	GENERATED_BODY()

public:
	AFELVenueVolume();

protected:
	virtual void BeginPlay() override;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Volume")
	UBoxComponent* CollisionComponent;

	/** Unique venue identifier token corresponding to the database registry (e.g. dojo_arena, venice_beach_court). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Volume")
	FString VenueToken;

	/** The default game mode associated with this venue (e.g. karate_h2h, basketball_dunk). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Volume")
	FString DefaultModeId;

private:
	UFUNCTION()
	void OnOverlapBegin(
		UPrimitiveComponent* OverlappedComp,
		AActor* OtherActor,
		UPrimitiveComponent* OtherComp,
		int32 OtherBodyIndex,
		bool bFromSweep,
		const FHitResult& SweepResult);
};
