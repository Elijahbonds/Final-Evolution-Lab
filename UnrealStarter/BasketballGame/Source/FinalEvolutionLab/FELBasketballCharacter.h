// Copyright (c) Final Evolution Lab. Copy into your game module (e.g. Source/FinalEvolutionLab/).

#pragma once

#include "CoreMinimal.h"
#include "UObject/UnrealType.h"
#include "FELArenaRulesTypes.h"
#include "FELJumpTimingTypes.h"
#include "FELReadinessTypes.h"
#include "IFELBiometricReceiver.h"
#include "Camera/CameraShakeBase.h"
#include "GameFramework/Character.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "FELBasketballCharacter.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FFELOnPerfectDunk);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FFELOnPerfectStrike);

class USpringArmComponent;
class UCameraComponent;
class UPointLightComponent;
class UNiagaraSystem;
class USoundBase;
class USoundAttenuation;
class USoundMix;
class UMaterialInterface;
class UTexture2D;
class UMotionWarpingComponent;
class UFELLandingIKComponent;
class UFELCinematicCameraComponent;

struct FFELArenaRules;

/**
 * Third-person character using the Elijah Bonds skeletal mesh (default path in .cpp).
 */
class UFELInputComponent;

UCLASS()
class FINALEVOLUTIONLAB_API AFELBasketballCharacter : public ACharacter, public IFELBiometricReceiver
{
	GENERATED_BODY()

	friend class UFELInputComponent;

public:
	AFELBasketballCharacter(const FObjectInitializer& ObjectInitializer);

	virtual void ApplyBiometricContext_Implementation(const FFELBiometricContext& Context) override;

	/** Jump / sprint tuning from scan metrics (see VISION_ALIGNMENT.md). */
	void ApplyReadiness(const FFELReadinessSnapshot& Snap);

	/** After ApplyReadiness: optional scales from ArenaSettings.json. Arena Dunk vs Lab Dunk: leakage is always applied inside ApplyReadiness (GAMEPLAY_STATUS parity). */
	void ApplyArenaPhysicsLayer(const FFELArenaRules& Rules);

	/**
	 * Dunk contest hang-time + neuro-drive VFX: call after ApplyReadiness + ApplyArenaPhysicsLayer from the neuro bridge.
	 * Uses Rules.bIsDunkContest + snapshot HangTimeScale / NeuralDrive.
	 */
	void ApplyNeuroArenaGameplay(const FFELReadinessSnapshot& Snap, const FFELArenaRules& Rules);

	/** First Bio-Sync: twin reveal orbit + Neuro-Flow ignition (driven by readiness `bPlayTwinBirthCinematicOnce`). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Onboarding")
	void PlayTwinBirthIntro(float DurationSeconds = 3.f);

	/** Last Bonds Bounce timing evaluation (Blueprint → "Leaky" anim layer when Early/Late). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Neuro")
	EFELJumpTimingBand LastJumpTimingBand = EFELJumpTimingBand::None;

	/** 0.45–1.0 realized fraction from input timing alone (after snapshot pipeline). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Neuro")
	float LastJumpTimingLeakFactor = 1.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Neuro")
	bool bNeuroFlowActive = false;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	USpringArmComponent* CameraBoom;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	UCameraComponent* FollowCamera;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Neuro")
	UPointLightComponent* NeuroDriveFootGlow;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Neuro")
	UPointLightComponent* NeuroDriveHandGlow;

	/** Steam / energy leak at feet when TimingLeak < 0.7 (assign Niagara system in editor). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Feedback")
	TObjectPtr<UNiagaraSystem> BondsBounceLeakVFX;

	/** "Sonic boom" at contact / hands when Neuro-Flow triggers (optional; assign in editor). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Feedback")
	TObjectPtr<UNiagaraSystem> NeuroFlowSonicBoomVFX;

	/** Optional: apex "Sonic Flare" for `Bonds_Apex_Ignition`; falls back to `NeuroFlowSonicBoomVFX` if unset. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Feedback|Signature")
	TObjectPtr<UNiagaraSystem> SignatureSonicFlareVFX;

	/** Heavy landing: scaled by `CachedAnkleHeat01` + impact speed (optional shake class). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Feedback")
	TSubclassOf<UCameraShakeBase> HeavyLandingCameraShake;

	/** Luma Venice 0.5x global dilation: broadcast camera punch (optional; FOV still kicks if unset). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Feedback|Signature")
	TSubclassOf<UCameraShakeBase> SignatureHeroBroadcastCameraShake;

	/** Apex / Perfect-band cinematic framing (spring arm + FOV; driven from Tick). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Neuro")
	TObjectPtr<UFELCinematicCameraComponent> CinematicCamera;

	/** Sonic / ring sting when entering Neuro-Flow (optional). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Audio")
	TObjectPtr<USoundBase> NeuroFlowSonicCue;

	/** Stadium "boom" when Bonds Bounce timing is Perfect (3D spatial; assign attenuation for arena falloff). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Audio")
	TObjectPtr<USoundBase> PerfectDunkStadiumBoomCue;

	UPROPERTY(EditDefaultsOnly, Category = "FEL|Audio")
	TObjectPtr<USoundAttenuation> PerfectDunkSpatialAttenuation;

	/** Sound mix that ducks other classes while Neuro-Flow sting plays (optional). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Audio")
	TObjectPtr<USoundMix> NeuroFlowDuckMix;

	/**
	 * Sovereign / MyTeam gear albedo — editor hook applies ASTC + 1024 cap for iOS/Android packaging (Fortnite-style tiering).
	 * Assign shop jersey/shoe source textures here so PostEditChangeProperty can stamp mobile-friendly settings.
	 */
	UPROPERTY(EditAnywhere, Category = "FEL|Gear|Sovereign")
	TArray<TObjectPtr<UTexture2D>> SovereignGearTextures;

