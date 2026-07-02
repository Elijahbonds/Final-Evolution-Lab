// WBP_MatchResult.h — WIN/DRAW/LOSS result screen with economy reward animations
#pragma once
#include "CoreMinimal.h"
#include "CommonActivatableWidget.h"
#include "WBP_MatchResult.generated.h"

UENUM(BlueprintType)
enum class EFELMatchOutcome : uint8
{
    Win     UMETA(DisplayName = "Win"),
    Draw    UMETA(DisplayName = "Draw"),
    Loss    UMETA(DisplayName = "Loss"),
};

UCLASS()
class FINALEVOLUTIONLAB_API UWBP_MatchResult : public UCommonActivatableWidget
{
    GENERATED_BODY()
public:
    UPROPERTY(BlueprintReadWrite, Category = "FEL|Result")
    EFELMatchOutcome Outcome = EFELMatchOutcome::Loss;

    UPROPERTY(BlueprintReadWrite, Category = "FEL|Result")
    int32 XPEarned = 0;

    UPROPERTY(BlueprintReadWrite, Category = "FEL|Result")
    int32 ShardsEarned = 0;

    UPROPERTY(BlueprintReadWrite, Category = "FEL|Result")
    float PRQDelta = 0.f;

    /** Play XP counter + shard counter animations, then show buttons */
    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|Result")
    void PlayRewardAnimation();

    UFUNCTION(BlueprintCallable, Category = "FEL|Menu")
    void OnNextMatchPressed();

    UFUNCTION(BlueprintCallable, Category = "FEL|Menu")
    void OnMainMenuPressed();

protected:
    virtual void NativeOnActivated() override;
};
