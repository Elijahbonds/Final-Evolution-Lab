// Copyright (c) Final Evolution Lab.
// Hex-aligned with Swift `Theme.brandCyan` / `Theme.brandBlue` (Utilities/Theme.swift) for Victory + HUD parity.

#pragma once

#include "CoreMinimal.h"

namespace FELBranding
{
	/** ~#00F2E6 — primary Neuro-Mechanic accent (matches Swift Theme.brandCyan). */
	inline constexpr FLinearColor NeuroAccentCyan()
	{
		return FLinearColor(0.f, 0.95f, 0.9f);
	}

	/** ~#00D4FF — secondary accent (matches Swift Theme.brandBlue). */
	inline constexpr FLinearColor NeuroAccentBlue()
	{
		return FLinearColor(0.f, 0.83f, 1.f);
	}

	inline constexpr FLinearColor PanelBackground()
	{
		return FLinearColor(0.02f, 0.02f, 0.02f, 0.92f);
	}
}
