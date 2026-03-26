// Copyright (c) Final Evolution Lab.
// Digital Twin Hub — spawn calibrated `AFELBasketballCharacter` + DeepMotion "Perfect Form" takeoff (Academy mocap catalog).

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "FELDigitalTwinHubLibrary.generated.h"

class AFELBasketballCharacter;
class UObject;

UCLASS()
class FINALEVOLUTIONLAB_API UFELDigitalTwinHubLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	/**
	 * Spawns the 3D digital twin at `SpawnTransform`, then applies `FFELReadinessSnapshot` built only from
	 * `UFELAvatarSubsystem` calibration (PRQ, vertical inches, neuro potential Z, kinetic heat / leakage map).
	 * Movement physics remain in `AFELBasketballCharacter::ApplyReadiness` + `FELNeuroMechanicPhysics` / `FELKineticLeakage`.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|DigitalTwin", meta = (WorldContext = "WorldContextObject"))
	static AFELBasketballCharacter* SpawnCalibratedDigitalTwin(
		UObject* WorldContextObject,
		TSubclassOf<AFELBasketballCharacter> CharacterClass,
		const FTransform& SpawnTransform);

	/**
	 * Plays the DeepMotion-captured montage for the current sport mode (map `PerfectFormMontageByArenaMode` in
	 * `UFELAcademyMocapCatalogSubsystem`). Bind to gamepad Cross / mobile tap from UI or Enhanced Input.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|DigitalTwin|Mocap")
	static bool PlayPerfectFormMocapTakeoff(AFELBasketballCharacter* Character, EFELArenaMode Mode);
};
