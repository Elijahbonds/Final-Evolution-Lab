// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "UFELAthleteHubWidget.h"
#include "FELBasketballHUD.generated.h"

/**
 * Canvas debug overlay + optional UMG Athlete Hub (engine-driven Sprint/Gather when WBP binds bars).
 */
UCLASS()
class FINALEVOLUTIONLAB_API AFELBasketballHUD : public AHUD
{
	GENERATED_BODY()

public:
	virtual void BeginPlay() override;
	virtual void DrawHUD() override;

	/** Optional; defaults to native `UFELAthleteHubWidget` C++ class if unset. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|HUD")
	TSubclassOf<UFELAthleteHubWidget> AthleteHubWidgetClass;

protected:
	UPROPERTY()
	TObjectPtr<UFELAthleteHubWidget> AthleteHubWidget;
};