	/** Post-process blendable: edge / electric aura when PRQ is Primed (>85). Use stencil against CustomDepth on mesh. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Neuro|Primed")
	TObjectPtr<UMaterialInterface> PrimedNeuroPostProcessMaterial;

	/** Skeletal mesh material slot index for jersey MID — drives `FEL_JerseyNeuroPulse` / `FEL_JerseyEmissiveCyan` (match MI parameters). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Neuro|Jersey", meta = (ClampMin = "0"))
	int32 NeuroFlowJerseyMaterialIndex = 0;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Neuro")
	FFELOnPerfectDunk OnPerfectDunk;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Neuro")
	FFELOnPerfectStrike OnPerfectStrike;

	/** Dojo Neural Tempest / lab modes: neuro pipeline walk cap before lateral-cut leakage (uu/s). */
	UFUNCTION(BlueprintPure, Category = "FEL|Neuro")
	float FELGetNeuroBaselineWalkSpeed() const { return CachedNeuroMaxWalkSpeed; }

	/** Dojo Neural Tempest: call when a burst commits at peak tension — iOS haptics + Niagara at contact. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Feedback")
	void BroadcastPerfectStrikeImpact();

	/**
	 * Creator Card signature move (`CachedSignatureTrait` from `signature_trait_id`).
	 * Mobile: `AFELBasketballPlayerController` maps tap/hold/double-tap (Enhanced Input parity) to this.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Signature")
	void ExecuteSignatureMove();

	/** Blueprint / legacy — forwards to `ExecuteSignatureMove`. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Signature")
	void TriggerSignatureMove();

	/** Gold Master: `AFELBasketballPlayerController::InputModeHandshake` (Mac Space) — same as default `Jump` action → `FEL_OnJumpPressed`. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Input")
	void FELHandshakeJump();

	/** IA_ShootTap during ascent: snap motion-warp toward rim using save-game peak Z as reference (Neuro-Mechanic integrity). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Input")
	void TryShootTapAscentRimSnap();

	UFUNCTION(BlueprintPure, Category = "FEL|Signature")
	EFELSignatureTrait GetEquippedSignatureTrait() const { return CachedSignatureTrait; }

	UFUNCTION(BlueprintPure, Category = "FEL|Gear")
	float GetCachedGearJumpMult() const { return CachedGearJumpMult; }

	/** Peak upward Z velocity (uu/s) sampled during the last jump — AI Coach / System Scan (stored in `FFELAthleteStats::JumpHeight` field at save time). */
	UFUNCTION(BlueprintPure, Category = "FEL|Coach")
	float GetLastJumpPeakZVelocityForStats() const { return LastJumpPeakZVelocityForStats; }

	/** Apply `UFELSaveGame` after `LoadGameFromSlot` (Bonds_Apex_Ignition unlock + cached gear mult). */
	void ApplyPersistedGearState(class UFELSaveGame* Save);

	/** True while signature execution should block buffered shoot (IMC tap / deferred 0.16s shoot). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Signature")
	bool IsSignatureMoveWindowActive() const;

	bool CanJump() const;

	virtual void BeginPlay() override;

	/**
	 * Mobile: virtual stick + optional sprint/gather from `AFELBasketballPlayerController` touch bridge.
	 * MoveForward/MoveRight are -1..1; TurnDelta is additive yaw; Sprint01/Gather01 are smoothed internally.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Touch")
	void ApplyTouchDriveInput(float MoveForward, float MoveRight, float TurnDelta, float Sprint01, float Gather01, float DeltaSeconds);

	/** Motion Warping — align mocap jumps to rim / goal targets (see `FELMotionWarpingLibrary`). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Animation")
	TObjectPtr<UMotionWarpingComponent> MotionWarping;

	/** Landing wobble from ankle/knee kinetic heat (Lab Dunk + Gymnastics). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Animation")
	TObjectPtr<UFELLandingIKComponent> LandingIK;

	/** Data-driven mocap + jump clips (mirrors ArenaSettings / `FFELSportNeuroConstants`). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Animation")
	FFELSportNeuroConstants CachedSportNeuro;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Neuro")
	float CachedPRQScore = 75.f;

	/** 0..1 horizontal speed vs neuro max walk (Athlete Hub — engine truth, not Swift). */
	UFUNCTION(BlueprintPure, Category = "FEL|AthleteHub")
	float GetSprintGauge01() const;

