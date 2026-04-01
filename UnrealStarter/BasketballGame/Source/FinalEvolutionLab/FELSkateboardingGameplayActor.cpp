// Copyright (c) Final Evolution Lab.

#include "FELSkateboardingGameplayActor.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FinalEvolutionLab.h"
#include "Math/UnrealMathUtility.h"

AFELSkateboardingGameplayActor::AFELSkateboardingGameplayActor()
{
        PrimaryActorTick.bCanEverTick = true;
}

void AFELSkateboardingGameplayActor::BeginPlay() { Super::BeginPlay(); }

void AFELSkateboardingGameplayActor::InitSkateSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState)
{
        CachedGameMode = GameMode;
        CachedGameState = GameState;
        ScoreCard = FFELSkateScoreCard();
        CurrentPhase = EFELSkatePhase::Cruising;
        PhaseTimer = 0.f;
        Balance01 = 1.f;
        Speed01 = 0.5f;
        ComboTrickCount = 0;
        ComboGraceTimer = 0.f;
}

float AFELSkateboardingGameplayActor::GetPRQ() const
{
        return CachedGameMode.IsValid() ? CachedGameMode->GetNeuroPRQScoreFloat() : 75.f;
}

float AFELSkateboardingGameplayActor::GetLeakage() const
{
        return CachedGameMode.IsValid() ? CachedGameMode->GetNeuroKineticLeakageMultiplierFloat() : 1.f;
}

void AFELSkateboardingGameplayActor::TransitionToPhase(EFELSkatePhase NewPhase)
{
        CurrentPhase = NewPhase;
        PhaseTimer = 0.f;
}

void AFELSkateboardingGameplayActor::HandleOllieInput()
{
        if (CurrentPhase == EFELSkatePhase::Cruising || CurrentPhase == EFELSkatePhase::Manual)
        {
                TransitionToPhase(EFELSkatePhase::Ollie);
                Speed01 = FMath::Clamp(Speed01 + 0.1f, 0.f, 1.f);
        }
}

void AFELSkateboardingGameplayActor::HandleTrickInput(int32 TrickId)
{
        if (CurrentPhase != EFELSkatePhase::Ollie && CurrentPhase != EFELSkatePhase::AirTrick)
                return;

        TransitionToPhase(EFELSkatePhase::AirTrick);
        const float PRQ01 = FMath::Clamp(GetPRQ() * 0.01f, 0.f, 1.f);
        const float LandChance = FMath::Lerp(0.6f, 0.96f, PRQ01) * Balance01;

        if (FMath::FRand() < LandChance)
        {
                float TrickValue = FMath::Lerp(50.f, 200.f, FMath::Clamp(TrickId * 0.15f, 0.f, 1.f));
                TrickValue *= (1.f + PRQ01 * 0.3f);
                ScoreCard.CurrentComboScore += TrickValue;
                ComboTrickCount++;
                ScoreCard.ComboMultiplier = 1.f + ComboTrickCount * 0.25f;
                ComboGraceTimer = FMath::Lerp(2.f, 3.5f, PRQ01);
                ScoreCard.TricksLanded++;
        }
        else
        {
                TriggerBail();
        }
}

void AFELSkateboardingGameplayActor::HandleGrindInput()
{
        if (CurrentPhase == EFELSkatePhase::Ollie || CurrentPhase == EFELSkatePhase::AirTrick ||
                CurrentPhase == EFELSkatePhase::Cruising)
        {
                TransitionToPhase(EFELSkatePhase::Grind);
                ScoreCard.GrindsCompleted++;
                ComboTrickCount++;
                ScoreCard.ComboMultiplier = 1.f + ComboTrickCount * 0.25f;
                ScoreCard.CurrentComboScore += 40.f;
                ComboGraceTimer = 2.5f;
        }
}

void AFELSkateboardingGameplayActor::HandleManualInput()
{
        if (CurrentPhase == EFELSkatePhase::Landing || CurrentPhase == EFELSkatePhase::Cruising)
        {
                TransitionToPhase(EFELSkatePhase::Manual);
                ScoreCard.ManualsCompleted++;
        }
}

