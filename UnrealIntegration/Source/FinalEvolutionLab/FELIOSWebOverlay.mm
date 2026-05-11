// Copyright (c) Final Evolution Lab.

#include "FELIOSWebOverlay.h"

#include "Async/Async.h"
#include "HAL/Platform.h"

#if PLATFORM_IOS

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// -----------------------------------------------------------------------------
// Shared overlay state (single WKWebView instance).
// -----------------------------------------------------------------------------
FELIOSWebOverlay::FOnOverlayMessage GOnMessage;
UIView* GFELOverlayContainer = nil;

static WKWebView* GFELWebView = nil;
static UITapGestureRecognizer* GFELThreeFingerToggle = nil;
static FELOverlayGestureTarget* GFELGestureTarget = nil;

static NSString* GFELBridgeToken = @"";
static NSSet<NSString*>* GFELAllowedHosts = nil;
static NSString* GFELLastRequestedURL = nil;
static UIView* GFELNavErrorBanner = nil;
static FELOverlayNavigationDelegate* GFELNavDelegate = nil;

static NSString* FelJsonQuotedString(NSString* s)
{
	if (s == nil)
	{
		return @"\"\"";
	}
	NSString* Esc = [s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
	Esc = [Esc stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
	return [NSString stringWithFormat:@"\"%@\"", Esc];
}

static NSString* FelNormalizeHost(NSString* host)
{
	if (host == nil || host.length == 0)
	{
		return @"";
	}
	NSString* h = host.lowercaseString;
	if ([h hasPrefix:@"www."])
	{
		return [h substringFromIndex:4];
	}
	return h;
}

static BOOL FelHostAllowed(NSString* hostNorm)
{
	if (GFELAllowedHosts == nil || GFELAllowedHosts.count == 0)
	{
		return NO;
	}
	NSString* n = FelNormalizeHost(hostNorm);
	return n.length > 0 && [GFELAllowedHosts containsObject:n];
}

static BOOL FelBridgeMessageAllowed(id BodyObj)
{
	if (GFELBridgeToken == nil || GFELBridgeToken.length == 0)
	{
		return NO;
	}
	if ([BodyObj isKindOfClass:[NSDictionary class]])
	{
		id Tok = [(NSDictionary*)BodyObj objectForKey:@"bridge_token"];
		if ([Tok isKindOfClass:[NSString class]] && [Tok isEqualToString:GFELBridgeToken])
		{
			return YES;
		}
	}
	return NO;
}

static void FelDismissNavBanner(void)
{
	if (GFELNavErrorBanner != nil)
	{
		[GFELNavErrorBanner removeFromSuperview];
		GFELNavErrorBanner = nil;
	}
}

static void FelRetryLastNavigation(void)
{
	if (GFELWebView == nil || GFELLastRequestedURL == nil)
	{
		return;
	}
	NSURL* U = [NSURL URLWithString:GFELLastRequestedURL];
	if (!U)
	{
		return;
	}
	[GFELWebView loadRequest:[NSURLRequest requestWithURL:U]];
}

static void FelShowNavigationError(NSString* message);

@interface FELOverlayNavigationDelegate : NSObject <WKNavigationDelegate>
@end

@implementation FELOverlayNavigationDelegate
- (void)webView:(WKWebView*)webView didFailProvisionalNavigation:(WKNavigation*)navigation withError:(NSError*)error
{
	(void)webView;
	(void)navigation;
	FelShowNavigationError(error.localizedDescription ?: @"Network error");
}

- (void)webView:(WKWebView*)webView didFailNavigation:(WKNavigation*)navigation withError:(NSError*)error
{
	(void)webView;
	(void)navigation;
	FelShowNavigationError(error.localizedDescription ?: @"Navigation error");
}

- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)navigation
{
	(void)webView;
	(void)navigation;
	FelDismissNavBanner();
}

- (void)webView:(WKWebView*)webView decidePolicyForNavigationAction:(WKNavigationAction*)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
	(void)webView;
	NSURL* url = navigationAction.request.URL;
	if (!url)
	{
		decisionHandler(WKNavigationActionPolicyCancel);
		return;
	}
	NSString* scheme = url.scheme.lowercaseString;
	if ([scheme isEqualToString:@"about"] || [scheme isEqualToString:@"data"])
	{
		decisionHandler(WKNavigationActionPolicyAllow);
		return;
	}
	if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"])
	{
		decisionHandler(WKNavigationActionPolicyCancel);
		return;
	}
	BOOL isMain = navigationAction.targetFrame == nil || navigationAction.targetFrame.isMainFrame;
	if (!isMain)
	{
		decisionHandler(WKNavigationActionPolicyAllow);
		return;
	}
	NSString* host = FelNormalizeHost(url.host);
	if (FelHostAllowed(host))
	{
		decisionHandler(WKNavigationActionPolicyAllow);
		return;
	}
	FelShowNavigationError(@"This navigation is blocked — host is not on the approved dashboard list.");
	decisionHandler(WKNavigationActionPolicyCancel);
}
@end