	/** 0..1 neural drive from readiness pipeline (Gather analog). */
	UFUNCTION(BlueprintPure, Category = "FEL|AthleteHub")
	float GetGatherNeuralDrive01() const;

	/** 0..1 active Neuro-Flow camera post blend. */
	UFUNCTION(BlueprintPure, Category = "FEL|AthleteHub")
	float GetNeuroFlowVisualBlend01() const;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Scan")
	float CachedAnkleHeat01 = 0.2f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Scan")
	float CachedKneeHeat01 = 0.2f;

protected:
#if WITH_EDITOR
	virtual void PostEditChangeProperty(FPropertyChangedEvent& PropertyChangedEvent) override;
	void ApplySovereignTexturePlatformDefaults();
#endif

	virtual void Tick(float DeltaSeconds) override;
	virtual void Jump() override;
	virtual void Landed(const FHitResult& Hit) override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
	virtual void OnMovementModeChanged(EMovementMode PrevMovementMode, uint8 PreviousCustomMode) override;
	virtual void SetupPlayerInputComponent(class UInputComponent* PlayerInputComponent) override;

	void MoveForward(float Value);
	void MoveRight(float Value);
	void Turn(float Value);
	void LookUp(float Value);

	void FEL_OnJumpPressed();
	void FEL_OnJumpReleased();

	void ApplyBondsBounceHitStop();
	void ClearBondsBounceHitStop();

	void UpdateNeuroDriveVisuals(float NeuralDrivePercent);
	void TickApproachRun(float DeltaSeconds);
	void ApplyLateralWalkFromNeuro();
	float ComputeLateralStrain01() const;
	void ApplyMidAirNeuralCorrection(float DeltaSeconds);
	void UpdateNeuroFlowVisuals(float DeltaSeconds);
	void UpdateHeroBroadcastCameraFeedback();
	void TriggerNeuroFlow();
	void ApplyJumpTakeoffAnimWarp(EFELJumpTimingBand Band);
	void ApplyNeuroLayerBlendToAnimInstance();
	void SpawnBondsBounceLeakVFX(float TimingLeak);
	void PlayNeuroFlowAudioCue();
	void PopNeuroFlowDuckMix();
	void UpdatePrimedPostProcess(float DeltaSeconds);
	void UpdateNeuroFlowCharacterMaterials(float DeltaSeconds);
	void EnsureNeuroFlowMaterialDynamics();
	void SpawnPerfectDunkRimNiagara();
	void TickSignatureTrait(float DeltaSeconds);
	void SpawnSignatureSonicFlareAtApex();
	/** Nintendo Switch: Joy-Con HD Rumble — Bonds Apex (≥40") primary snap + Sonic Flare bloom-matched secondary pulse. */
	void TriggerSwitchHaptics(float BloomIntensity01, bool bBondsApexHighJump);
	void TryNeuroFlowTeleportTowardRim();

	/** Phase 2: multiply JumpZVelocity + MaxWalkSpeed from PRQ (after neuro stack; FELPRQInfluence). */
	void ApplyPRQNeuralDriveToMovement(float PRQ0to100);

	/** RC 1.0 Luma Venice: restore global dilation + broadcast bloom after short hang window. */
	void OnSonicFlareBroadcastWindowEnd();

	UFUNCTION()
	void OnPerfectDunkWarpHapticTimerFired();
	void PlayPerfectDunkSpatialBoom();
	FVector GetNearestHoopLocationForVFX() const;

	FTimerHandle JumpWarpResetTimerHandle;
	FTimerHandle MotionWarpClearTimerHandle;
	FTimerHandle NeuroFlowAudioMixTimerHandle;
	FTimerHandle HitStopResetTimerHandle;
	FTimerHandle PerfectDunkWarpHapticTimerHandle;
	FTimerHandle SonicFlareBroadcastTimerHandle;

