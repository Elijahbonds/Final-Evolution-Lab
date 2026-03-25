// Copyright (c) Final Evolution Lab.
// System Scan → Vertical Velocity Academy "Fix This" mapping (parity with Swift `SystemScanMovementDecoder`).

#pragma once

#include "CoreMinimal.h"

namespace FELMovementDecoderAcademy
{
	/** Kinetic leak threshold for educational copy + primary module (prescription bands may use 0.65). */
	inline constexpr double LeakThreshold = 0.6;

	enum class EJointDecoder : uint8
	{
		Ankle,
		Knee,
		Hip
	};

	/** Primary Academy module id when heat > LeakThreshold; empty if no leak. */
	inline FString PrimaryFixModuleId(EJointDecoder Joint, double Heat01)
	{
		if (Heat01 <= LeakThreshold)
		{
			return FString();
		}
		switch (Joint)
		{
		case EJointDecoder::Ankle: return TEXT("mod1");  // Bio-Electric Freeway / CNS
		case EJointDecoder::Knee: return TEXT("mod2");   // SFMA/FMS internal GPS
		case EJointDecoder::Hip: return TEXT("mod5");   // Anatomy of the Sling
		default: return FString();
		}
	}

	inline FString WhyMattersText(EJointDecoder Joint, double Heat01)
	{
		if (Heat01 <= LeakThreshold)
		{
			return FString();
		}
		switch (Joint)
		{
		case EJointDecoder::Ankle:
			return TEXT("Limited ankle dorsiflexion bleeds energy into the floor, reducing vertical potential. Clear dorsiflexion so force exits upward.");
		case EJointDecoder::Knee:
			return TEXT("Knee tracking and stiffness issues leak torque and elastic return. Restoring alignment lets the spring recoil.");
		case EJointDecoder::Hip:
			return TEXT("Short hip extension caps triple extension and shifts load upstream. Open the hip hinge to protect the chain.");
		default: return FString();
		}
	}
}
