// Copyright (c) Final Evolution Lab.

#include "FELPlatformManager.h"
#include "HAL/Platform.h"

#ifndef PIXEL_STREAMING_ENABLED
#define PIXEL_STREAMING_ENABLED 0
#endif

EFELBuildTarget FELPlatformManager::GetActivePlatform()
{
#if PLATFORM_PS5
	return EFELBuildTarget::PS5;
#elif PLATFORM_IOS
	return EFELBuildTarget::IOS;
#elif PLATFORM_ANDROID
	return EFELBuildTarget::Android;
#elif PIXEL_STREAMING_ENABLED
	// Web / Pixel Streaming sender build (set PIXEL_STREAMING_ENABLED=1 in Build.cs + enable plugin).
	return EFELBuildTarget::PixelStreaming;
#elif PLATFORM_MAC
	return EFELBuildTarget::MacDesktop;
#elif PLATFORM_WINDOWS
	return EFELBuildTarget::Win64;
#elif PLATFORM_LINUX
	return EFELBuildTarget::Linux;
#else
	return EFELBuildTarget::Unknown;
#endif
}