	/** Luma_Venice_Shop: Bonds Apex TV moment — global slow-mo + bloom (see package_gold_master RC constants). */
	bool bSonicFlareBroadcastHangActive = false;
	bool bSonicFlareBroadcastBloomActive = false;
	bool bWasSonicFlareBroadcastHangActive = false;

#if defined(PLATFORM_PS5) && PLATFORM_PS5
	/** PS5 Pro: mirror-finish RT cvars during Sonic Flare window (Venice shop floor); restored when the 0.2s hang ends. */
	void PushVeniceMirrorFinishRtIfPS5Pro();
	void PopVeniceMirrorFinishRt();
	bool bVeniceMirrorFinishRtPushed = false;
	bool bHasVeniceMirrorSavedMaxRoughness = false;
	bool bHasVeniceMirrorSavedRTGI = false;
	float VeniceMirrorSavedMaxRoughness = 0.f;
	int32 VeniceMirrorSavedRTGI = 0;
#endif

	/** Kinetic chain: Sprint→Gather (ExecuteSignatureMove) transfers horizontal speed into next jump (see AUDIT_BIOMECHANICAL_ECOSYSTEM). */
	float PendingKineticGatherJumpBoost = 0.f;
	/** Snapshot before Bonds Apex jump for +25% AirControl (Fortnite-style mid-air strafe parity). */
	float CachedAirControlBeforeBondsApexJump = 0.35f;
	float DefaultFollowCameraFOV = 90.f;
	float AscentRimSnapCooldownRemaining = 0.f;
	bool bBondsApexSeekingApexPrevFrame = false;

	/** Grace period after leaving ground without a jump (ledge walk-off). */
	float CoyoteTimeRemaining = 0.f;
	static constexpr float CoyoteTimeSeconds = 0.1f;
	/** Set true at jump start so Walking→Falling from takeoff does not grant coyote. */
	bool bLeftGroundByJump = false;

	/** Snapshot + arena pipeline jump Z before per-jump timing multiplier (cm/s). */
	float CachedJumpZAfterNeuroPipeline = 420.f;
	/** Max walk speed after neuro + arena physics, before lateral-cut leakage (uu/s). */
	float CachedNeuroMaxWalkSpeed = 600.f;
	/** Seconds spent above approach speed while grounded (gather clock for Bonds Bounce). */
	float ApproachRunSeconds = 0.f;
	float CachedNeuralDrive = 0.f;
	int32 ConsecutivePerfectJumps = 0;
	float NeuroFlowRemainSec = 0.f;
	float NeuroFlowVisualBlend = 0.f;
	bool bNeuroFlowDuckMixPushed = false;
	float PrimedPostProcessBlend = 0.f;

	static constexpr float ApproachSpeedThresholdUU = 280.f;

	bool bIsDunkContestContext = false;
	/** H2H / 3v3 Street Jam (trick meter on gathers) — sim timing, not dunk hang-time slice. */
	bool bIsStreetJamContext = false;
	float NeuroHangTimeScaleCached = 1.f;
	float DefaultMovementGravityScale = 1.f;
	/** Vertical velocity band (uu/s) for apex hang-time gravity easing. */
	float DunkApexVelocityBand = 220.f;
	bool bNeuroDriveGlowActive = false;

	float CachedKineticLeakageMult = 1.f;
	FString CachedActiveArenaMode;

	/** From `readiness_snapshot.json` MyTeam gear (1.0–1.06). */
	float CachedGearMotionWarpMult = 1.f;
	float CachedGearJumpMult = 1.f;
	float CachedNeuroFlowIntensityScale = 1.f;

	/** Stood Creator Card — layered after gear jump mult. */
	float CachedStoodCardJumpScale = 1.f;
	float CachedStoodCardNeuralAlpha = 1.f;
	FString CachedStoodCardTier;
	FLinearColor CachedNeuroFlowAuraColor = FLinearColor(0.15f, 1.f, 0.95f);

	EFELSignatureTrait CachedSignatureTrait = EFELSignatureTrait::None;
	float SignatureMoveCooldownRemaining = 0.f;
	float SignatureAuraBlend01 = 0.f;
	bool bPendingSignatureApexIgnition = false;
	bool bBondsApexIgnitionSeekApex = false;
	bool bBondsApexWasRising = false;
	double SignatureGhostStrikeUntilTime = 0.0;

	/** True from jump takeoff until landing — tracks max upward Z velocity for PerformanceHistory. */
	bool bTrackJumpPeakForStats = false;
	float LastJumpPeakZVelocityForStats = 0.f;

	/** iOS touch: sprint / gather modifiers (0..1), smoothed in ApplyTouchDriveInput. */
	float TouchSprintBlend01 = 0.f;
	float TouchGatherBlend01 = 0.f;

	UPROPERTY(Transient)
	TArray<TObjectPtr<UMaterialInstanceDynamic>> NeuroFlowMaterialDynamics;

	bool bNeuroFlowMIDsEnsured = false;
};
