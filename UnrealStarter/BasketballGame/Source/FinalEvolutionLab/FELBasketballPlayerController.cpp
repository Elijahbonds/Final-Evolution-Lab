// Copyright (c) Final Evolution Lab.

#include "FELBasketballPlayerController.h"
#include "FELBasketballCharacter.h"
#include "FELConsoleHapticBridge.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FELMatchTypes.h"
#include "UFELBaseballBattingSubsystem.h"
#include "FELReadinessTypes.h"
#include "UFELSaveGame.h"
#include "FELAthleteStatsTypes.h"
#include "FELNativeBridge.h"
#include "Misc/DateTime.h"
#include "FELShopInteractionActor.h"
#include "FELNeuroDebugHUDWidget.h"
#include "FELNeuroMechanicBridgeSubsystem.h"
#include "UFELInputComponent.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "InputAction.h"
#include "InputActionValue.h"
#include "Engine/GameInstance.h"
#include "Engine/EngineTypes.h"
#include "Engine/LocalPlayer.h"
#include "HAL/Platform.h"
#include "HAL/PlatformTime.h"
#include "InputCoreTypes.h"
#include "CollisionQueryParams.h"
#include "Engine/EngineTypes.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PlayerInput.h"
#include "GameFramework/ForceFeedbackParameters.h"
#include "Camera/CameraComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Engine/Engine.h"
#include "Kismet/GameplayStatics.h"
#include "RenderingThread.h"
#include "TimerManager.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

#ifndef PIXEL_STREAMING_ENABLED
#define PIXEL_STREAMING_ENABLED 0
#endif

namespace
{
void FEL_ApplyManualExposureBaselineToFollowCamera(UCameraComponent* FollowCamera)
{
	if (!FollowCamera)
	{
		return;
	}
	FPostProcessSettings& PP = FollowCamera->PostProcessSettings;
	PP.bOverride_AutoExposureMethod = true;
	PP.AutoExposureMethod = EAutoExposureMethod::AEM_Manual;
	PP.bOverride_AutoExposureBias = true;
	PP.AutoExposureBias = 1.0f;
}

/** Stock UCameraComponent has no SetAutoExposureBias; keep parity with requested API. */
void FEL_ForceCameraAutoExposureBias(UCameraComponent* FollowCamera, const float Bias)
{
	if (!FollowCamera)
	{
		return;
	}
	FPostProcessSettings& PP = FollowCamera->PostProcessSettings;
	PP.bOverride_AutoExposureBias = true;
	PP.AutoExposureBias = Bias;
}

bool FEL_IsSovereignShopMap(const UWorld* World)
{
	if (!World)
	{
		return false;
	}
	const FString N = UGameplayStatics::GetCurrentLevelName(World, true);
	return N.Contains(TEXT("SovereignShop")) || N.Contains(TEXT("L_SovereignShop_Luma")) || N.Contains(TEXT("Luma_Venice_Shop"));
}

FString FEL_FatigueStateToJsonString(const EFELFatigueState S)
{
	switch (S)
	{
	case EFELFatigueState::Fatigued:
		return TEXT("Fatigued");
	case EFELFatigueState::Normal:
		return TEXT("Normal");
	case EFELFatigueState::Inconclusive:
		return TEXT("Inconclusive");
	default:
		return TEXT("Unknown");
	}
}
} // namespace

#if PLATFORM_IOS || PLATFORM_ANDROID
#define FEL_TOUCH_DRIVE 1
#else
#define FEL_TOUCH_DRIVE 0
#endif

void AFELBasketballPlayerController::InputLatencyMonitor_MarkPress()
{
	InputLatencyPressWallSeconds = FPlatformTime::Seconds();
	bInputLatencyAwaitingLaunch = true;
}

void AFELBasketballPlayerController::InputLatencyMonitor_OnCharacterLaunch()
{
	if (!bInputLatencyAwaitingLaunch || InputLatencyPressWallSeconds < 0.0)
	{
		return;
	}
	const double Now = FPlatformTime::Seconds();
	const double Ms = (Now - InputLatencyPressWallSeconds) * 1000.0;
	bInputLatencyAwaitingLaunch = false;
	InputLatencyPressWallSeconds = -1.0;
	// AUDIT_QUALITY / SHIP_CRITERIA — one frame @60 Hz ≈ 16.67 ms ("Instant Ignition").
	constexpr double kOneFrame60Ms = 1000.0 / 60.0;
	if (Ms > kOneFrame60Ms)
	{
		UE_LOG(LogTemp, Warning, TEXT("FEL InputLatencyMonitor: Bonds Apex launch delayed %.2f ms (threshold %.2f ms)"), Ms, kOneFrame60Ms);
		if (GEngine)
		{
			GEngine->AddOnScreenDebugMessage(
				-1,
				2.5f,
				FColor::Orange,
				FString::Printf(TEXT("Performance: input→launch %.1f ms (target ≤16.6 ms)"), Ms));
		}
	}
}

