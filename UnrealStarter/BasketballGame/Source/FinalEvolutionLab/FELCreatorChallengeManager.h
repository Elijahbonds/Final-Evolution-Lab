// Copyright Final Evolution Lab. All Rights Reserved.
// FELCreatorChallengeManager.h - Creator Challenge Integration
// Manages creator-specific challenges and rewards within game modes.

#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "FELCreatorProfile.h"
#include "FELCreatorChallengeManager.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FOnChallengeProgress, const FString&, ChallengeID, int32, CurrentScore, int32, RequiredScore);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnChallengeUnlocked, const FString&, ChallengeID, const FString&, RewardDescription);

/**
 * UFELCreatorChallengeManager - Actor component that tracks creator challenge progress.
 * Attach to the game mode actor to enable creator challenges.
 */
UCLASS(ClassGroup=(Custom), meta=(BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELCreatorChallengeManager : public UActorComponent
{
    GENERATED_BODY()

public:
    UFELCreatorChallengeManager();

    /** Start tracking a specific creator's challenges */
    UFUNCTION(BlueprintCallable, Category = "FEL|Challenges")
    void ActivateCreatorChallenges(const FString& CreatorID);

    /** Report progress towards active challenges */
    UFUNCTION(BlueprintCallable, Category = "FEL|Challenges")
    void ReportScore(const FString& ChallengeID, int32 Score);

    /** Increment score by amount */
    UFUNCTION(BlueprintCallable, Category = "FEL|Challenges")
    void IncrementScore(const FString& ChallengeID, int32 Amount = 1);

    /** Get all active challenges */
    UFUNCTION(BlueprintCallable, Category = "FEL|Challenges")
    TArray<FCreatorChallenge> GetActiveChallenges() const;

    /** Get progress for a challenge (0.0 to 1.0) */
    UFUNCTION(BlueprintPure, Category = "FEL|Challenges")
    float GetChallengeProgress(const FString& ChallengeID) const;

    /** Check if a challenge is active */
    UFUNCTION(BlueprintPure, Category = "FEL|Challenges")
    bool IsChallengeActive(const FString& ChallengeID) const;

    /** Get active creator ID */
    UFUNCTION(BlueprintPure, Category = "FEL|Challenges")
    FString GetActiveCreatorID() const { return ActiveCreatorID; }

    // Delegates
    UPROPERTY(BlueprintAssignable, Category = "FEL|Challenges")
    FOnChallengeProgress OnChallengeProgress;

    UPROPERTY(BlueprintAssignable, Category = "FEL|Challenges")
    FOnChallengeUnlocked OnChallengeUnlocked;

protected:
    virtual void BeginPlay() override;

private:
    FString ActiveCreatorID;
    TArray<FCreatorChallenge> ActiveChallenges;
    TMap<FString, int32> ChallengeScores;
};
