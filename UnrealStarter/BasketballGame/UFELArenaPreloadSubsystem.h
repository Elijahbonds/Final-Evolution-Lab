// Copyright (c) Final Evolution Lab.
// Async preload of all 12 UFELArenaModeData primary assets (Bonds Bounce 1.0 — no cold hitch on first mode pick).

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Engine/StreamableManager.h"
#include "Templates/SharedPointer.h"
#include "UFELArenaPreloadSubsystem.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFELArenaPreloadSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;

	UFUNCTION(BlueprintPure, Category = "FEL|Arena|Preload")
	bool HasFinishedArenaModePreload() const { return bArenaPreloadFinished; }

private:
	void OnArenaModesPreloaded();

	FStreamableManager StreamableManager;
	TSharedPtr<FStreamableHandle> ArenaPreloadHandle;
	bool bArenaPreloadFinished = false;
};
