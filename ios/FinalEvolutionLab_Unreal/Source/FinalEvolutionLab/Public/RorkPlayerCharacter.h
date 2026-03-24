#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "InputActionValue.h"
#include "RorkPlayerCharacter.generated.h"

class UInputAction;
class UInputMappingContext;
class URorkNativeBridgeComponent;
class APlayerScoreManager;

UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API ARorkPlayerCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ARorkPlayerCharacter();

protected:
    virtual void BeginPlay() override;
    virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;

private:
    void Move(const FInputActionValue& Value);
    void Dunk(const FInputActionValue& Value);
    void CacheBridgeAndScoreManager();

    UPROPERTY(EditAnywhere, Category = "Rork|Movement")
    float MoveSpeed = 500.f;

    UPROPERTY(EditAnywhere, Category = "Rork|Movement")
    float DunkImpulse = 700.f;

    UPROPERTY(EditAnywhere, Category = "Rork|Score")
    int32 DunkScoreIncrement = 10;

    UPROPERTY(EditAnywhere, Category = "Rork|Input")
    TObjectPtr<UInputMappingContext> GameplayMappingContext;

    UPROPERTY(EditAnywhere, Category = "Rork|Input")
    TObjectPtr<UInputAction> MoveAction;

    UPROPERTY(EditAnywhere, Category = "Rork|Input")
    TObjectPtr<UInputAction> DunkAction;

    UPROPERTY(Transient)
    TObjectPtr<URorkNativeBridgeComponent> RorkBridge;

    UPROPERTY(Transient)
    TObjectPtr<APlayerScoreManager> PlayerScoreManager;
};