void AFELBasketballPlayerController::PlayBondsBounceHaptics(EFELJumpTimingBand Band, float TimingLeakFactor)
{
	const float Leak = FMath::Clamp(TimingLeakFactor, 0.f, 1.f);

	if (Band == EFELJumpTimingBand::Perfect)
	{
		// Sharp, powerful hit — right large motor (heavy impulse).
		PlayDynamicForceFeedback(1.f, 0.11f, false, false, true, false, EDynamicForceFeedbackAction::Start);
		return;
	}

	if (Band == EFELJumpTimingBand::Early || Band == EFELJumpTimingBand::Late || Leak < 0.75f)
	{
		// Low-frequency rumble — small motors, longer duration = energy loss (see FELKineticLeakage timing curve).
		const float RumbleAmp = FMath::Lerp(0.58f, 0.26f, Leak);
		PlayDynamicForceFeedback(RumbleAmp, 0.42f, false, true, false, true, EDynamicForceFeedbackAction::Start);
		return;
	}

	if (Band == EFELJumpTimingBand::Good)
	{
		PlayDynamicForceFeedback(0.62f, 0.09f, false, false, true, true, EDynamicForceFeedbackAction::Start);
	}
}

AFELBasketballPlayerController::AFELBasketballPlayerController()
{
	bShowMouseCursor = false;
}

void AFELBasketballPlayerController::BeginPlay()
{
	Super::BeginPlay();

#if FEL_TOUCH_DRIVE
	if (IsLocalPlayerController() && !IA_SignatureVerticalSwipe)
	{
		UE_LOG(LogTemp, Error,
			TEXT("FATAL: IA_SignatureVerticalSwipe unassigned in IMC_FELMobile — assign the Enhanced Input Action on AFELBasketballPlayerController or vertical swipe / signature will not fire."));
	}
	if (MobileTouchMappingContext && IsLocalPlayerController())
	{
		if (ULocalPlayer* LP = GetLocalPlayer())
		{
			if (UEnhancedInputLocalPlayerSubsystem* Subsys = LP->GetSubsystem<UEnhancedInputLocalPlayerSubsystem>())
			{
				Subsys->AddMappingContext(MobileTouchMappingContext, 100);
			}
		}
	}
#endif

	SwitchInputMode();

#if !UE_BUILD_SHIPPING
	// Editor + Development/Test: live Neuro HUD (stripped from Shipping compiles).
	const TSubclassOf<UFELNeuroDebugHUDWidget> WidgetClass = NeuroDebugHUDWidgetClass
		? NeuroDebugHUDWidgetClass
		: TSubclassOf<UFELNeuroDebugHUDWidget>(UFELNeuroDebugHUDWidget::StaticClass());
	NeuroDebugHUDWidgetInstance = CreateWidget<UFELNeuroDebugHUDWidget>(this, WidgetClass);
	if (NeuroDebugHUDWidgetInstance)
	{
		NeuroDebugHUDWidgetInstance->AddToViewport(100);
	}
#endif
}

void AFELBasketballPlayerController::OnPossess(APawn* InPawn)
{
	Super::OnPossess(InPawn);
	if (UWorld* const WLoad = GetWorld())
	{
		WLoad->GetTimerManager().SetTimer(
			LoadGearRetryTimerHandle,
			this,
			&AFELBasketballPlayerController::LoadGearState,
			0.5f,
			false);
	}
	if (InPawn)
	{
		// Force viewport / PlayerCameraManager onto the Digital Twin pawn (fixes black screen when view target never latched).
		SetViewTargetWithBlend(InPawn, 0.f, VTBlend_Linear, 0.f, false);
	}
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(RenderingWarmupFlushTimerHandle);
		W->GetTimerManager().SetTimer(
			RenderingWarmupFlushTimerHandle,
			this,
			&AFELBasketballPlayerController::OnDelayedRenderingFlush,
			2.f,
			false);
	}
}

void AFELBasketballPlayerController::OnDelayedRenderingFlush()
{
	FlushRenderingCommands();
	if (UWorld* const W = GetWorld())
	{
		const FString CurrentMap = W->GetMapName();
		UE_LOG(LogTemp, Warning, TEXT("GOLD MASTER: Rendering Flush on Map: %s"), *CurrentMap);
		if (GEngine)
		{
			GEngine->AddOnScreenDebugMessage(-1, 5.f, FColor::Cyan, FString::Printf(TEXT("Map: %s"), *CurrentMap));
		}
	}
	if (AFELBasketballCharacter* Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		FEL_ApplyManualExposureBaselineToFollowCamera(Ch->FollowCamera);
		if (Ch->FollowCamera)
		{
			FEL_ForceCameraAutoExposureBias(Ch->FollowCamera, 1.0f);
		}
	}
}

void AFELBasketballPlayerController::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	SaveGearState();
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(RenderingWarmupFlushTimerHandle);
		W->GetTimerManager().ClearTimer(DeferredShootTapTimerHandle);
		W->GetTimerManager().ClearTimer(LoadGearRetryTimerHandle);
	}
	Super::EndPlay(EndPlayReason);
}