void AFELSkateboardingGameplayActor::Tick(float DeltaSeconds)
{
        Super::Tick(DeltaSeconds);
        if (!CachedGameMode.IsValid() || !CachedGameState.IsValid()) return;
        if (CachedGameState->HasMatchEnded()) return;

        PhaseTimer += DeltaSeconds;
        const float PRQ01 = FMath::Clamp(GetPRQ() * 0.01f, 0.f, 1.f);

        // Combo grace countdown
        if (ComboGraceTimer > 0.f)
        {
                ComboGraceTimer -= DeltaSeconds;
                if (ComboGraceTimer <= 0.f && ComboTrickCount > 0)
                        CommitCombo();
        }

        switch (CurrentPhase)
        {
        case EFELSkatePhase::Cruising:
                Speed01 = FMath::Clamp(Speed01 - 0.02f * DeltaSeconds, 0.1f, 1.f);
                break;
        case EFELSkatePhase::Ollie:
                if (PhaseTimer > 0.4f) TransitionToPhase(EFELSkatePhase::AirTrick);
                break;
        case EFELSkatePhase::AirTrick:
                if (PhaseTimer > FMath::Lerp(1.2f, 2.f, Speed01))
                {
                        TransitionToPhase(EFELSkatePhase::Landing);
                }
                break;
        case EFELSkatePhase::Grind:
                {
                        const float GrindDrain = FMath::Max(0.05f, 0.15f - PRQ01 * 0.08f);
                        Balance01 = FMath::Clamp(Balance01 - GrindDrain * DeltaSeconds, 0.f, 1.f);
                        ScoreCard.CurrentComboScore += 30.f * DeltaSeconds;
                        ComboGraceTimer = 2.5f;
                        if (Balance01 < 0.1f) TriggerBail();
                        if (PhaseTimer > FMath::Lerp(2.f, 4.f, PRQ01))
                                TransitionToPhase(EFELSkatePhase::Landing);
                }
                break;
        case EFELSkatePhase::Manual:
                {
                        const float ManualDrain = FMath::Max(0.04f, 0.12f - PRQ01 * 0.06f);
                        Balance01 = FMath::Clamp(Balance01 - ManualDrain * DeltaSeconds, 0.f, 1.f);
                        ScoreCard.CurrentComboScore += 15.f * DeltaSeconds;
                        ComboGraceTimer = 2.f;
                        if (Balance01 < 0.08f) TriggerBail();
                }
                break;
        case EFELSkatePhase::Landing:
                {
                        const float LandWindow = FMath::Lerp(0.15f, 0.4f, PRQ01);
                        if (PhaseTimer < LandWindow)
                                Balance01 = FMath::Clamp(Balance01 + 0.3f, 0.f, 1.f);
                        if (PhaseTimer > 0.5f) TransitionToPhase(EFELSkatePhase::Cruising);
                }
                break;
        case EFELSkatePhase::Bail:
                if (PhaseTimer > 1.5f)
                {
                        Balance01 = 0.8f;
                        TransitionToPhase(EFELSkatePhase::Cruising);
                }
                break;
        }
}

void AFELSkateboardingGameplayActor::CommitCombo()
{
        const float FinalScore = ScoreCard.CurrentComboScore * ScoreCard.ComboMultiplier;
        ScoreCard.TotalScore += FinalScore;
        if (FinalScore > ScoreCard.BestComboScore)
                ScoreCard.BestComboScore = FinalScore;

        if (CachedGameState.IsValid() && CachedGameState->IsScoringEnabled())
                CachedGameState->AddScore(FMath::FloorToInt(FinalScore * 0.01f));

        ScoreCard.CurrentComboScore = 0.f;
        ScoreCard.ComboMultiplier = 1.f;
        ComboTrickCount = 0;
}

void AFELSkateboardingGameplayActor::TriggerBail()
{
        ScoreCard.Bails++;
        ScoreCard.CurrentComboScore = 0.f;
        ScoreCard.ComboMultiplier = 1.f;
        ComboTrickCount = 0;
        ComboGraceTimer = 0.f;
        TransitionToPhase(EFELSkatePhase::Bail);
}

FString AFELSkateboardingGameplayActor::BuildHudLine() const
{
        const TCHAR* PhaseName = TEXT("Idle");
        switch (CurrentPhase)
        {
        case EFELSkatePhase::Cruising: PhaseName = TEXT("Cruising"); break;
        case EFELSkatePhase::Ollie: PhaseName = TEXT("Ollie!"); break;
        case EFELSkatePhase::Grind: PhaseName = TEXT("GRINDING"); break;
        case EFELSkatePhase::Manual: PhaseName = TEXT("MANUAL"); break;
        case EFELSkatePhase::AirTrick: PhaseName = TEXT("AIR!"); break;
        case EFELSkatePhase::Landing: PhaseName = TEXT("Landing"); break;
        case EFELSkatePhase::Bail: PhaseName = TEXT("BAIL"); break;
        }
        return FString::Printf(
                TEXT("Skate · %s · combo %.0f × %.1f · total %.0f · best %.0f"),
                PhaseName, ScoreCard.CurrentComboScore, ScoreCard.ComboMultiplier,
                ScoreCard.TotalScore, ScoreCard.BestComboScore);
}
