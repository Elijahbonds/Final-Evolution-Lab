// Copyright (c) Final Evolution Lab.
// Neuro-Knowledge (neuroscience / biomechanics) quiz — Brain Brawl UI hook.

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELQuizWidget.generated.h"

class UButton;
class UTextBlock;
class UVerticalBox;
class UGameInstance;
class UFELNeuroMechanicBridgeSubsystem;

/** One multiple-choice neuro question (static bank in .cpp). */
USTRUCT()
struct FFELNeuroQuizItem
{
	GENERATED_BODY()

	UPROPERTY()
	FString Question;

	UPROPERTY()
	TArray<FString> Answers;

	UPROPERTY()
	int32 CorrectIndex = 0;
};

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

	/** Close UI and restore game input (call after last question or from BP). */
	UFUNCTION(BlueprintCallable, Category = "FEL|BrainBrawl")
	void FinishQuiz();

protected:
	virtual void NativeConstruct() override;

private:
	void BuildProgrammaticLayoutIfNeeded();
	void PresentCurrentQuestion();
	void OnAnswerButtonClicked(int32 AnswerIndex);
	void ApplyCorrectAnswerBoost() const;

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

	/** Optional WBP bindings — if all null, C++ builds fallback UI. */
	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UTextBlock> QuestionTextBlock = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	TObjectPtr<UVerticalBox> AnswerVerticalBox = nullptr;

	UPROPERTY(Transient)
	TArray<TObjectPtr<UButton>> SpawnedAnswerButtons;
};
