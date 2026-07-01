// Copyright (c) Final Evolution Lab.
#pragma once

#include "CoreMinimal.h"

/**
 * iOS WebKit overlay bridge (WKWebView) — native "curtain" above the UE viewport.
 *
 * Implemented in ObjC++ (`FELIOSWebOverlay.mm`). No-op on non-iOS platforms.
 */
namespace FELIOSWebOverlay
{
	using FOnOverlayMessage = TFunction<void(const FString& JsonOrText)>;

	/** Creates (or reuses) the WKWebView and loads Url. Safe to call multiple times. */
	void EnsureCreatedAndLoaded(const FString& Url);

	/** Show/hide overlay (does not destroy). */
	void Show();
	void Hide();

	/** Evaluate JS in the overlay page (ignored if not created yet). */
	void Eval(const FString& JavaScript);

	/** Receive messages from JS bridge: window.webkit.messageHandlers.FELBridge.postMessage(...) */
	void SetOnMessage(FOnOverlayMessage InCallback);

	/** Returns whether the overlay has been created. */
	bool IsCreated();
}