void AFELBasketballPlayerController::SaveGearState()
{
	UFELSaveGame* Save = nullptr;
	if (UGameplayStatics::DoesSaveGameExist(UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex))
	{
		Save = Cast<UFELSaveGame>(UGameplayStatics::LoadGameFromSlot(UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex));
	}
	if (!Save)
	{
		Save = Cast<UFELSaveGame>(UGameplayStatics::CreateSaveGameObject(UFELSaveGame::StaticClass()));
	}
	if (!Save)
	{
		return;
	}
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		Save->CachedGearJumpMult = Ch->GetCachedGearJumpMult();

		FFELReadinessSnapshot Snap;
		if (UGameInstance* GI = GetGameInstance())
		{
			if (UFELNeuroMechanicBridgeSubsystem* Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
			{
				Br->GetCachedSnapshot(Snap);
			}
		}
		if (UWorld* W = GetWorld())
		{
			if (AFELBasketballGameState* GS = W->GetGameState<AFELBasketballGameState>())
			{
				const FFELReadinessSnapshot& GSS = GS->GetReadinessSnapshot();
				if (GSS.FlightTimeSeconds > 0.0 || GSS.VerticalEstimateInches > 0.0)
				{
					Snap = GSS;
				}
			}
		}

		const float PeakZ = Ch->GetLastJumpPeakZVelocityForStats();
		const bool bCompromised = UFELSaveGame::Validation_StressTest_IsDataCompromised(Snap, PeakZ);

		if (!bCompromised && Ch->GetEquippedSignatureTrait() == EFELSignatureTrait::Bonds_Apex_Ignition)
		{
			Save->UnlockedSovereignSkins.AddUnique(TEXT("Bonds_Apex_Ignition"));
		}
#if !UE_BUILD_SHIPPING
		else if (bCompromised && Ch->GetEquippedSignatureTrait() == EFELSignatureTrait::Bonds_Apex_Ignition)
		{
			UE_LOG(LogTemp, Warning, TEXT("FEL Validation_StressTest: Sovereign gear bonus withheld — scan vs JumpZ physics inconsistent (AUDIT_BIOMECHANICAL_ECOSYSTEM)."));
		}
#endif

		if (PeakZ > 40.f && !bCompromised)
		{
			FFELAthleteStats Sample;
			Sample.JumpHeight = PeakZ;
			switch (Ch->GetEquippedSignatureTrait())
			{
			case EFELSignatureTrait::Bonds_Apex_Ignition:
				Sample.GearID = TEXT("Bonds_Apex_Ignition");
				break;
			default:
				Sample.GearID = TEXT("Base");
				break;
			}
			Sample.Timestamp = FDateTime::UtcNow();
			Save->PerformanceHistory.Add(Sample);
			while (Save->PerformanceHistory.Num() > 256)
			{
				Save->PerformanceHistory.RemoveAt(0);
			}
		}
	}
	if (UWorld* const W = GetWorld())
	{
		Save->CurrentVenue = UGameplayStatics::GetCurrentLevelName(W, true);
	}
	UGameplayStatics::SaveGameToSlot(Save, UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex);
#if PLATFORM_IOS
	{
		const FString CoachJson = GenerateAthletePerformanceJSON();
		FELNativeBridge::NotifyCoachPerformanceJSON(CoachJson);
		const FString SyncB64 = UFELSaveGame::ExportSaveToJSON(Save);
		FELNativeBridge::NotifyUniversalSyncExport(SyncB64);
	}
#endif
}

void AFELBasketballPlayerController::LoadGearState()
{
	if (!UGameplayStatics::DoesSaveGameExist(UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex))
	{
		return;
	}
	UFELSaveGame* const Save = Cast<UFELSaveGame>(
		UGameplayStatics::LoadGameFromSlot(UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex));
	if (!Save)
	{
		return;
	}
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		Ch->ApplyPersistedGearState(Save);
	}
}

void AFELBasketballPlayerController::EnsureBondsApexIgnitionUnlockedAndSave()
{
	UFELSaveGame* Save = nullptr;
	if (UGameplayStatics::DoesSaveGameExist(UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex))
	{
		Save = Cast<UFELSaveGame>(UGameplayStatics::LoadGameFromSlot(UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex));
	}
	if (!Save)
	{
		Save = Cast<UFELSaveGame>(UGameplayStatics::CreateSaveGameObject(UFELSaveGame::StaticClass()));
	}
	if (!Save)
	{
		return;
	}
	Save->UnlockedSovereignSkins.AddUnique(TEXT("Bonds_Apex_Ignition"));
	UGameplayStatics::SaveGameToSlot(Save, UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex);
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		Ch->ApplyPersistedGearState(Save);
	}
}

void AFELBasketballPlayerController::PlayerTick(float DeltaTime)
{
#if PLATFORM_IOS || PLATFORM_ANDROID
	if (PlayerInput)
	{
		const bool bPad = PlayerInput->GetJoystickCount() > 0;
		if (bPad != bGamepadMobileSignatureOverride)
		{
			SwitchInputMode();
		}
	}
#endif
	Super::PlayerTick(DeltaTime);
#if FEL_TOUCH_DRIVE
	ProcessTouchDrive(DeltaTime);
#else
	SignatureGestureDebounce = FMath::Max(0.f, SignatureGestureDebounce - DeltaTime);
	if (AFELBasketballCharacter* Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		const float Sprint01 = FMath::Max(HandshakeKeyboardSprint01, EnhancedInputSprint01);
		Ch->ApplyTouchDriveInput(0.f, 0.f, 0.f, Sprint01, 0.f, DeltaTime);
		if (bEnhancedJumpQueued)
		{
			InputLatencyMonitor_MarkPress();
			bool bBaseballSwing = false;
			if (CachedAppliedArenaMode == EFELArenaMode::Baseball)
			{
				if (AFELBasketballGameMode* GM = GetWorld()->GetAuthGameMode<AFELBasketballGameMode>())
				{
					if (GM->MatchPhase == EFELMatchPhase::InProgress)
					{
						FEL_RequestBaseballSwing();
						bBaseballSwing = true;
					}
				}
			}
			if (!bBaseballSwing)
			{
				if (UFELInputComponent* FEL = Cast<UFELInputComponent>(Ch->InputComponent))
				{
					FEL->BufferJump();
				}
			}
		}
		bEnhancedJumpQueued = false;
	}
	EnhancedInputSprint01 = 0.f;
#endif
#if PLATFORM_PS5
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		FELConsoleHapticBridge::UpdateGatherTriggerResistance(this, Ch->TouchGatherBlend01, DeltaTime);
	}
