#include "RorkBridgeRoutingLibrary.h"

#include "EngineUtils.h"
#include "MotionDataReceiverComponent.h"
#include "RorkNativeBridgeComponent.h"

bool URorkBridgeRoutingLibrary::RouteNativeScoreToBridge(UObject* WorldContextObject, int32 Score)
{
    if (!IsValid(WorldContextObject))
    {
        return false;
    }

    UWorld* World = WorldContextObject->GetWorld();
    if (!IsValid(World))
    {
        return false;
    }

    for (TActorIterator<AActor> It(World); It; ++It)
    {
        if (URorkNativeBridgeComponent* Bridge = It->FindComponentByClass<URorkNativeBridgeComponent>())
        {
            Bridge->OnRorkScoreUpdated(Score);
            return true;
        }
    }

    return false;
}

bool URorkBridgeRoutingLibrary::RouteMotionJsonToReceiver(UObject* WorldContextObject, const FString& JsonString)
{
    if (!IsValid(WorldContextObject))
    {
        return false;
    }

    UWorld* World = WorldContextObject->GetWorld();
    if (!IsValid(World))
    {
        return false;
    }

    for (TActorIterator<AActor> It(World); It; ++It)
    {
        if (UMotionDataReceiverComponent* Receiver = It->FindComponentByClass<UMotionDataReceiverComponent>())
        {
            Receiver->OnMotionData(JsonString);
            return true;
        }
    }

    return false;
}
