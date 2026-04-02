// Copyright Final Evolution Lab. All Rights Reserved.
// FELCreatorChallengeManager.cpp

#include "FELCreatorChallengeManager.h"
#include "FELCreatorManager.h"
#include "Kismet/GameplayStatics.h"

UFELCreatorChallengeManager::UFELCreatorChallengeManager()
{
    PrimaryComponentTick.bCanEverTick = false;
}

void UFELCreatorChallengeManager::BeginPlay()
{
    Super::BeginPlay();
}

void UFELCreatorChallengeManager::ActivateCreatorChallenges(const FString& CreatorID)
{
    ActiveCreatorID = CreatorID;
    ActiveChallenges.Empty();
    ChallengeScores.Empty();

    if (UGameInstance* GI = UGameplayStatics::GetGameInstance(this))
    {
        if (UFELCreatorManager* CM = GI->GetSubsystem<UFELCreatorManager>())
        {
            ActiveChallenges = CM->GetCreatorChallenges(CreatorID);
            for (const FCreatorChallenge& C : ActiveChallenges)
            {
                ChallengeScores.Add(C.ChallengeID, 0);
            }
            UE_LOG(LogTemp, Log, TEXT("[FEL Challenges] Activated %d challenges for: %s"),
                ActiveChallenges.Num(), *CreatorID);
        }
    }
}

void UFELCreatorChallengeManager::ReportScore(const FString& ChallengeID, int32 Score)
{
    if (!ChallengeScores.Contains(ChallengeID)) return;

    ChallengeScores[ChallengeID] = Score;

    // Find the challenge to check completion
    for (const FCreatorChallenge& C : ActiveChallenges)
    {
        if (C.ChallengeID == ChallengeID)
        {
            OnChallengeProgress.Broadcast(ChallengeID, Score, C.RequiredScore);

            if (Score >= C.RequiredScore)
            {
                // Challenge completed!
                if (UGameInstance* GI = UGameplayStatics::GetGameInstance(this))
                {
                    if (UFELCreatorManager* CM = GI->GetSubsystem<UFELCreatorManager>())
                    {
                        CM->CompleteChallenge(ActiveCreatorID, ChallengeID);
                    }
                }
                OnChallengeUnlocked.Broadcast(ChallengeID, C.Reward);
                UE_LOG(LogTemp, Log, TEXT("[FEL Challenges] Completed: %s | Reward: %s"),
                    *ChallengeID, *C.Reward);
            }
            break;
        }
    }
}

void UFELCreatorChallengeManager::IncrementScore(const FString& ChallengeID, int32 Amount)
{
    if (int32* Current = ChallengeScores.Find(ChallengeID))
    {
        ReportScore(ChallengeID, *Current + Amount);
    }
}

TArray<FCreatorChallenge> UFELCreatorChallengeManager::GetActiveChallenges() const
{
    return ActiveChallenges;
}

float UFELCreatorChallengeManager::GetChallengeProgress(const FString& ChallengeID) const
{
    const int32* Score = ChallengeScores.Find(ChallengeID);
    if (!Score) return 0.f;

    for (const FCreatorChallenge& C : ActiveChallenges)
    {
        if (C.ChallengeID == ChallengeID && C.RequiredScore > 0)
        {
            return FMath::Clamp(static_cast<float>(*Score) / C.RequiredScore, 0.f, 1.f);
        }
    }
    return 0.f;
}

bool UFELCreatorChallengeManager::IsChallengeActive(const FString& ChallengeID) const
{
    return ChallengeScores.Contains(ChallengeID);
}
