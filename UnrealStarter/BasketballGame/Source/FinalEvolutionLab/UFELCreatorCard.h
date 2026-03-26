// Copyright (c) Final Evolution Lab.
// Creator Card — collectible boost; temporary PRQ / Arena multipliers (Court IQ, Hang Time, etc.).

#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "UFELCreatorCard.generated.h"

/**
 * Data asset for a Creator Card (matches Swift `CreatorCard` catalog concept).
 * Designers tune multipliers; runtime applies while the card is active (duration in seconds).
 */
UCLASS(BlueprintType)
class FINALEVOLUTIONLAB_API UFELCreatorCard : public UPrimaryDataAsset
{
	GENERATED_BODY()

public:
	/** Must match Swift `CreatorCard.id` / profile.ownedCardIds. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|CreatorCard")
	FName CardId;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|CreatorCard")
	FText DisplayName;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|CreatorCard", meta = (MultiLine = "true"))
	FText Description;

	/** Multiplier applied to PRQ contribution in Arena scoring / feedback (1.0 = no change). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Boosts")
	float PRQMultiplier = 1.0f;

	/** Scales raw Arena performance / round score aggregation. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Boosts")
	float ArenaPerformanceMultiplier = 1.0f;

	/** "Court IQ" — decision / timing lane (PRQ sub-weight in design docs). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Boosts")
	float CourtIQMultiplier = 1.0f;

	/** Hang time / apex — vertical expression lane. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Boosts")
	float HangTimeMultiplier = 1.0f;

	/** How long the boost lasts after activation (seconds). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|CreatorCard")
	float ActiveDurationSeconds = 300.0f;

	/** Dojo Neural Tempest — Cyclone Energy funnel (1.0 = default). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Boosts|DojoTempest", meta = (ClampMin = "0.5", ClampMax = "1.5"))
	float DojoTempestEnergyRegenScale = 1.0f;

	/** Dojo Neural Tempest — Tempest Burst strike power (1.0 = default). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Boosts|DojoTempest", meta = (ClampMin = "0.5", ClampMax = "1.5"))
	float DojoTempestStrikePowerScale = 1.0f;

	UFUNCTION(BlueprintPure, Category = "FEL|CreatorCard")
	FName GetCardId() const { return CardId; }
};
