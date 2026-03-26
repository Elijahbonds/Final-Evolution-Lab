// Copyright (c) Final Evolution Lab.
// Core curriculum + interest paths + timed parallel-path duel (Coursebox-style prompt → path id).

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELBrainBrawlAcademyTypes.h"
#include "UFELBrainBrawlAcademySubsystem.generated.h"

USTRUCT()
struct FFELBrainBrawlPathDef
{
	GENERATED_BODY()

	UPROPERTY()
	FString Id;

	UPROPERTY()
	FString Title;

	UPROPERTY()
	TArray<FString> InterestKeywords;

	UPROPERTY()
	float Difficulty01 = 0.5f;
};

USTRUCT()
struct FFELBrainBrawlDomainProgress
{
	GENERATED_BODY()

	UPROPERTY()
	EFELBrainBrawlCurriculumDomain Domain = EFELBrainBrawlCurriculumDomain::Analyze;

	UPROPERTY()
	int32 Attempts = 0;

	UPROPERTY()
	int32 Correct = 0;
};

/**
 * Loads `Content/FEL/Config/BrainBrawlCurriculum.json`, persists domain stats under Saved/FEL/,
 * resolves a guided path from a free-text interest prompt (keyword heuristic; swap for LLM later),
 * and runs a friend-on-their-path vs you-on-yours timer duel (simulated opponent pace).
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELBrainBrawlAcademySubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;

	/** Round clock + banks; call before opening UFELQuizWidget Brain Brawl UI. */
	void BeginAcademyDuel(float RoundSeconds, const FString& InterestPrompt, const FString& OpponentPathIdOrEmpty);

	void TickDuel(float DeltaSeconds);

	bool IsDuelActive() const { return bDuelActive; }

	float GetRemainingDuelSeconds() const { return RemainingDuelSeconds; }

	int32 GetLocalCorrectCount() const { return LocalCorrectCount; }

	int32 GetOpponentCorrectCount() const { return OpponentCorrectCount; }

	int32 GetLocalQuestionsAnswered() const { return LocalQuestionsAnswered; }

	FString GetLocalPathTitle() const { return LocalPathTitle; }

	FString GetOpponentPathTitle() const { return OpponentPathTitle; }

	FString GetLocalPathId() const { return LocalPathId; }

	FString GetOpponentPathId() const { return OpponentPathId; }

	int32 GetConfiguredRoundSeconds() const { return ConfiguredRoundSeconds; }

	/** Copy for the quiz widget (already merged core + local interest path). */
	void CopyLocalQuestionBank(TArray<FFELNeuroQuizItem>& OutBank) const { OutBank = ActiveLocalQuestionBank; }

	void RecordLocalAnswer(const FFELNeuroQuizItem& Item, bool bCorrect);

	/** Persist domain stats + last paths; idempotent if duel already finalized. */
	void FinalizeDuelAndPersistProgress();

	/** Blueprint / UI: same keyword resolver used by BeginAcademyDuel for the local player. */
	UFUNCTION(BlueprintCallable, Category = "FEL|BrainBrawl|Academy")
	FString ResolveGuidedPathIdFromInterestPrompt(const FString& InterestPrompt) const;

protected:
	void LoadCurriculumFromDisk();
	void LoadEmbeddedFallbackCurriculum();
	void LoadProgressFromDisk();
	void SaveProgressToDisk() const;

	int32 FindPathIndexById(const FString& Id) const;
	FString PickOpponentPathId(const FString& AvoidId) const;
	void RebuildActiveQuestionBank();
	int32 ScorePromptAgainstPath(const FString& PromptLower, const FFELBrainBrawlPathDef& Path) const;

	UPROPERTY()
	TArray<FFELBrainBrawlPathDef> PathCatalog;

	UPROPERTY()
	TArray<FFELNeuroQuizItem> MasterQuestionBank;

	UPROPERTY()
	TArray<FFELNeuroQuizItem> ActiveLocalQuestionBank;

	UPROPERTY()
	TArray<FFELBrainBrawlDomainProgress> DomainProgress;

	FString LocalPathId;
	FString OpponentPathId;
	FString LocalPathTitle;
	FString OpponentPathTitle;
	float OpponentDifficulty01 = 0.5f;

	float RemainingDuelSeconds = 0.f;
	int32 ConfiguredRoundSeconds = 120;
	bool bDuelActive = false;
	bool bDuelFinalized = false;

	int32 LocalCorrectCount = 0;
	int32 LocalQuestionsAnswered = 0;
	int32 OpponentCorrectCount = 0;
	int32 OpponentQuestionsResolved = 0;

	float OpponentQuestionAccumulator = 0.f;
	float OpponentNextQuestionInterval = 10.f;
};
