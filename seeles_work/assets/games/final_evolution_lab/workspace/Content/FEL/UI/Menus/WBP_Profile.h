// WBP_Profile.h — Avatar, XP, PRQ sparkline, shard balance
#pragma once
#include "CoreMinimal.h"
#include "CommonActivatableWidget.h"
#include "WBP_Profile.generated.h"

USTRUCT(BlueprintType)
struct FFELProfileData
{
    GENERATED_BODY()
    UPROPERTY(BlueprintReadOnly) FString DisplayName;
    UPROPERTY(BlueprintReadOnly) FString AvatarUrl;
    UPROPERTY(BlueprintReadOnly) int32 TotalXP = 0;
    UPROPERTY(BlueprintReadOnly) float PRQScore = 0.f;
    UPROPERTY(BlueprintReadOnly) int32 ShardBalance = 0;
    UPROPERTY(BlueprintReadOnly) TArray<float> PRQHistory7Day;
};

UCLASS()
class FINALEVOLUTIONLAB_API UWBP_Profile : public UCommonActivatableWidget
{
    GENERATED_BODY()
public:
    UPROPERTY(BlueprintReadOnly, Category = "FEL|Profile")
    FFELProfileData ProfileData;

protected:
    virtual void NativeOnActivated() override;
    /** GET /users/{user_id}/profile via FELAPIClient */
    void FetchProfile();
};
