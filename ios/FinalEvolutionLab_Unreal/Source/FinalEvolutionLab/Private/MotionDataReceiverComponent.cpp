#include "MotionDataReceiverComponent.h"

#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"

UMotionDataReceiverComponent::UMotionDataReceiverComponent()
{
    PrimaryComponentTick.bCanEverTick = false;
}

void UMotionDataReceiverComponent::BeginPlay()
{
    Super::BeginPlay();
    UE_LOG(LogTemp, Log, TEXT("[MotionDataReceiver] Ready to receive motion data."));
}

void UMotionDataReceiverComponent::OnMotionData(const FString& JsonString)
{
    TSharedPtr<FJsonObject> JsonObject;
    const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonString);

    if (!FJsonSerializer::Deserialize(Reader, JsonObject) || !JsonObject.IsValid())
    {
        UE_LOG(LogTemp, Error, TEXT("[MotionDataReceiver] Failed to parse motion JSON: %s"), *JsonString);
        return;
    }

    double Value = 0.0;
    if (JsonObject->TryGetNumberField(TEXT("ax"), Value)) LatestPayload.Ax = static_cast<float>(Value);
    if (JsonObject->TryGetNumberField(TEXT("ay"), Value)) LatestPayload.Ay = static_cast<float>(Value);
    if (JsonObject->TryGetNumberField(TEXT("az"), Value)) LatestPayload.Az = static_cast<float>(Value);
    if (JsonObject->TryGetNumberField(TEXT("gx"), Value)) LatestPayload.Gx = static_cast<float>(Value);
    if (JsonObject->TryGetNumberField(TEXT("gy"), Value)) LatestPayload.Gy = static_cast<float>(Value);
    if (JsonObject->TryGetNumberField(TEXT("gz"), Value)) LatestPayload.Gz = static_cast<float>(Value);
    if (JsonObject->TryGetNumberField(TEXT("t"), Value)) LatestPayload.Timestamp = Value;

    OnMotionPayloadUpdated.Broadcast(LatestPayload);
}
