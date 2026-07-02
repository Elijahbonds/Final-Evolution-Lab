#include "FELNeuroCognitiveSubsystem.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"

float UFELNeuroCognitiveSubsystem::SafeGetFloat(const TSharedPtr<FJsonObject>& Obj, const FString& Key, float Default) const {
    double Val = 0.0;
    return (Obj.IsValid() && Obj->TryGetNumberField(Key, Val)) ? static_cast<float>(Val) : Default;
}

void UFELNeuroCognitiveSubsystem::UpdateFromBridgePayload(const FString& JsonString) {
    TSharedPtr<FJsonObject> JsonObject;
    TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonString);
    if (!FJsonSerializer::Deserialize(Reader, JsonObject) || !JsonObject.IsValid()) return;
    Data.MRIScore    = SafeGetFloat(JsonObject, TEXT("mri_score"),    50.f);
    Data.ARV         = SafeGetFloat(JsonObject, TEXT("arv"),           0.5f);
    Data.ESI         = SafeGetFloat(JsonObject, TEXT("esi"),          50.f);
    Data.PacingScore = SafeGetFloat(JsonObject, TEXT("pacing_score"), 50.f);
    RecalculateModifiers();
}

void UFELNeuroCognitiveSubsystem::RecalculateModifiers() {
    Data.ComboDecayModifier         = 0.6f + Data.ARV * 0.8f;
    Data.PerfectGuardWindowModifier = 0.8f + (Data.ESI / 100.f) * 0.4f;
    Data.QTEApexWindowModifier      = 0.85f + (Data.PacingScore / 100.f) * 0.30f;
}
