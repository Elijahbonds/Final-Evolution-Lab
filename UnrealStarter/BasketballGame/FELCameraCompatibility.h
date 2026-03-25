// Copyright (c) Final Evolution Lab.
// UE 5.5+ / 5.7: FMinimalViewInfo no longer exposes the nested FPOV member `POV`.
// Use the flattened fields on FMinimalViewInfo from APlayerCameraManager::GetCameraCacheView():
//   Location, Rotation, FOV (and related projection members) — NOT ViewInfo.POV.Location.

#pragma once

#include "CoreMinimal.h"
#include "Camera/CameraTypes.h"
#include "Engine/PlayerCameraManager.h"

namespace FELCameraCompatUE57
{
	/** Camera cache world location (replaces legacy `GetCameraCacheView().POV.Location`). */
	inline FVector GetCameraCacheLocation(const APlayerCameraManager* PCM)
	{
		if (!PCM)
		{
			return FVector::ZeroVector;
		}
		const FMinimalViewInfo& V = PCM->GetCameraCacheView();
		return V.Location;
	}

	/** Camera cache world rotation (replaces legacy `GetCameraCacheView().POV.Rotation`). */
	inline FRotator GetCameraCacheRotation(const APlayerCameraManager* PCM)
	{
		if (!PCM)
		{
			return FRotator::ZeroRotator;
		}
		const FMinimalViewInfo& V = PCM->GetCameraCacheView();
		return V.Rotation;
	}

	inline float GetCameraCacheFOV(const APlayerCameraManager* PCM)
	{
		if (!PCM)
		{
			return 90.f;
		}
		const FMinimalViewInfo& V = PCM->GetCameraCacheView();
		return V.FOV;
	}
}
