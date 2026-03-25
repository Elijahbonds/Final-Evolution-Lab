// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "FELReadinessTypes.h"

class UWorld;

/** Load JSON snapshot aligned with Swift PerformanceMetrics (camelCase keys). See NEURO_MECHANIC_BRIDGE.md. */
struct FELReadinessIO
{
	/**
	 * Parse JSON string (Swift export / file contents). Keys: efficiencyScore, prqScore, signature_trait_id, readinessScore, verticalPotential, neuralDrive, popForce, verticalEstimateInches, hangTimeScale, kineticLeakageMultiplier, currentOutfit, active_mode.
	 * When `WorldForTravel` is non-null, triggers mandatory `OpenLevel` for the venue matching `active_mode` (MapTravel handshake) after the snapshot is fully parsed.
	 * If `OutIssuedVenueTravel` is set, it receives whether `OpenLevel` was issued (callers should defer `ApplyReadinessToActors` until the new map loads).
	 */
	static bool ParseSnapshotJsonString(const FString& JsonStr, FFELReadinessSnapshot& Out, FString* OutError = nullptr, UWorld* WorldForTravel = nullptr, bool* OutIssuedVenueTravel = nullptr);

	/**
	 * When `active_mode` requests a basketball venue, travel to the canonical Venice Beach 3D shell (Signal Velocity).
	 * Returns true if `OpenLevel` was issued (caller must not touch actors in this frame — world will reload).
	 */
	static bool TryMandatoryVenueTravelForActiveMode(UWorld* World, const FFELReadinessSnapshot& Snap);

	/** Drive level `APostProcessVolume` tagged `FEL_NeuroFlow` from `Snap.PRQScore` (Measure You pillar). */
	static void ApplySystemScanOptics(class APlayerCameraManager* PCM);
	static void ApplyNeuroFlowPostProcessFromSnapshot(UWorld* World, const FFELReadinessSnapshot& Snap);

	/**
	 * Tries, in order: Documents/FEL (iOS, Swift PRQManager), Saved/FEL, Content/FEL/Config.
	 * See FELPlatformPaths::GetReadinessSnapshotCandidatePaths.
	 */
	static bool TryLoadSnapshot(FFELReadinessSnapshot& Out, FString* OutError = nullptr);
};
