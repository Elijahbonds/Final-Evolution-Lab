// Copyright (c) Final Evolution Lab.

#include "UFELSystemScanService.h"
#include "FELFlightTimeAnalysis.h"
#include "FELKalmanFilter1D.h"
#include "FELPRQScanFormula.h"
#include "FELNeuroMechanicPhysics.h"

void UFELSystemScanService::AnalyzeScan(
	const FString& Goal,
	float OptionalVideoDurationSeconds,
	int32 DeterminismSeed,
	FFELSystemScanOutput& OutScan,
	int32 ToeOffFrameIndex,
	int32 HeelStrikeFrameIndex,
	float NominalVideoFrameRate) const
{
	const int32 Tier = FELPRQScanFormula::GoalTierFromString(Goal);

	double VMin = 0.0, VMax = 0.0;
	FELPRQScanFormula::GoalTierVerticalRange(Tier, VMin, VMax);
	double Vert = FMath::Lerp(VMin, VMax, FELPRQScanFormula::Hash01(DeterminismSeed));
	{
		FELKalmanFilter1D VertKF;
		VertKF.Reset(Vert);
		const double RawPerturb = 0.985 + 0.03 * FELPRQScanFormula::Hash01(DeterminismSeed + 404);
		Vert = VertKF.Update(Vert * RawPerturb);
	}

	double Flt = -1.0;
	if (ToeOffFrameIndex >= 0 && HeelStrikeFrameIndex > ToeOffFrameIndex && NominalVideoFrameRate > 1.0f)
	{
		const double T = FELFlightTimeAnalysis::FlightSecondsFromToeOffHeelStrikeFrames(
			ToeOffFrameIndex, HeelStrikeFrameIndex, static_cast<double>(NominalVideoFrameRate));
		if (T > 0.0)
		{
			Flt = T;
		}
	}
	if (Flt < 0.0 && OptionalVideoDurationSeconds > 0.0f)
	{
		Flt = FELPRQScanFormula::FlightFromVideoDurationSeconds(static_cast<double>(OptionalVideoDurationSeconds), DeterminismSeed);
	}
	if (Flt < 0.0)
	{
		double F0 = 0.0, F1 = 0.0;
		FELPRQScanFormula::GoalTierFlightRange(Tier, F0, F1);
		Flt = FMath::Lerp(F0, F1, FELPRQScanFormula::Hash01(DeterminismSeed + 33));
	}

	const double PRQ = FELPRQScanFormula::ComputePRQ0to100(Vert, Flt, Tier, DeterminismSeed);
	OutScan.PRQ0to100 = PRQ;
	OutScan.VerticalEstimateInches = Vert;
	OutScan.FlightTimeSeconds = Flt;
	OutScan.MovementGrade = FELPRQScanFormula::MovementGradeFromPRQ(PRQ);
	OutScan.RecommendedTrack = FELPRQScanFormula::RecommendedTrackFromTier(Tier);
	OutScan.StartingTrack = TrackEnumFromString(OutScan.RecommendedTrack);
	OutScan.NeuroVerticalPotentialJumpZ = FELNeuroMechanicPhysics::PotentialJumpZFromVerticalInches(static_cast<float>(Vert));
}

EFELStartingTrack UFELSystemScanService::TrackEnumFromString(const FString& TrackName)
{
	if (TrackName.Equals(TEXT("Flight"), ESearchCase::IgnoreCase))
	{
		return EFELStartingTrack::Flight;
	}
	if (TrackName.Equals(TEXT("Elite"), ESearchCase::IgnoreCase))
	{
		return EFELStartingTrack::Elite;
	}
	return EFELStartingTrack::Foundations;
}
