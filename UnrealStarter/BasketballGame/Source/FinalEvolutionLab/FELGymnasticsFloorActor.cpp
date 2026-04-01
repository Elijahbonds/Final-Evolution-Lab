// Copyright (c) Final Evolution Lab.

#include "FELGymnasticsFloorActor.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FELTwelvePillarArenaGameplay.h"
#include "FinalEvolutionLab.h"
#include "Math/UnrealMathUtility.h"

AFELGymnasticsFloorActor::AFELGymnasticsFloorActor()
{
	PrimaryActorTick.bCanEverTick = true;
}

void AFELGymnasticsFloorActor::BeginPlay() { Super::BeginPlay(); }

void AFELGymnasticsFloorActor::InitRoutine(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState)
{
	CachedGameMode = GameMode;
	CachedGameState = GameState;
	ScoreCard = FFELGymnasticsScoreCard();
	CurrentPhase = EFELGymnasticsPhase::Preparing;
	PhaseTimer = 0.f;
	RoutineTimer = 0.f;
}

float AFELGymnasticsFloorActor::GetPRQ() const
{
	return CachedGameMode.IsValid() ? CachedGameMode->GetNeuroPRQScoreFloat() : 75.f;
}

void AFELGymnasticsFloorActor::TransitionToPhase(EFELGymnasticsPhase NewPhase)
{
	CurrentPhase = NewPhase;
	PhaseTimer = 0.f;
}

void AFELGymnasticsFloorActor::HandleTumblingInput(int32 SkillLevel)
{
	if (CurrentPhase != EFELGymnasticsPhase::Tumbling && CurrentPhase != EFELGymnasticsPhase::Preparing)
		return;

	TransitionToPhase(EFELGymnasticsPhase::Tumbling);
	const float PRQ01 = FMath::Clamp(GetPRQ() * 0.01f, 0.f, 1.f);
	const float StaminaDrain = FELTwelvePillarArenaGameplay::GymnasticsStaminaDrainScale(GetPRQ());

	ScoreCard.Stamina01 = FMath::Clamp(ScoreCard.Stamina01 - 0.15f * StaminaDrain, 0.f, 1.f);

	const float Difficulty = FMath::Clamp(SkillLevel * 0.2f, 0.1f, 1.f);
	const float ExecutionQuality = FMath::Lerp(0.6f, 1.f, PRQ01) * ScoreCard.Stamina01;

	ScoreCard.DifficultyScore += Difficulty * 2.f;
	ScoreCard.FormQuality01 = ExecutionQuality;

	if (ExecutionQuality < 0.7f)
		ApplyDeduction(0.3f, TEXT("Form break on tumbling"));

	ScoreCard.PassesCompleted++;
	if (ScoreCard.PassesCompleted >= TotalPasses)
		TransitionToPhase(EFELGymnasticsPhase::Dismount);
}

void AFELGymnasticsFloorActor::HandleLeapInput()
{
	if (CurrentPhase == EFELGymnasticsPhase::Dance || CurrentPhase == EFELGymnasticsPhase::Preparing)
	{
		TransitionToPhase(EFELGymnasticsPhase::Leap);
		const float PRQ01 = GetPRQ() * 0.01f;
		ScoreCard.ArtistryScore += FMath::Lerp(1.f, 2.5f, PRQ01);
		ScoreCard.DifficultyScore += 0.4f;
	}
}

void AFELGymnasticsFloorActor::HandleBalanceInput()
{
	TransitionToPhase(EFELGymnasticsPhase::Balance);
	const float PRQ01 = GetPRQ() * 0.01f;
	const float HoldQuality = FMath::Lerp(0.5f, 1.f, PRQ01) * ScoreCard.Stamina01;
	ScoreCard.ArtistryScore += HoldQuality * 1.5f;
	if (HoldQuality < 0.6f)
		ApplyDeduction(0.1f, TEXT("Wobble on balance"));
}

void AFELGymnasticsFloorActor::HandleDismountInput(int32 DismountDifficulty)
{
	if (CurrentPhase != EFELGymnasticsPhase::Dismount && ScoreCard.PassesCompleted < TotalPasses)
		return;

	TransitionToPhase(EFELGymnasticsPhase::Dismount);
	const float PRQ01 = GetPRQ() * 0.01f;
	const float LandQuality = FMath::Lerp(0.5f, 1.f, PRQ01) * ScoreCard.Stamina01;

	ScoreCard.DifficultyScore += FMath::Clamp(DismountDifficulty * 0.3f, 0.1f, 1.5f);

	if (LandQuality < 0.7f)
		ApplyDeduction(0.5f, TEXT("Step on landing"));
	if (LandQuality < 0.5f)
		ApplyDeduction(0.3f, TEXT("Major form break"));

	FinalizeRoutine();
}

void AFELGymnasticsFloorActor::ApplyDeduction(float Amount, const FString& Reason)
{
	ScoreCard.ExecutionScore = FMath::Max(0.f, ScoreCard.ExecutionScore - Amount);
	ScoreCard.DeductionCount++;
}

void AFELGymnasticsFloorActor::FinalizeRoutine()
{
	TransitionToPhase(EFELGymnasticsPhase::Scored);
	const float Total = ScoreCard.DifficultyScore + ScoreCard.ExecutionScore + ScoreCard.ArtistryScore;

	if (CachedGameState.IsValid() && CachedGameState->IsScoringEnabled())
		CachedGameState->AddScore(FMath::FloorToInt(Total));
}

void AFELGymnasticsFloorActor::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	if (!CachedGameMode.IsValid() || !CachedGameState.IsValid()) return;
	if (CachedGameState->HasMatchEnded()) return;

	PhaseTimer += DeltaSeconds;
	RoutineTimer += DeltaSeconds;

	const float PRQ01 = FMath::Clamp(GetPRQ() * 0.01f, 0.f, 1.f);

	// Stamina regenerates slowly during dance/artistry phases
	if (CurrentPhase == EFELGymnasticsPhase::Dance || CurrentPhase == EFELGymnasticsPhase::Balance)
	{
		ScoreCard.Stamina01 = FMath::Clamp(ScoreCard.Stamina01 + 0.03f * DeltaSeconds, 0.f, 1.f);
	}

	// Auto-transition from preparing
	if (CurrentPhase == EFELGymnasticsPhase::Preparing && PhaseTimer > 2.f)
		TransitionToPhase(EFELGymnasticsPhase::Dance);

	// Leap auto-ends
	if (CurrentPhase == EFELGymnasticsPhase::Leap && PhaseTimer > 1.f)
		TransitionToPhase(EFELGymnasticsPhase::Dance);

	// Balance auto-ends
	if (CurrentPhase == EFELGymnasticsPhase::Balance && PhaseTimer > 2.f)
		TransitionToPhase(EFELGymnasticsPhase::Dance);

	// Time penalty
	if (RoutineTimer > 90.f && CurrentPhase != EFELGymnasticsPhase::Scored)
	{
		ApplyDeduction(1.f, TEXT("Time violation"));
		FinalizeRoutine();
	}
}

FString AFELGymnasticsFloorActor::BuildHudLine() const
{
	const float Total = ScoreCard.DifficultyScore + ScoreCard.ExecutionScore + ScoreCard.ArtistryScore;
	return FString::Printf(
		TEXT("Gymnastics · D:%.1f E:%.1f A:%.1f = %.1f · passes %d/%d · stamina %.0f%%"),
		ScoreCard.DifficultyScore, ScoreCard.ExecutionScore, ScoreCard.ArtistryScore, Total,
		ScoreCard.PassesCompleted, TotalPasses, ScoreCard.Stamina01 * 100.f);
}
