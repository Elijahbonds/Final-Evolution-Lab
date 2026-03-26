// Copyright (c) Final Evolution Lab.
// 1D Kalman filter — smooths noisy joint / leakage metrics from scan video (lighting, clothing, compression).

#pragma once

#include "CoreMinimal.h"

struct FELKalmanFilter1D
{
	double X = 0.0;
	double P = 1.0;
	/** Process noise — smaller = smoother trajectory (slower to respond). */
	double Q = 0.0008;
	/** Measurement noise — higher = trust measurements less (loose clothing / low light). */
	double R = 0.22;

	/** Predict step (advance state). */
	void Predict()
	{
		P += Q;
	}

	/** Update with measurement Z; returns filtered estimate. */
	double Update(double Z)
	{
		if (!FMath::IsFinite(Z))
		{
			return X;
		}
		const double K = P / (P + R);
		X = X + K * (Z - X);
		P = (1.0 - K) * P;
		return X;
	}

	void Reset(double InitialX = 0.0)
	{
		X = InitialX;
		P = 1.0;
	}
};
