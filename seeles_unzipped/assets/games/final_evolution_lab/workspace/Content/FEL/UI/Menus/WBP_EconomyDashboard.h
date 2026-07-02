// WBP_EconomyDashboard.h — Session history, XP/shards per session, PRQ delta
#pragma once
#include "CoreMinimal.h"
#include "CommonActivatableWidget.h"
#include "WBP_EconomyDashboard.generated.h"

USTRUCT(BlueprintType)
struct FFELSessionRecord
{
    GENERATED_BODY()
    UPROPERTY(BlueprintReadOnly) FString ModeId;
    UPROPERTY(BlueprintReadOnly) int32 XPEarned = 0;
    UPROPERTY(BlueprintReadOnly) int32 ShardsEarned = 0;
    UPROPERTY(BlueprintReadOnly) float PRQDelta = 0.f;
    UPROPERTY(BlueprintReadOnly) float MRIScore = 0.f;
    UPROPERTY(BlueprintReadOnly) FString Outcome;
    UPROPERTY(BlueprintReadOnly) FString Timestamp;
};

UCLASS()
class FINALEVOLUTIONLAB_API UWBP_EconomyDashboard : public UCommonActivatableWidget
{
    GENERATED_BODY()
public:
    /** Last 10 session records — populated on activate via FELEconomySubsystem */
    UPROPERTY(BlueprintReadOnly, Category = "FEL|Economy")
    TArray<FFELSessionRecord> SessionHistory;

protected:
    virtual void NativeOnActivated() override;
    void FetchSessionHistory();
};