static void FelShowNavigationError(NSString* message)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		FelDismissNavBanner();
		UIView* Container = GFELOverlayContainer;
		if (Container == nil)
		{
			return;
		}

		UIView* bar = [[UIView alloc] initWithFrame:CGRectZero];
		bar.translatesAutoresizingMaskIntoConstraints = NO;
		bar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.94];
		bar.layer.cornerRadius = 12;
		bar.layer.masksToBounds = YES;

		UILabel* lab = [[UILabel alloc] initWithFrame:CGRectZero];
		lab.translatesAutoresizingMaskIntoConstraints = NO;
		lab.numberOfLines = 0;
		lab.textColor = UIColor.whiteColor;
		lab.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
		lab.text = message ?: @"Dashboard load error";

		UIAction* retryAct = [UIAction actionWithTitle:@"Retry" image:nil identifier:nil handler:^(__unused UIAction* _Nonnull action) {
			FelRetryLastNavigation();
			FelDismissNavBanner();
		}];
		UIButton* retryBtn = [UIButton buttonWithType:UIButtonTypeSystem primaryAction:retryAct];

		UIAction* hideAct = [UIAction actionWithTitle:@"Continue without dashboard" image:nil identifier:nil handler:^(__unused UIAction* _Nonnull action) {
			FelDismissNavBanner();
			if (GFELOverlayContainer != nil)
			{
				GFELOverlayContainer.hidden = YES;
			}
		}];
		UIButton* hideBtn = [UIButton buttonWithType:UIButtonTypeSystem primaryAction:hideAct];
		retryBtn.translatesAutoresizingMaskIntoConstraints = NO;
		hideBtn.translatesAutoresizingMaskIntoConstraints = NO;

		UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[ retryBtn, hideBtn ]];
		row.translatesAutoresizingMaskIntoConstraints = NO;
		row.axis = UILayoutConstraintAxisHorizontal;
		row.spacing = 16;
		row.distribution = UIStackViewDistributionFillEqually;

		UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[ lab, row ]];
		stack.translatesAutoresizingMaskIntoConstraints = NO;
		stack.axis = UILayoutConstraintAxisVertical;
		stack.spacing = 10;

		[bar addSubview:stack];
		[Container addSubview:bar];
		GFELNavErrorBanner = bar;

		UILayoutGuide* safe = Container.safeAreaLayoutGuide;
		[NSLayoutConstraint activateConstraints:@[
			[bar.leadingAnchor constraintEqualToAnchor:Container.leadingAnchor constant:12],
			[bar.trailingAnchor constraintEqualToAnchor:Container.trailingAnchor constant:-12],
			[bar.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
			[stack.topAnchor constraintEqualToAnchor:bar.topAnchor constant:12],
			[stack.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:12],
			[stack.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-12],
			[stack.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-12],
		]];
	});
}

@interface FELBridgeHandler : NSObject <WKScriptMessageHandler>
@end