#endif
}
#if FEL_TOUCH_DRIVE
void AFELBasketballPlayerController::InputTouch(const uint32 Handle, const ETouchType::Type Type, const FVector2D Location)
{
	Super::InputTouch(Handle, Type, Location);
	// Drive runs in PlayerTick after Enhanced Input so IMC gestures merge with touch sampling in one pass.
	(void)Handle;
	(void)Type;
	(void)Location;
}
#endif

void AFELBasketballPlayerController::OnIASprintLongPress(const FInputActionValue& Value)
{
	if (Value.GetValueType() == EInputActionValueType::Boolean)
	{
		EnhancedInputSprint01 = Value.Get<bool>() ? 1.f : 0.f;
	}
	else
	{
		EnhancedInputSprint01 = FMath::Clamp(Value.GetMagnitude(), 0.f, 1.f);
	}
}

void AFELBasketballPlayerController::OnIASignatureVerticalSwipe(const FInputActionValue& Value)
{
#if PLATFORM_IOS || PLATFORM_ANDROID
	if (bGamepadMobileSignatureOverride)
	{
		return;
	}
#endif
	const float Mag = FMath::Clamp(Value.GetMagnitude(), 0.f, 1.f);
	if (Mag < 0.22f)
	{
		return;
	}
	if (SignatureGestureDebounce > 0.f)
	{
		return;
	}
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		Ch->ExecuteSignatureMove();
		SignatureGestureDebounce = 0.45f;
	}
}

void AFELBasketballPlayerController::OnIASignatureGamepadStick(const FInputActionValue& Value)
{
#if PLATFORM_IOS || PLATFORM_ANDROID
	if (!bGamepadMobileSignatureOverride)
	{
		return;
	}
#endif
	float Y = 0.f;
	if (Value.GetValueType() == EInputActionValueType::Axis2D)
	{
		Y = Value.Get<FVector2D>().Y;
	}
	else if (Value.GetValueType() == EInputActionValueType::Axis1D)
	{
		Y = Value.Get<float>();
	}
	else
	{
		Y = Value.GetMagnitude();
	}
	// Default UE gamepad: stick up = negative Y.
	if (Y > -0.55f || SignatureGestureDebounce > 0.f)
	{
		return;
	}
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		Ch->ExecuteSignatureMove();
		SignatureGestureDebounce = 0.45f;
	}
}

void AFELBasketballPlayerController::OnIAJump(const FInputActionValue& Value)
{
	(void)Value;
	InputLatencyMonitor_MarkPress();
	bEnhancedJumpQueued = true;
	// Standalone / host: same-frame swing when IA_Jump maps to bat (Wii Baseball).
	if (TryHandleBaseballJumpAsSwing())
	{
		bEnhancedJumpQueued = false;
	}
}

void AFELBasketballPlayerController::OnIAShootTap(const FInputActionValue& Value)
{
	(void)Value;
	if (CachedAppliedArenaMode == EFELArenaMode::Baseball)
	{
		if (AFELBasketballGameMode* GM = GetWorld()->GetAuthGameMode<AFELBasketballGameMode>())
		{
			if (GM->MatchPhase == EFELMatchPhase::InProgress)
			{
				InputLatencyMonitor_MarkPress();
				FEL_RequestBaseballSwing();
				return;
			}
		}
	}
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		if (Ch->IsSignatureMoveWindowActive())
		{
			return;
		}
		InputLatencyMonitor_MarkPress();
		if (UFELInputComponent* FEL = Cast<UFELInputComponent>(Ch->InputComponent))
		{
			FEL->BufferJump();
		}
	}
}

void AFELBasketballPlayerController::OnIASignatureDoubleTap(const FInputActionValue& Value)
{
	(void)Value;
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		Ch->ExecuteSignatureMove();
	}
}

void AFELBasketballPlayerController::OnDeferredShootTap()
{
	if (CachedAppliedArenaMode == EFELArenaMode::Baseball)
	{
		if (AFELBasketballGameMode* GM = GetWorld()->GetAuthGameMode<AFELBasketballGameMode>())
		{
			if (GM->MatchPhase == EFELMatchPhase::InProgress)
			{
				InputLatencyMonitor_MarkPress();
				FEL_RequestBaseballSwing();
				RightHalfLastTapReleaseTime = -100.f;
				return;
			}
		}
	}
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		if (Ch->IsSignatureMoveWindowActive())
		{
			RightHalfLastTapReleaseTime = -100.f;
			return;
		}
		InputLatencyMonitor_MarkPress();
		if (UFELInputComponent* FEL = Cast<UFELInputComponent>(Ch->InputComponent))
		{
			FEL->BufferJump();
		}
		Ch->TryShootTapAscentRimSnap();
	}
	RightHalfLastTapReleaseTime = -100.f;
}

