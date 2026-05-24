#pragma once
#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELNeuroCognitiveSubsystem.generated.h"

USTRUCT(BlueprintType)
struct FFELNeuroCogData {
    GENERATED_BODY()
    UPROPERTY(BlueprintReadOnly) float MRIScore = 50.f;
    UPROPERTY(BlueprintReadOnly) float ARV = 0.5f;
    UPROPERTY(BlueprintReadOnly) float ESI = 50.f;
    UPROPERTY(BlueprintReadOnly) float PacingScore = 50.f;
    UPROPERTY(BlueprintReadOnly) float ComboDecayModifier = 1.0f;
    UPROPERTY(BlueprintReadOnly) float PerfectGuardWindowModifier = 1.0f;
    UPROPERTY(BlueprintReadOnly) float QTEApexWindowModifier = 1.0f;
};

UCLASS()
class FINALEVOLUTIONLAB_API UFELNeuroCognitiveSubsystem : public UGameInstanceSubsystem {
    GENERATED_BODY()
public:
    UFUNCTION(BlueprintCallable, Category="FEL|Neuro") void UpdateFromBridgePayload(const FString& JsonString);
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetMRIScore() const { return Data.MRIScore; }
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetARV() const { return Data.ARV; }
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetESI() const { return Data.ESI; }
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetPacingScore() const { return Data.PacingScore; }
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetComboDecayModifier() const { return Data.ComboDecayModifier; }
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetPerfectGuardWindowModifier() const { return Data.PerfectGuardWindowModifier; }
    UFUNCTION(BlueprintPure, Category="FEL|Neuro") float GetQTEApexWindowModifier() const { return Data.QTEApexWindowModifier; }
private:
    FFELNeuroCogData Data;
    void RecalculateModifiers();
    float SafeGetFloat(const TSharedPtr<FJsonObject>& Obj, const FString& Key, float Default) const;
};
