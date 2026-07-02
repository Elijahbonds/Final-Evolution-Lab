// Copyright (c) Final Evolution Lab.

#include "FELIOSWebOverlay.h"

#include "Async/Async.h"
#include "HAL/Platform.h"

#if PLATFORM_IOS

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface FELBridgeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation FELBridgeHandler
- (void)userContentController:(WKUserContentController*)userContentController didReceiveScriptMessage:(WKScriptMessage*)message
{
	if (message == nil)
	{
		return;
	}
	id Body = message.body;

	NSString* AsString = nil;
	if ([Body isKindOfClass:[NSString class]])
	{
		AsString = (NSString*)Body;
	}
	else if ([NSJSONSerialization isValidJSONObject:Body])
	{
		NSError* Err = nil;
		NSData* Data = [NSJSONSerialization dataWithJSONObject:Body options:0 error:&Err];
		if (Data && !Err)
		{
			AsString = [[NSString alloc] initWithData:Data encoding:NSUTF8StringEncoding];
		}
	}

	if (AsString == nil)
	{
		AsString = [NSString stringWithFormat:@"%@", Body];
	}

	const char* Utf8 = [AsString UTF8String];
	FString Payload = Utf8 ? UTF8_TO_TCHAR(Utf8) : FString();

	AsyncTask(ENamedThreads::GameThread, [Payload = MoveTemp(Payload)]() mutable
	{
		extern FELIOSWebOverlay::FOnOverlayMessage GOnMessage;
		if (GOnMessage)
		{
			GOnMessage(Payload);
		}
	});
}
@end

@interface FELOverlayGestureTarget : NSObject
@end

@implementation FELOverlayGestureTarget
- (void)toggleOverlay:(id)sender
{
	(void)sender;
	extern UIView* GFELOverlayContainer;
	if (GFELOverlayContainer != nil)
	{
		GFELOverlayContainer.hidden = !GFELOverlayContainer.hidden;
	}
}
@end

// Keep these in global scope for ObjC++ compilation.
FELIOSWebOverlay::FOnOverlayMessage GOnMessage;
UIView* GFELOverlayContainer = nil;

namespace
{
	static WKWebView* GFELWebView = nil;
	static UIView* &GFELContainer = GFELOverlayContainer;
	static UITapGestureRecognizer* GFELThreeFingerToggle = nil;
	static FELOverlayGestureTarget* GFELGestureTarget = nil;

	static UIWindow* FelKeyWindow()
	{
		UIWindow* Key = nil;
		if (@available(iOS 13.0, *))
		{
			for (UIScene* Scene in UIApplication.sharedApplication.connectedScenes)
			{
				if (![Scene isKindOfClass:[UIWindowScene class]])
				{
					continue;
				}
				UIWindowScene* WS = (UIWindowScene*)Scene;
				for (UIWindow* W in WS.windows)
				{
					if (W.isKeyWindow)
					{
						Key = W;
						break;
					}
				}
				if (Key) { break; }
			}
		}
		if (!Key)
		{
			Key = UIApplication.sharedApplication.keyWindow;
		}
		return Key;
	}

	static void FelEnsureOverlay()
	{
		if (GFELWebView != nil && GFELContainer != nil)
		{
			return;
		}

		UIWindow* W = FelKeyWindow();
		if (!W)
		{
			return;
		}

		GFELContainer = [[UIView alloc] initWithFrame:W.bounds];
		GFELContainer.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
		GFELContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

		WKWebViewConfiguration* Config = [[WKWebViewConfiguration alloc] init];
		WKUserContentController* UC = [[WKUserContentController alloc] init];

		// Inject a minimal bridge helper so your dashboard can call FELBridge.post(...)
		NSString* bridgeJS =
			@"(function(){"
			" if(!window.FELBridge){"
			"  window.FELBridge={post:function(msg){try{window.webkit.messageHandlers.FELBridge.postMessage(msg);}catch(e){}}};"
			" }"
			" if(!window.FELNativeReceive){"
			"  window.FELNativeReceive=function(_){};"
			" }"
			"})();";
		WKUserScript* script = [[WKUserScript alloc] initWithSource:bridgeJS
			injectionTime:WKUserScriptInjectionTimeAtDocumentStart
			forMainFrameOnly:YES];
		[UC addUserScript:script];

		[UC addScriptMessageHandler:[[FELBridgeHandler alloc] init] name:@"FELBridge"];
		Config.userContentController = UC;

		GFELWebView = [[WKWebView alloc] initWithFrame:GFELContainer.bounds configuration:Config];
		GFELWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		GFELWebView.opaque = NO;
		GFELWebView.backgroundColor = UIColor.clearColor;
		GFELWebView.scrollView.backgroundColor = UIColor.clearColor;

		[GFELContainer addSubview:GFELWebView];

		[W addSubview:GFELContainer];
		GFELContainer.hidden = YES;

		// Global gesture to re-open overlay: 3-finger double tap.
		if (!GFELThreeFingerToggle)
		{
			GFELGestureTarget = [[FELOverlayGestureTarget alloc] init];
			GFELThreeFingerToggle = [[UITapGestureRecognizer alloc] initWithTarget:GFELGestureTarget action:@selector(toggleOverlay:)];
			GFELThreeFingerToggle.numberOfTouchesRequired = 3;
			GFELThreeFingerToggle.numberOfTapsRequired = 2;
			GFELThreeFingerToggle.cancelsTouchesInView = NO;
			[W addGestureRecognizer:GFELThreeFingerToggle];
		}
	}

	static void FelLoadUrl(const FString& Url)
	{
		if (GFELWebView == nil)
		{
			return;
		}
		FString U = Url.TrimStartAndEnd();
		if (U.IsEmpty())
		{
			return;
		}
		FTCHARToUTF8 Utf(*U);
		NSString* NSU = [NSString stringWithUTF8String:Utf.Get()];
		NSURL* NUrl = [NSURL URLWithString:NSU];
		if (!NUrl)
		{
			return;
		}
		NSURLRequest* Req = [NSURLRequest requestWithURL:NUrl];
		[GFELWebView loadRequest:Req];
	}
}

namespace FELIOSWebOverlay
{
	void EnsureCreatedAndLoaded(const FString& Url)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			FelEnsureOverlay();
			FelLoadUrl(Url);
		});
	}

	void Show()
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			if (GFELContainer) { GFELContainer.hidden = NO; }
		});
	}

	void Hide()
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			if (GFELContainer) { GFELContainer.hidden = YES; }
		});
	}

	void Eval(const FString& JavaScript)
	{
		FString JS = JavaScript;
		dispatch_async(dispatch_get_main_queue(), ^{
			if (!GFELWebView)
			{
				return;
			}
			FTCHARToUTF8 Utf(*JS);
			NSString* NSJS = [NSString stringWithUTF8String:Utf.Get()];
			[GFELWebView evaluateJavaScript:NSJS completionHandler:nil];
		});
	}

	void SetOnMessage(FOnOverlayMessage InCallback)
	{
		::GOnMessage = MoveTemp(InCallback);
	}

	bool IsCreated()
	{
		return GFELWebView != nil;
	}
}

#else

namespace FELIOSWebOverlay
{
	void EnsureCreatedAndLoaded(const FString&) {}
	void Show() {}
	void Hide() {}
	void Eval(const FString&) {}
	void SetOnMessage(FOnOverlayMessage) {}
	bool IsCreated() { return false; }
}

#endif