void AFELBasketballPlayerController::ProcessTouchDrive(const float DeltaSeconds)
{
	// Gold Master 3D handshake: Hold left stick = sprint; Tap right = shoot (deferred); Double-tap right = ExecuteSignatureMove
	// (Enhanced Input parity via IA_* + IMC; touch sampling merges same frame after Super::PlayerTick).
	AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn());
	if (!Ch)
	{
		return;
	}
	SignatureGestureDebounce = FMath::Max(0.f, SignatureGestureDebounce - DeltaSeconds);

	int32 SizeX = 0;
	int32 SizeY = 0;
	GetViewportSize(SizeX, SizeY);
	if (SizeX < 8 || SizeY < 8)
	{
		return;
	}

	float X1 = 0.f;
	float Y1 = 0.f;
	bool b1 = false;
	GetInputTouchState(ETouchIndex::Touch1, X1, Y1, b1);

	float X2 = 0.f;
	float Y2 = 0.f;
	bool b2 = false;
	GetInputTouchState(ETouchIndex::Touch2, X2, Y2, b2);

	const float n1x = X1 / SizeX;
	const float n1y = Y1 / SizeY;
	const float n2x = X2 / SizeX;
	const float n2y = Y2 / SizeY;
	const float PrevTouch1X = LastTouch1Norm.X;
	const float PrevTouch1Y = LastTouch1Norm.Y;
	const float PrevTouch2Y = LastTouch2Norm.Y;

	bGatherPadActive = b2 && n2y > 0.64f;

	if (bTouch1WasPressed && !b1)
	{
		if (UWorld* W = GetWorld())
		{
			const float Dur = W->GetTimeSeconds() - Touch1PressTime;
			if (Dur >= 0.f && Dur < 0.125f && !bTouch1MovedSignificantly)
			{
				bool bBaseballTap = false;
				if (CachedAppliedArenaMode == EFELArenaMode::Baseball && !FEL_IsSovereignShopMap(W))
				{
					if (AFELBasketballGameMode* GM = W->GetAuthGameMode<AFELBasketballGameMode>())
					{
						if (GM->MatchPhase == EFELMatchPhase::InProgress)
						{
							InputLatencyMonitor_MarkPress();
							FEL_RequestBaseballSwing();
							bBaseballTap = true;
						}
					}
				}
				if (!bBaseballTap)
				{
					bool bShopHandled = false;
					if (FEL_IsSovereignShopMap(W))
					{
						bShopHandled = TryTraceShopHotspotOnTap(PrevTouch1X, PrevTouch1Y, SizeX, SizeY);
					}
					if (!bShopHandled && PrevTouch1X >= 0.52f)
					{
						const float NowTap = W->GetTimeSeconds();
						if (RightHalfLastTapReleaseTime > 0.f && (NowTap - RightHalfLastTapReleaseTime) < 0.42f)
						{
							W->GetTimerManager().ClearTimer(DeferredShootTapTimerHandle);
							Ch->ExecuteSignatureMove();
							RightHalfLastTapReleaseTime = -100.f;
						}
						else
						{
							RightHalfLastTapReleaseTime = NowTap;
							W->GetTimerManager().SetTimer(
								DeferredShootTapTimerHandle,
								this,
								&AFELBasketballPlayerController::OnDeferredShootTap,
								0.1f,
								false);
						}
					}
				}
			}
		}
	}

	if (!bTouch1WasPressed && b1)
	{
		if (UWorld* W = GetWorld())
		{
			Touch1PressTime = W->GetTimeSeconds();
		}
		bTouch1MovedSignificantly = false;
	}

	float MoveForward = 0.f;
	float MoveRight = 0.f;
	float TurnDelta = 0.f;
	float Sprint01 = 0.f;

	if (b1)
	{
		if (n1x < 0.48f)
		{
			static const FVector2D kStickCenter(0.24f, 0.62f);
			static constexpr float kMaxRadius = 0.17f;
			FVector2D Delta(n1x - kStickCenter.X, n1y - kStickCenter.Y);
			float Len = Delta.Size();
			if (Len > kMaxRadius && Len > 1e-5f)
			{
				Delta *= (kMaxRadius / Len);
				Len = kMaxRadius;
			}
			if (Len > 0.04f)
			{
				bTouch1MovedSignificantly = true;
			}
			MoveForward = FMath::Clamp(-Delta.Y / kMaxRadius, -1.f, 1.f);
			MoveRight = FMath::Clamp(Delta.X / kMaxRadius, -1.f, 1.f);
			const float Mag = Len / kMaxRadius;
			// Enhanced Input parity: long press on stick zone = sprint (hold past threshold, deflection past gate).
			if (Mag > 0.35f && Touch1PressTime > 0.f && GetWorld())
			{
				const float Held = GetWorld()->GetTimeSeconds() - Touch1PressTime;
				if (Held > 0.22f)
				{
					Sprint01 = FMath::Clamp((Mag - 0.35f) / 0.65f, 0.f, 1.f) * FMath::Clamp((Held - 0.22f) / 0.28f, 0.f, 1.f);
				}
			}
		}
		else
		{
			TurnDelta = (n1x - LastTouch1Norm.X) * TouchLookSensitivity;
			bTouch1MovedSignificantly = true;
		}
	}

	if (b1)
	{
		LastTouch1Norm = FVector2D(n1x, n1y);
	}
	bTouch1WasPressed = b1;
	if (b2)
	{
		LastTouch2Norm = FVector2D(n2x, n2y);
	}

	// Right half: fast vertical swipe up = Signature Move (IMC: IA_SignatureVerticalSwipe). Gather is second-finger pad only.
	if (!bGamepadMobileSignatureOverride && b1 && n1x >= 0.52f && DeltaSeconds > 1e-5f)
	{
		const float UpVel = FMath::Max(0.f, PrevTouch1Y - n1y);
		const float UpSpeed = UpVel / DeltaSeconds;
		if (UpSpeed > 2.4f && !FEL_IsSovereignShopMap(GetWorld()) && SignatureGestureDebounce <= 0.f)
		{
			Ch->ExecuteSignatureMove();
			SignatureGestureDebounce = 0.45f;
		}
	}

	const float Gather01 = bGatherPadActive ? 1.f : 0.f;
	Sprint01 = FMath::Max(Sprint01, EnhancedInputSprint01);

	if (!bGamepadMobileSignatureOverride && SignatureGestureDebounce <= 0.f && b1 && b2 && n1x > 0.5f && n2x > 0.5f && DeltaSeconds > 1e-5f)
	{
		const float U1 = PrevTouch1Y - n1y;
		const float U2 = PrevTouch2Y - n2y;
		const float S1 = U1 / DeltaSeconds;
		const float S2 = U2 / DeltaSeconds;
		if (U1 > 0.045f && U2 > 0.045f && S1 > 2.2f && S2 > 2.2f && !FEL_IsSovereignShopMap(GetWorld()))
		{
			Ch->ExecuteSignatureMove();
			SignatureGestureDebounce = 0.45f;
		}
	}

	Ch->ApplyTouchDriveInput(MoveForward, MoveRight, TurnDelta, Sprint01, Gather01, DeltaSeconds);

	if (bEnhancedJumpQueued)
	{
		InputLatencyMonitor_MarkPress();
		bool bBaseballSwing = false;
		if (CachedAppliedArenaMode == EFELArenaMode::Baseball)
		{
			if (AFELBasketballGameMode* GM = GetWorld()->GetAuthGameMode<AFELBasketballGameMode>())
			{
				if (GM->MatchPhase == EFELMatchPhase::InProgress)
				{
					FEL_RequestBaseballSwing();
					bBaseballSwing = true;
				}
			}
		}
		if (!bBaseballSwing)
		{
			if (UFELInputComponent* FEL = Cast<UFELInputComponent>(Ch->InputComponent))
			{
				FEL->BufferJump();
			}
		}
	}

	EnhancedInputSprint01 = 0.f;
	bEnhancedJumpQueued = false;
}

