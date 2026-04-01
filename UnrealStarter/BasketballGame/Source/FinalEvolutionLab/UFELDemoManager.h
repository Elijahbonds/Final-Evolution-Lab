// Copyright (c) Final Evolution Lab.
// Ghost demonstration: spawn avatar, camera blend, Perfect Form HUD overlay.

#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "FELArenaHUDTypes.h"
#include "FELExerciseDemonstrator.h"
#include "FELExerciseDemoTypes.h"
#include "UFELDemoManager.generated.h"

class AFELBasketballGameMode;
class UUserWidget;
class UAnimMontage;

UCLASS(ClassGroup = (Custom), meta = (BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELDemoManager : public UActorComponent
{
	GENERATED_BODY()

public:
	UFELDemoManager();

	UPROPERTY(EditDefaultsOnly, Category = "FEL|Demonstration")
	TSubclassOf<AFELExerciseDemonstrator> DemonstratorClass;

	UPROPERTY(EditDefaultsOnly, Category = "FEL|Demonstration", meta = (ClampMin = "0", UIMin = "0"))
	float ExerciseDemoCameraBlendInSeconds = 0.85f;

	UPROPERTY(EditDefaultsOnly, Category = "FEL|Demonstration", meta = (ClampMin = "0", UIMin = "0"))
	float ExerciseDemoCameraBlendOutSeconds = 0.65f;

	UPROPERTY(EditDefaultsOnly, Category = "FEL|Demonstration")
	float DemonstratorOffsetFromPlayerCM = 280.f;

	/** When demonstrations may start: pre-match only (default), Practice open play, or any phase except post-match. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Demonstration")
	EFELExerciseDemoGameplayPolicy ExerciseDemoPhasePolicy = EFELExerciseDemoGameplayPolicy::PreMatchOnly;

	/** After DeepMotion montage completes, blend camera back to pawn and destroy demonstrator (onboarding flow). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Demonstration")
	bool bEndDemoWhenDemonstrationMontageCompletes = true;

	/** Optional WBP; defaults to native UFELPerfectFormChecklistWidget. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Demonstration")
	TSubclassOf<UUserWidget> PerfectFormChecklistWidgetClass;

	/**
	 * Optional montage from `UFELExerciseDemoPipelineSubsystem` / `UFELAcademyMocapCatalogSubsystem` (default: idle AnimBP only).
	 * Negative PRQOverride0to100 uses the game mode snapshot PRQ.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Demonstration", meta = (AdvancedDisplay = "PRQOverride0to100"))
	void TriggerExerciseDemo(UAnimMontage* OptionalDemonstrationMontage = nullptr, float PRQOverride0to100 = -1.f);

	UFUNCTION(BlueprintCallable, Category = "FEL|Demonstration")
	void EndExerciseDemoIfActive();

protected:
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	UPROPERTY()
	TWeakObjectPtr<AFELExerciseDemonstrator> ActiveDemonstrator;

	UPROPERTY()
	TWeakObjectPtr<UUserWidget> ActivePerfectFormWidget;

	void ShowPerfectFormOverlay(const FFELArenaHUDConfig& Hud);
	void HidePerfectFormOverlay();

	AFELBasketballGameMode* GetFELGameMode() const;

	bool CanExerciseDemoRunThisPhase(const AFELBasketballGameMode* GM) const;

	UFUNCTION()
	void HandleDemonstrationMontageEnded(bool bInterrupted);
};
