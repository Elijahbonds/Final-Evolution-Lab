// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FELHoopScoreVolume.generated.h"

class UBoxComponent;

/**
 * Place under/near a hoop; when the FEL basketball overlaps, adds score (with cooldown).
 */
UCLASS()
class FINALEVOLUTIONLAB_API AFELHoopScoreVolume : public AActor
{
	GENERATED_BODY()

public:
	AFELHoopScoreVolume();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	UBoxComponent* TriggerBox;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL")
	int32 PointsPerBucket = 1;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL")
	float ScoreCooldownSeconds = 1.5f;

protected:
	virtual void BeginPlay() override;

	UFUNCTION()
	void OnTriggerOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor, UPrimitiveComponent* OtherComp,
		int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult);

	float LastScoreWorldTime = -1000.f;
};