bool AFELBasketballPlayerController::TryTraceShopHotspotOnTap(
	const float ScreenNormX,
	const float ScreenNormY,
	const int32 ViewportSizeX,
	const int32 ViewportSizeY)
{
	UWorld* const W = GetWorld();
	if (!W || !PlayerCameraManager)
	{
		return false;
	}
	const float SX = ScreenNormX * static_cast<float>(ViewportSizeX);
	const float SY = ScreenNormY * static_cast<float>(ViewportSizeY);
	FVector WorldLoc;
	FVector WorldDir;
	if (!UGameplayStatics::DeprojectScreenToWorld(this, FVector2D(SX, SY), WorldLoc, WorldDir))
	{
		return false;
	}
	WorldDir.Normalize();
	FCollisionQueryParams Params(SCENE_QUERY_STAT(FELShopTap), false, this);
	if (const APawn* P = GetPawn())
	{
		Params.AddIgnoredActor(P);
	}
	FHitResult Hit;
	const FVector End = WorldLoc + WorldDir * 12000.f;
	if (!W->LineTraceSingleByChannel(Hit, WorldLoc, End, ECC_Visibility, Params))
	{
		return false;
	}
	AActor* HitActor = Hit.GetActor();
	if (!HitActor && Hit.Component.IsValid())
	{
		HitActor = Hit.Component->GetOwner();
	}
	if (!HitActor)
	{
		return false;
	}
	if (AFELShopInteractionActor* Shop = Cast<AFELShopInteractionActor>(HitActor))
	{
		Shop->ActivateFromTap();
		return true;
	}
	return false;
}

