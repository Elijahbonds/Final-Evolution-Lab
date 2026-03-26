// Copyright (c) Final Evolution Lab.
// Neuro-Knowledge (neuroscience / biomechanics) quiz — Brain Brawl UI hook.

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELBrainBrawlAcademyTypes.h"
#include "UFELBrainBrawlAcademySubsystem.h"
#include "FELQuizWidget.generated.h"

class UButton;
class UTextBlock;
class UVerticalBox;
class UGameInstance;
class UFELNeuroMechanicBridgeSubsystem;

/**
 * Shown when Brain Brawl mode activates. Correct answers call the neuro bridge for a temporary PRQ boost.
 * Works with no Blueprint asset: builds a VerticalBox + buttons in NativeConstruct when designer widgets are absent.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELQuizWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	/** Wire subsystem + optional shuffle; safe to call from GameMode after CreateWidget. */
	UFUNCTION(BlueprintCallable, Category = "FEL|BrainBrawl")
	void InitializeQuiz(UGameInstance* GameInstance);

	/**
	 * Big Brain Academy–style duel: core curriculum + interest path, parallel friend path sim, round timer.
	 * Call after `UFELBrainBrawlAcademySubsystem::BeginAcademyDuel` (see AFELBasketballGameMode).
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|BrainBrawl")
	void InitializeBrainBrawlFromSubsystem(UGameInstance* GameInstance);

	/** Close UI and restore game input (call after last question or from BP). */
	UFUNCTION(BlueprintCallable, Category = "FEL|BrainBrawl")
	void FinishQuiz();

protected:
	virtual void NativeConstruct() override;
	virtual void NativeDestruct() override;

private:
	void BuildProgrammaticLayoutIfNeeded();
	void PresentCurrentQuestion();
	void OnAnswerButtonClicked(int32 AnswerIndex);
	void ApplyCorrectAnswerBoost() const;
	void BindAnswerButton(UButton* Btn, int32 AnswerIndex);
	void StartAcademyHudPump();
	void StopAcademyHudPump();
	void PumpAcademyHud();
	void RefreshAcademyHudTexts();
	void CompleteAcademyDuelAndClose();
	void SetAnswerInputLocked(bool bLocked);
	void UpdateAnswerButtonsInteractable();

	UFUNCTION()
	void OnAnswerLockoutExpired();

	UFUNCTION()
	void OnAnswerClicked0();

	UFUNCTION()
	void OnAnswerClicked1();

	UFUNCTION()
	void OnAnswerClicked2();

	UFUNCTION()
	void OnAnswerClicked3();

	UFUNCTION()
	void OnAnswerClicked4();

	UFUNCTION()
	void OnAnswerClicked5();

	UFUNCTION()
	void OnAnswerClicked6();

	UFUNCTION()
	void OnAnswerClicked7();

	UPROPERTY(Transient)
	TObjectPtr<UGameInstance> CachedGameInstance = nullptr;

	UPROPERTY(Transient)
	TArray<FFELNeuroQuizItem> QuestionBank;

	UPROPERTY(Transient)
	TArray<int32> ShuffledOrder;

	UPROPERTY(Transient)
	int32 CurrentOrdinal = 0;

	UPROPERTY(Transient)
	bool bBuiltProgrammaticFallback = false;

	UPROPERTY(Transient)
	TObjectPtr<UTextBlock> ProgrammaticDuelStatusText = nullptr;

	UPROPERTY(Transient)
	TObjectPtr<UTextBlock> ProgrammaticDuelTimerText = nullptr;

	/** Optional WBP bindings — if all null, C++ builds fallback UI. */
	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> QuestionTextBlock = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UVerticalBox> AnswerVerticalBox = nullptr;

	UPROPERTY(Transient)
	TArray<TObjectPtr<UButton>> SpawnedAnswerButtons;

	UPROPERTY(Transient)
	TObjectPtr<UFELBrainBrawlAcademySubsystem> AcademySubsystem = nullptr;

	UPROPERTY(Transient)
	bool bAcademyDuelMode = false;

	UPROPERTY(Transient)
	bool bAcademyCompletionDispatched = false;

	UPROPERTY(Transient)
	bool bAnswerInputLocked = false;

	UPROPERTY(Transient)
	FTimerHandle AcademyHudTimerHandle;

	UPROPERTY(Transient)
	FTimerHandle AnswerLockoutTimerHandle;

	UPROPERTY(Transient)
	double LastAcademyHudWorldSeconds = 0.0;
};
