#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FinalEvolutionTypes.h"
#include "ArenaActor.generated.h"

class UPointLightComponent;
class UStaticMeshComponent;
class UMaterialInstanceDynamic;
class USceneComponent;

UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API AArenaActor : public AActor
{
    GENERATED_BODY()

public:
    AArenaActor();

    UFUNCTION(BlueprintCallable, Category = "Arena")
    void ApplyTheme(EGameModeId Mode);

protected:
    virtual void BeginPlay() override;

private:
    UPROPERTY(VisibleAnywhere, Category = "Arena")
    TObjectPtr<USceneComponent> SceneRoot;

    UPROPERTY(VisibleAnywhere, Category = "Arena")
    TObjectPtr<UStaticMeshComponent> ArenaMesh;

    UPROPERTY(VisibleAnywhere, Category = "Arena")
    TObjectPtr<UPointLightComponent> ArenaLight;

    UPROPERTY(EditAnywhere, Category = "Arena")
    EGameModeId ActiveMode = EGameModeId::DUNK_CONTEST_VENICE;

    UPROPERTY(EditAnywhere, Category = "Arena")
    int32 WallMaterialSlotIndex = 0;

    UPROPERTY(EditAnywhere, Category = "Arena")
    int32 FloorMaterialSlotIndex = 1;

    UPROPERTY(Transient, BlueprintReadOnly, Category = "Arena", meta = (AllowPrivateAccess = "true"))
    TObjectPtr<UMaterialInstanceDynamic> WallMaterialInstance;

    UPROPERTY(Transient, BlueprintReadOnly, Category = "Arena", meta = (AllowPrivateAccess = "true"))
    TObjectPtr<UMaterialInstanceDynamic> FloorMaterialInstance;
};
