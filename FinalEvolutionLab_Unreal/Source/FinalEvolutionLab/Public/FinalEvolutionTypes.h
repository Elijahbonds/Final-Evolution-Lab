#pragma once

#include "CoreMinimal.h"
#include "FinalEvolutionTypes.generated.h"

UENUM(BlueprintType)
enum class EGameModeId : uint8
{
    BASKETBALL_HEAD_TO_HEAD UMETA(DisplayName = "Basketball 1v1"),
    DUNK_CONTEST_VENICE UMETA(DisplayName = "Venice Dunk Contest"),
    BASKETBALL_3V3 UMETA(DisplayName = "Basketball 3v3"),
    FOOTBALL_QB_DRILL UMETA(DisplayName = "QB Drill"),
    SOCCER_PENALTY UMETA(DisplayName = "Soccer Penalty"),
    TENNIS_SERVE UMETA(DisplayName = "Tennis Serve"),
    VOLLEYBALL_SPIKE UMETA(DisplayName = "Volleyball Spike")
};

USTRUCT(BlueprintType)
struct FGameAttributes
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float VerticalJump;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float NeuralDrive;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float PopForce;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float Efficiency;

    FGameAttributes()
        : VerticalJump(20.0f)
        , NeuralDrive(50.0f)
        , PopForce(50.0f)
        , Efficiency(50.0f)
    {
    }
};

USTRUCT(BlueprintType)
struct FArenaTheme
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    FLinearColor WallColor;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    FLinearColor WallAccent;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    FLinearColor FloorColor;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float LightIntensity;

    FArenaTheme()
        : WallColor(FLinearColor::Gray)
        , WallAccent(FLinearColor::White)
        , FloorColor(FLinearColor::Black)
        , LightIntensity(1.0f)
    {
    }
};
