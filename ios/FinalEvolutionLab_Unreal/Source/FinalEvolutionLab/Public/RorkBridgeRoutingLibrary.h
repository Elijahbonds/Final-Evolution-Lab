#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "RorkBridgeRoutingLibrary.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API URorkBridgeRoutingLibrary : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintCallable, Category = "Rork|Bridge", meta = (WorldContext = "WorldContextObject"))
    static bool RouteNativeScoreToBridge(UObject* WorldContextObject, int32 Score);

    UFUNCTION(BlueprintCallable, Category = "Rork|Bridge", meta = (WorldContext = "WorldContextObject"))
    static bool RouteMotionJsonToReceiver(UObject* WorldContextObject, const FString& JsonString);
};
