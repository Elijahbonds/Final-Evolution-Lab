// Copyright (c) Final Evolution Lab.

#include "FELDunkBallistics.h"
#include "Math/UnrealMathUtility.h"

namespace
{
	static bool SegmentIntersectsRimSlab(
		const FVector& A,
		const FVector& B,
		const FVector& RimCenter,
		const float RimPlaneZ,
		const float RimRadiusXY,
		const float RimHalfThicknessZ,
		const float BallRadius,
		float& OutAlpha)
	{
		const float ZMin = RimPlaneZ - RimHalfThicknessZ - BallRadius;
		const float ZMax = RimPlaneZ + RimHalfThicknessZ + BallRadius;
		const FVector D = B - A;
		const float Len = D.Size();
		if (Len < KINDA_SMALL_NUMBER)
		{
			const FVector2D P(A.X - RimCenter.X, A.Y - RimCenter.Y);
			const bool XY = P.Size() <= RimRadiusXY + BallRadius;
			const bool Z = A.Z >= ZMin && A.Z <= ZMax;
			OutAlpha = 0.f;
			return XY && Z;
		}
		for (int32 i = 0; i <= 8; ++i)
		{
			const float T = i / 8.f;
			const FVector P = FMath::Lerp(A, B, T);
			if (P.Z < ZMin || P.Z > ZMax)
			{
				continue;
			}
			const float Dx = P.X - RimCenter.X;
			const float Dy = P.Y - RimCenter.Y;
			if (FMath::Sqrt(Dx * Dx + Dy * Dy) <= RimRadiusXY + BallRadius)
			{
				OutAlpha = T;
				return true;
			}
		}
		return false;
	}
} // namespace

bool FELDunkBallistics::SampleArcUntilRimContact(
	const FVector& StartWorld,
	const FVector& StartVelocityCmPerSec,
	const float GravityZCmPerSec2,
	const FVector& RimCenterWorld,
	const float RimPlaneZ,
	const float RimRadiusXY,
	const float RimHalfThicknessZ,
	const float BallRadiusUU,
	const float DeltaT,
	const int32 MaxSteps,
	float& OutTimeSec,
	FVector& OutContactLocation,
	FVector& OutVelocityAtContact)
{
	OutTimeSec = 0.f;
	OutContactLocation = StartWorld;
	OutVelocityAtContact = StartVelocityCmPerSec;
	FVector Pos = StartWorld;
	FVector Vel = StartVelocityCmPerSec;
	const float G = GravityZCmPerSec2;
	const int32 Cap = FMath::Clamp(MaxSteps, 4, 4096);
	for (int32 Step = 0; Step < Cap; ++Step)
	{
		const FVector NextVel = Vel + FVector(0.f, 0.f, G) * DeltaT;
		const FVector NextPos = Pos + Vel * DeltaT + FVector(0.f, 0.f, 0.5f * G * DeltaT * DeltaT);
		float Alpha = 0.f;
		if (SegmentIntersectsRimSlab(Pos, NextPos, RimCenterWorld, RimPlaneZ, RimRadiusXY, RimHalfThicknessZ, BallRadiusUU, Alpha))
		{
			OutTimeSec = (Step + Alpha) * DeltaT;
			OutContactLocation = FMath::Lerp(Pos, NextPos, Alpha);
			OutVelocityAtContact = FMath::Lerp(Vel, NextVel, Alpha);
			return true;
		}
		Pos = NextPos;
		Vel = NextVel;
	}
	return false;
}
