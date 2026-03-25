// Copyright (c) Final Evolution Lab.
// Unreal → Swift host shell (NSNotification on iOS; no-op / log on other platforms).
// Pairs with FinalEvolutionLab FELBridgeNotifications + FELUnrealSessionImporter.

#pragma once

#include "CoreMinimal.h"

struct FFELMatchResultSummary;

struct FELNativeBridge
{
	/** Call after session_results.json is written; Swift importer ingests Vault + PRQ history. */
	static void NotifySessionResultsReady(const FString& AbsolutePathToSessionResultsJson);

	/** User tapped Return to Dashboard on UFELMatchResultsWidget — host may tear down UE view. */
	static void NotifyExitToDashboardRequested();

	/** User tapped Share Your Evolution — iOS host renders Athlete Card and opens share sheet. */
	static void NotifyShareEvolutionRequested();

	/** iOS shell: UINotificationFeedbackGenerator — Academy terminal interact. */
	static void NotifyAcademyTerminalEngaged();

	/** iOS shell: success pulse when a Vertical Velocity Academy module is recorded this session. */
	static void NotifyAcademyModuleCompletionPulse();

	/** iOS shell: match-end feedback (elite dunk vs standard completion). */
	static void NotifyMatchCompleteIOSFeedback(const FFELMatchResultSummary& Summary);

	/** PNG bytes of SceneCapture2D avatar — Swift `FELAvatarSnapshotStore`. */
	static void NotifyAvatarSnapshotPng(const TArray<uint8>& PngBytes);

	/** Absolute path to Neuro-Flow `.mp4` for Photos / Recents (Swift `PHPhotoLibrary`). */
	static void NotifyNeuroFlowMp4Exported(const FString& AbsolutePathToMp4);

	/**
	 * iOS: high-intensity impact haptic for Perfect dunk (`kind` 4) or Perfect strike (`kind` 5) via `FelUnrealUINotificationFeedback`.
	 * Swift `FELHaptics.unrealUINotificationFeedback` maps these to UIImpactFeedbackGenerator (heavy/rigid).
	 */
	static void NotifyPerfectImpactHaptics(bool bPerfectStrike);

	/** iOS: sharp "warp contact" thud when motion-warp target is reached (`kind` 6) — ProMotion-safe, paired with Perfect dunk. */
	static void NotifyPerfectDunkWarpThud();

	/** iOS: Bonds Apex Sonic Flare at jump apex (`kind` 7) — paired with Niagara apex spawn; PS5 uses `PlayDynamicForceFeedback` in character. */
	static void NotifySonicFlareApexHaptics();

	/** Swift presents `UFELShardMarketplaceView` (NSNotification `FelUnrealShardMarketplaceRequest`). */
	static void NotifyShardMarketplaceHotspot(const FString& HotspotId, const FString& LumaCaptureId);

	/** iOS: level is running — cancels Swift arena handshake watchdog (`FELUnrealLevelLoaded`). */
	static void NotifyLevelLoaded(const FString& MapName);

	/** iOS / Mac host: JSON from `GenerateAthletePerformanceJSON` — Swift caches for Share + fatigue banner. */
	static void NotifyCoachPerformanceJSON(const FString& JsonUtf8);

	/** iOS host: `UFELSaveGame::ExportSaveToJSON` (XOR + Base64) — manual Firebase / iCloud bridge. */
	static void NotifyUniversalSyncExport(const FString& Base64Payload);

	/** iOS: Bonds Apex ≥40" demo replay window started — Swift `felHeroMomentExportReady` + ReplayKit hero clip. */
	static void NotifyHeroMomentExportReady(float EstimatedApexHeightInches);

	/**
	 * iOS host: Vertical Velocity Academy Push 1,2 — `BeatPhaseMod3` matches `UFELInputManager::PlayPushTwelveClinicalHaptic`
	 * (0 = penultimate Push, 1–2 = takeoff beats). Drives Swift `FELHaptics.pushPenultimateStrideClinical`.
	 */
	static void NotifyPenultimateStrideRhythm(int32 BeatPhaseMod3);
};
