// Copyright (c) Final Evolution Lab.
// Header-level platform tier — no UObject; safe to include from any module.

#pragma once

#include "FELBuildTargetTypes.h"

#ifndef PIXEL_STREAMING_ENABLED
#define PIXEL_STREAMING_ENABLED 0
#endif

/**
 * Cross-platform build identity for Universal Launch (Cmd+R parity across targets).
 * Resolution order: PS5 → iOS → Android → PixelStreaming (define) → Mac → Win64 → Linux → Generic.
 */
namespace FELPlatformManager
{
	/** Resolved at compile time from PLATFORM_* and PIXEL_STREAMING_ENABLED. */
	FINALEVOLUTIONLAB_API EFELBuildTarget GetActivePlatform();
}