@implementation FELBridgeHandler
- (void)userContentController:(WKUserContentController*)userContentController didReceiveScriptMessage:(WKScriptMessage*)message
{
	(void)userContentController;
	if (message == nil)
	{
		return;
	}
	id Body = message.body;

	if (!FelBridgeMessageAllowed(Body))
	{
		return;
	}

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
	if (GFELOverlayContainer != nil)
	{
		GFELOverlayContainer.hidden = !GFELOverlayContainer.hidden;
	}
}
@end

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
			if (Key)
			{
				break;
			}
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
	if (GFELWebView != nil && GFELOverlayContainer != nil)
	{
		return;
	}

	UIWindow* W = FelKeyWindow();
	if (!W)
	{
		return;
	}

	if (GFELOverlayContainer == nil)
	{
		GFELOverlayContainer = [[UIView alloc] initWithFrame:W.bounds];
	}
	UIView* Container = GFELOverlayContainer;
	Container.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
	Container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	WKWebViewConfiguration* Config = [[WKWebViewConfiguration alloc] init];
	WKUserContentController* UC = [[WKUserContentController alloc] init];

	NSString* TokLit = FelJsonQuotedString(GFELBridgeToken);
	NSString* bridgeJS = [NSString stringWithFormat:
		@"(function(){"
		 "window.__FEL_BRIDGE_TOKEN__=%@;"
		 "if(!window.FELBridge){"
		 " window.FELBridge={post:function(msg){try{var m=(typeof msg==='object'&&msg)?Object.assign({},msg):{raw:String(msg)};"
		 "m.bridge_token=window.__FEL_BRIDGE_TOKEN__;"
		 "window.webkit.messageHandlers.FELBridge.postMessage(m);}catch(e){}}};"
		 "}"
		 "if(!window.FELNativeReceive){window.FELNativeReceive=function(_){};}"
		 "})();",
		TokLit];
	WKUserScript* script = [[WKUserScript alloc] initWithSource:bridgeJS
		injectionTime:WKUserScriptInjectionTimeAtDocumentStart
		forMainFrameOnly:YES];
	[UC addUserScript:script];

	[UC addScriptMessageHandler:[[FELBridgeHandler alloc] init] name:@"FELBridge"];
	Config.userContentController = UC;

	GFELWebView = [[WKWebView alloc] initWithFrame:Container.bounds configuration:Config];
	GFELWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	GFELWebView.opaque = NO;
	GFELWebView.backgroundColor = UIColor.clearColor;
	GFELWebView.scrollView.backgroundColor = UIColor.clearColor;

	if (GFELNavDelegate == nil)
	{
		GFELNavDelegate = [[FELOverlayNavigationDelegate alloc] init];
	}
	GFELWebView.navigationDelegate = GFELNavDelegate;

	[Container addSubview:GFELWebView];

	[W addSubview:Container];
	Container.hidden = YES;

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
	if (!NUrl || NUrl.host.length == 0)
	{
		FelShowNavigationError(@"Invalid dashboard URL.");
		return;
	}
	if (!FelHostAllowed(FelNormalizeHost(NUrl.host)))
	{
		FelShowNavigationError(@"Dashboard URL host is not allowlisted.");
		return;
	}
	GFELLastRequestedURL = NUrl.absoluteString;
	NSURLRequest* Req = [NSURLRequest requestWithURL:NUrl];
	[GFELWebView loadRequest:Req];
}

namespace FELIOSWebOverlay
{
	void EnsureCreatedAndLoadedWithSecurity(const FString& Url, const FString& BridgeToken, const TArray<FString>& AllowedHosts)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			NSMutableSet* S = [NSMutableSet set];
			for (const FString& H : AllowedHosts)
			{
				FString T = H.TrimStartAndEnd().ToLower();
				if (T.StartsWith(TEXT("www.")))
				{
					T = T.Mid(4);
				}
				if (T.IsEmpty())
				{
					continue;
				}
				FTCHARToUTF8 Utf(*T);
				NSString* NSH = [NSString stringWithUTF8String:Utf.Get()];
				if (NSH)
				{
					[S addObject:NSH];
				}
			}
			GFELAllowedHosts = [S copy];

			FTCHARToUTF8 TokUtf(*BridgeToken);
			GFELBridgeToken = [NSString stringWithUTF8String:TokUtf.Get()];

			FelEnsureOverlay();
			FelLoadUrl(Url);
		});
	}

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
			if (GFELOverlayContainer)
			{
				GFELOverlayContainer.hidden = NO;
			}
		});
	}

	void Hide()
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			if (GFELOverlayContainer)
			{
				GFELOverlayContainer.hidden = YES;
			}
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
	void EnsureCreatedAndLoadedWithSecurity(const FString&, const FString&, const TArray<FString>&) {}
	void EnsureCreatedAndLoaded(const FString&) {}
	void Show() {}
	void Hide() {}
	void Eval(const FString&) {}
	void SetOnMessage(FOnOverlayMessage) {}
	bool IsCreated() { return false; }
}

#endif
