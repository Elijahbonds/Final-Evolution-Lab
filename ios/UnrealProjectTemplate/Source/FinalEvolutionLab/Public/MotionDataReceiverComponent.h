#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "MotionDataReceiverComponent.generated.h"

USTRUCT(BlueprintType)
struct FMotionPayload
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly) float Ax = 0.f;
    UPROPERTY(BlueprintReadOnly) float Ay = 0.f;
    UPROPERTY(BlueprintReadOnly) float Az = 0.f;
    UPROPERTY(BlueprintReadOnly) float Gx = 0.f;
    UPROPERTY(BlueprintReadOnly) float Gy = 0.f;
    UPROPERTY(BlueprintReadOnly) float Gz = 0.f;
    UPROPERTY(BlueprintReadOnly) double Timestamp = 0.0;
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnMotionPayloadUpdated, const FMotionPayload&, Payload);

UCLASS(ClassGroup=(Rork), BlueprintType, Blueprintable, meta=(BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UMotionDataReceiverComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UMotionDataReceiverComponent();

    // Native iOS host should call with JSON payload: {ax, ay, az, gx, gy, gz, t}
    UFUNCTION(BlueprintCallable, Category = "Rork|Motion")
    void OnMotionData(const FString& JsonString);

    UFUNCTION(BlueprintPure, Category = "Rork|Motion")
    FMotionPayload GetLatestPayload() const { return LatestPayload; }

    UPROPERTY(BlueprintAssignable, Category = "Rork|Motion")
    FOnMotionPayloadUpdated OnMotionPayloadUpdated;

protected:
    virtual void BeginPlay() override;

private:
    UPROPERTY(VisibleAnywhere, Category = "Rork|Motion")
    FMotionPayload LatestPayload;
};