void AFELBasketballPlayerController::SetupInputComponent()
{
	Super::SetupInputComponent();

#if FEL_TOUCH_DRIVE
	if (UEnhancedInputComponent* const EIC = Cast<UEnhancedInputComponent>(InputComponent))
	{
		if (IA_SprintLongPress)
		{
			EIC->BindAction(IA_SprintLongPress, ETriggerEvent::Triggered, this, &AFELBasketballPlayerController::OnIASprintLongPress);
			EIC->BindAction(IA_SprintLongPress, ETriggerEvent::Ongoing, this, &AFELBasketballPlayerController::OnIASprintLongPress);
		}
		if (IA_SignatureVerticalSwipe)
		{
			EIC->BindAction(IA_SignatureVerticalSwipe, ETriggerEvent::Triggered, this, &AFELBasketballPlayerController::OnIASignatureVerticalSwipe);
		}
		else
		{
			const FString Msg = TEXT("[FEL] IA_SignatureVerticalSwipe MISSING — assign UInputAction on PlayerController + IMC_FELMobile");
			UE_LOG(LogTemp, Error, TEXT("%s"), *Msg);
			if (GEngine)
			{
				GEngine->AddOnScreenDebugMessage(
					-1,
					25.f,
					FColor::Red,
					Msg);
			}
		}
		if (IA_JumpPrimary)
		{
			EIC->BindAction(IA_JumpPrimary, ETriggerEvent::Started, this, &AFELBasketballPlayerController::OnIAJump);
		}
		if (IA_ShootTap)
		{
			EIC->BindAction(IA_ShootTap, ETriggerEvent::Started, this, &AFELBasketballPlayerController::OnIAShootTap);
		}
		if (IA_SignatureDoubleTap)
		{
			EIC->BindAction(IA_SignatureDoubleTap, ETriggerEvent::Started, this, &AFELBasketballPlayerController::OnIASignatureDoubleTap);
		}
		if (IA_SignatureGamepadStick)
		{
			EIC->BindAction(IA_SignatureGamepadStick, ETriggerEvent::Triggered, this, &AFELBasketballPlayerController::OnIASignatureGamepadStick);
			EIC->BindAction(IA_SignatureGamepadStick, ETriggerEvent::Ongoing, this, &AFELBasketballPlayerController::OnIASignatureGamepadStick);
		}
	}
#endif

	InputModeHandshake();

#if !UE_BUILD_SHIPPING
	if (InputComponent)
	{
		InputComponent->BindAction(
			"FELHotReloadReadiness",
			IE_Pressed,
			this,
			&AFELBasketballPlayerController::InputHotReloadReadiness);
	}
#endif
}

void AFELBasketballPlayerController::InputModeHandshake()
{
#if FEL_TOUCH_DRIVE
	// iOS + Android: identical touch pipeline via `ProcessTouchDrive` + Enhanced Input IMC (see FEL_TOUCH_DRIVE).
	return;
#else
	// Mac / PS5 / PC / Android GDK (no touch IMC): legacy keys map to the same handlers as mobile `IA_*` assets.
	if (InputComponent)
	{
		InputComponent->BindKey(EKeys::Gamepad_FaceButton_Left, IE_Pressed, this, &AFELBasketballPlayerController::OnHandshakeShoot);
		InputComponent->BindKey(EKeys::SpaceBar, IE_Pressed, this, &AFELBasketballPlayerController::OnHandshakeJumpKey);
		InputComponent->BindKey(EKeys::LeftShift, IE_Pressed, this, &AFELBasketballPlayerController::OnHandshakeSprintPressed);
		InputComponent->BindKey(EKeys::LeftShift, IE_Released, this, &AFELBasketballPlayerController::OnHandshakeSprintReleased);
		InputComponent->BindAxisKey(EKeys::Gamepad_RightY, this, &AFELBasketballPlayerController::OnHandshakeRightStickY);
#if PLATFORM_ANDROID
		// GDK: explicit Cross (A) jump parity when not using virtual touch layer.
		InputComponent->BindKey(EKeys::Gamepad_FaceButton_Bottom, IE_Pressed, this, &AFELBasketballPlayerController::OnHandshakeJumpKey);
#endif
#if PIXEL_STREAMING_ENABLED
		// Web / Pixel Streaming: wheel as swipe proxy → same signature path as `IA_SignatureVerticalSwipe`.
		// For full parity, add Pixel Streaming plugin `PixelStreamingInput` on this PC / BP subclass and map to the same IA in IMC.
		InputComponent->BindKey(EKeys::MouseWheelUp, IE_Pressed, this, &AFELBasketballPlayerController::OnPixelStreamingSignatureSwipe);
#endif
	}
#endif
}

void AFELBasketballPlayerController::OnHandshakeShoot()
{
	FInputActionValue Dummy;
	OnIAShootTap(Dummy);
}

void AFELBasketballPlayerController::OnHandshakeJumpKey()
{
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		Ch->FELHandshakeJump();
	}
}

void AFELBasketballPlayerController::OnHandshakeSprintPressed()
{
	HandshakeKeyboardSprint01 = 1.f;
}

void AFELBasketballPlayerController::OnHandshakeSprintReleased()
{
	HandshakeKeyboardSprint01 = 0.f;
}

void AFELBasketballPlayerController::OnHandshakeRightStickY(const float Value)
{
	const float Y = Value;
	const float Prev = HandshakeLastRightStickY;
	HandshakeLastRightStickY = Y;
	if (SignatureGestureDebounce > 0.f)
	{
		return;
	}
	// Edge into "stick up" (UE default: up = negative Y) — same threshold as `OnIASignatureGamepadStick`.
	const bool bEntered = Prev > -0.55f && Y <= -0.55f;
	if (!bEntered)
	{
		return;
	}
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		Ch->ExecuteSignatureMove();
		SignatureGestureDebounce = 0.45f;
	}
}

void AFELBasketballPlayerController::OnPixelStreamingSignatureSwipe()
{
	if (SignatureGestureDebounce > 0.f)
	{
		return;
	}
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		Ch->ExecuteSignatureMove();
		SignatureGestureDebounce = 0.45f;
	}
}

