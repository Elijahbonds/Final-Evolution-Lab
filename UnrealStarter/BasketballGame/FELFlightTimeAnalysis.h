// Copyright (c) Final Evolution Lab.
// High-frequency (120/240 fps) flight time: toe-off frame → heel-strike frame at nominal device frame rate.

#pragma once

#include "CoreMinimal.h"

namespace FELFlightTimeAnalysis
{
	/**
	 * Sub-millisecond precision when NominalFrameRate is 120 or 240 (dt = 1/fps).
	 * @param ToeOffFrameIndex  First frame where takeoff is detected (vertical GRF drop / toe-off).
	 * @param HeelStrikeFrameIndex  First frame where landing contact is detected (heel strike).
	 * @return Flight time in seconds, or -1 if invalid.
	 */
	inline double FlightSecondsFromToeOffHeelStrikeFrames(int32 ToeOffFrameIndex, int32 HeelStrikeFrameIndex, double NominalFrameRate)
	{
		if (NominalFrameRate <= 0.0 || !FMath::IsFinite(NominalFrameRate))
		{
			return -1.0;
		}
		if (HeelStrikeFrameIndex <= ToeOffFrameIndex)
		{
			return -1.0;
		}
		const double Dt = 1.0 / NominalFrameRate;
		return static_cast<double>(HeelStrikeFrameIndex - ToeOffFrameIndex) * Dt;
	}
}
