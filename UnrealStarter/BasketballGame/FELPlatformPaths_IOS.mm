// Copyright (c) Final Evolution Lab.
// iOS: Documents/FEL — same container Swift PRQManager uses for readiness_snapshot.json.
// Add this file to your game module for iOS builds only (see FinalEvolutionLab.Build.cs.snippet).

#include "FELPlatformPaths.h"
#include "HAL/PlatformFilemanager.h"
#include "Misc/Paths.h"

#if PLATFORM_IOS
#import <Foundation/Foundation.h>

FString FELPlatformPaths::GetFELDataDirectory()
{
	NSArray* Paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString* Doc = [Paths objectAtIndex:0];
	FString Base(UTF8_TO_TCHAR([Doc UTF8String]));
	const FString Dir = FPaths::Combine(Base, TEXT("FEL"));
	IPlatformFile& PF = FPlatformFileManager::Get().GetPlatformFile();
	if (!PF.DirectoryExists(*Dir))
	{
		PF.CreateDirectoryTree(*Dir);
	}
	// Large JSON caches / Unreal exports — exclude from iCloud backup (persists on device; see Apple File System guidelines).
	NSString* FelPath = [NSString stringWithUTF8String:TCHAR_TO_UTF8(*Dir)];
	NSURL* FelURL = [NSURL fileURLWithPath:FelPath isDirectory:YES];
	NSError* AttrErr = nil;
	(void)[FelURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&AttrErr];
	return Dir;
}
#endif