void AFELBasketballPlayerController::ApplyArenaInputForMode(const EFELArenaMode Mode)
{
	CachedAppliedArenaMode = Mode;
	if (ULocalPlayer* LP = GetLocalPlayer())
	{
		if (UEnhancedInputLocalPlayerSubsystem* Subsys = LP->GetSubsystem<UEnhancedInputLocalPlayerSubsystem>())
		{
			// Optional: per-mode IMC swap from UFELArenaModeData — `MobileTouchMappingContext` is registered in BeginPlay on mobile.
			(void)Subsys;
		}
	}
}

bool AFELBasketballPlayerController::TryHandleBaseballJumpAsSwing()
{
	if (CachedAppliedArenaMode != EFELArenaMode::Baseball)
	{
		return false;
	}
	UWorld* const W = GetWorld();
	if (!W)
	{
		return false;
	}
	AFELBasketballGameMode* const GM = W->GetAuthGameMode<AFELBasketballGameMode>();
	if (!GM || GM->CurrentMode != EFELArenaMode::Baseball || GM->MatchPhase != EFELMatchPhase::InProgress)
	{
		return false;
	}
	FEL_RequestBaseballSwing();
	return true;
}

void AFELBasketballPlayerController::FEL_RequestBaseballSwing()
{
	if (CachedAppliedArenaMode != EFELArenaMode::Baseball)
	{
		return;
	}
	if (!IsLocalPlayerController())
	{
		return;
	}
	if (HasAuthority())
	{
		ExecBaseballSwingOnServer();
	}
	else
	{
		ServerFELBaseballSwing();
	}
}

void AFELBasketballPlayerController::ExecBaseballSwingOnServer()
{
	UWorld* const W = GetWorld();
	UGameInstance* const GI = GetGameInstance();
	if (!W || !GI)
	{
		return;
	}
	UFELBaseballBattingSubsystem* const Sub = GI->GetSubsystem<UFELBaseballBattingSubsystem>();
	if (!Sub)
	{
		return;
	}
	AFELBasketballGameMode* const GM = W->GetAuthGameMode<AFELBasketballGameMode>();
	AFELBasketballGameState* const GS = W->GetGameState<AFELBasketballGameState>();
	if (!GM || !GS)
	{
		return;
	}
	Sub->HandleSwingInput(GM, GS, this);
}

void AFELBasketballPlayerController::ServerFELBaseballSwing_Implementation()
{
	ExecBaseballSwingOnServer();
}

void AFELBasketballPlayerController::SwitchInputMode()
{
#if PLATFORM_IOS || PLATFORM_ANDROID
	bGamepadMobileSignatureOverride = PlayerInput && PlayerInput->GetJoystickCount() > 0;
#else
	bGamepadMobileSignatureOverride = false;
#endif
}

void AFELBasketballPlayerController::InputHotReloadReadiness()
{
#if UE_BUILD_SHIPPING
	return;
#else
	UGameInstance* const GI = GetGameInstance();
	if (!GI)
	{
		return;
	}

	if (UFELNeuroMechanicBridgeSubsystem* const Bridge = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
	{
		FString Err;
		(void)Bridge->ReloadSnapshotFromDiskAndApply(Err);
	}
#endif
}

FString AFELBasketballPlayerController::GenerateAthletePerformanceJSON()
{
	UFELSaveGame* Save = nullptr;
	if (UGameplayStatics::DoesSaveGameExist(UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex))
	{
		Save = Cast<UFELSaveGame>(UGameplayStatics::LoadGameFromSlot(UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex));
	}
	if (!Save)
	{
		Save = Cast<UFELSaveGame>(UGameplayStatics::CreateSaveGameObject(UFELSaveGame::StaticClass()));
	}
	if (!Save)
	{
		return TEXT("{\"error\":\"no_save\"}");
	}

	float AllTimePeakZ = 0.f;
	for (const FFELAthleteStats& Row : Save->PerformanceHistory)
	{
		AllTimePeakZ = FMath::Max(AllTimePeakZ, Row.JumpHeight);
	}

	FString GearID = TEXT("Base");
	if (AFELBasketballCharacter* const Ch = Cast<AFELBasketballCharacter>(GetPawn()))
	{
		if (Ch->GetEquippedSignatureTrait() == EFELSignatureTrait::Bonds_Apex_Ignition)
		{
			GearID = TEXT("Bonds_Apex_Ignition");
		}
	}
	else if (Save->UnlockedSovereignSkins.Contains(TEXT("Bonds_Apex_Ignition")))
	{
		GearID = TEXT("Bonds_Apex_Ignition");
	}

	const EFELFatigueState Trend = UFELSaveGame::GetJumpPerformanceTrend(Save);

	TSharedPtr<FJsonObject> Root = MakeShared<FJsonObject>();
	Root->SetStringField(TEXT("athleteName"), TEXT("Elijah Bonds"));
	Root->SetStringField(TEXT("gearId"), GearID);
	Root->SetNumberField(TEXT("allTimePeakZ"), static_cast<double>(AllTimePeakZ));
	Root->SetStringField(TEXT("fatigueState"), FEL_FatigueStateToJsonString(Trend));

	FString Out;
	const TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&Out);
	if (FJsonSerializer::Serialize(Root.ToSharedRef(), Writer))
	{
		return Out;
	}
	return TEXT("{\"error\":\"json_serialize_failed\"}");
}
