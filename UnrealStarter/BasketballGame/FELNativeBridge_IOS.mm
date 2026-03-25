// Copyright (c) Final Evolution Lab.
// iOS: post NSNotification names consumed by Swift (NativeCallProxy parity, inverted direction).

#include "CoreMinimal.h"

#if PLATFORM_IOS
#import <Foundation/Foundation.h>
#include "Async/Async.h"
#include "Engine/Engine.h"
#include "Math/UnrealMathUtility.h"
#include "UFELPlatformManager.h"

static NSString* const kFELUnrealSessionResultsReady = @"FELUnrealSessionResultsReady";
static NSString* const kFELUnrealExitToDashboard = @"FELUnrealExitToDashboard";
static NSString* const kFelShareEvolutionFromUnreal = @"FelShareEvolutionFromUnreal";
static NSString* const kFelUnrealUINotificationFeedback = @"FelUnrealUINotificationFeedback";
static NSString* const kFelAvatarSnapshotPngReady = @"FelAvatarSnapshotPngReady";
static NSString* const kFelNeuroFlowMp4ExportReady = @"FelNeuroFlowMp4ExportReady";
static NSString* const kFelUnrealShardMarketplaceRequest = @"FelUnrealShardMarketplaceRequest";
static NSString* const kFELUnrealLevelLoaded = @"FELUnrealLevelLoaded";
static NSString* const kFelCoachPerformanceSnapshot = @"FelCoachPerformanceSnapshot";
static NSString* const kFelUniversalSyncExport = @"FelUniversalSyncExport";
static NSString* const kFelHeroMomentExportReady = @"felHeroMomentExportReady";
static NSString* const kFelPenultimateStrideRhythm = @"felPenultimateStrideRhythm";

extern "C" void FEL_IOS_PostSessionReady(const char* PathUtf8)
{
	NSString* path = PathUtf8 ? [NSString stringWithUTF8String:PathUtf8] : @"";
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kFELUnrealSessionResultsReady
		                                                    object:nil
		                                                  userInfo:@{ @"sessionResultsPath": path }];
	});
}

extern "C" void FEL_IOS_PostExitToDashboard()
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kFELUnrealExitToDashboard object:nil];
	});
}

extern "C" void FEL_IOS_PostShareEvolution()
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kFelShareEvolutionFromUnreal object:nil];
	});
}

extern "C" void FEL_IOS_PostUINotificationFeedback(int32 Kind)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kFelUnrealUINotificationFeedback
		                                                    object:nil
		                                                  userInfo:@{ @"kind": @(Kind) }];
	});
}

extern "C" void FEL_IOS_PostAvatarSnapshotPng(const void* Bytes, int32 Len)
{
	if (!Bytes || Len <= 0)
	{
		return;
	}
	NSData* data = [NSData dataWithBytes:Bytes length:Len];
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kFelAvatarSnapshotPngReady
		                                                    object:nil
		                                                  userInfo:@{ @"pngData": data }];
	});
}

extern "C" void FEL_IOS_PostNeuroFlowMp4Path(const char* PathUtf8)
{
	NSString* path = PathUtf8 ? [NSString stringWithUTF8String:PathUtf8] : @"";
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kFelNeuroFlowMp4ExportReady
		                                                    object:nil
		                                                  userInfo:@{ @"mp4Path": path }];
	});
}

extern "C" void FEL_IOS_PostShardMarketplaceHotspot(const char* HotspotUtf8, const char* CaptureUtf8)
{
	NSString* hid = HotspotUtf8 ? [NSString stringWithUTF8String:HotspotUtf8] : @"";
	NSString* cap = CaptureUtf8 ? [NSString stringWithUTF8String:CaptureUtf8] : @"";
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kFelUnrealShardMarketplaceRequest
		                                                    object:nil
		                                                  userInfo:@{ @"hotspotId": hid, @"lumaCaptureId": cap }];
	});
}

extern "C" void FEL_IOS_PostLevelLoaded(const char* MapUtf8)
{
	NSString* map = MapUtf8 ? [NSString stringWithUTF8String:MapUtf8] : @"";
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kFELUnrealLevelLoaded
		                                                    object:nil
		                                                  userInfo:@{ @"mapName": map }];
	});
}

extern "C" void FEL_IOS_PostCoachPerformanceJSON(const char* JsonUtf8)
{
	NSString* json = JsonUtf8 ? [NSString stringWithUTF8String:JsonUtf8] : @"";
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kFelCoachPerformanceSnapshot
		                                                    object:nil
		                                                  userInfo:@{ @"json": json }];
	});
}

extern "C" void FEL_IOS_PostUniversalSyncExport(const char* Base64Utf8)
{
	NSString* payload = Base64Utf8 ? [NSString stringWithUTF8String:Base64Utf8] : @"";
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kFelUniversalSyncExport
		                                                    object:nil
		                                                  userInfo:@{ @"base64": payload }];
	});
}

extern "C" void FEL_IOS_PostHeroMomentExportReady(float EstimatedApexInches)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kFelHeroMomentExportReady
		                                                    object:nil
		                                                  userInfo:@{ @"estimatedApexInches": @(EstimatedApexInches) }];
	});
}

extern "C" void FEL_IOS_PostPenultimateStrideRhythm(int32 Phase)
{
	const int32 P = ((Phase % 3) + 3) % 3;
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kFelPenultimateStrideRhythm
		                                                    object:nil
		                                                  userInfo:@{ @"phase": @(P) }];
	});
}

/** Swift `FELLuminanceAnalyzer` / Arena session — drives `UFELPlatformManager::ApplyIOSLiveSessionLuminancePostProcess` (AUDIT_QUALITY). */
extern "C" void FEL_IOS_OnAmbientLuminanceChanged(float Luma01, float DeltaLuma)
{
	const float L = FMath::Clamp(Luma01, 0.f, 1.f);
	const float D = DeltaLuma;
	AsyncTask(ENamedThreads::GameThread, [L, D]()
	{
		if (!GEngine)
		{
			return;
		}
		for (const FWorldContext& Ctx : GEngine->GetWorldContexts())
		{
			if (UWorld* W = Ctx.World())
			{
				if (UGameInstance* GI = W->GetGameInstance())
				{
					if (UFELPlatformManager* PM = GI->GetSubsystem<UFELPlatformManager>())
					{
						PM->ApplyIOSLiveSessionLuminancePostProcess(L, D);
						return;
					}
				}
			}
		}
	});
}
#endif
