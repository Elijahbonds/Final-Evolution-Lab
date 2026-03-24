#include "ArenaActor.h"

#include "Components/PointLightComponent.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Materials/MaterialInstanceDynamic.h"

AArenaActor::AArenaActor()
{
    PrimaryActorTick.bCanEverTick = false;

    SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    SetRootComponent(SceneRoot);

    ArenaMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("ArenaMesh"));
    ArenaMesh->SetupAttachment(SceneRoot);
    ArenaMesh->SetMobility(EComponentMobility::Movable);

    ArenaLight = CreateDefaultSubobject<UPointLightComponent>(TEXT("ArenaLight"));
    ArenaLight->SetupAttachment(SceneRoot);
    ArenaLight->SetMobility(EComponentMobility::Movable);
    ArenaLight->Intensity = 1800.0f;
}

void AArenaActor::BeginPlay()
{
    Super::BeginPlay();

    if (ArenaMesh != nullptr)
    {
        WallMaterialInstance = ArenaMesh->CreateAndSetMaterialInstanceDynamic(WallMaterialSlotIndex);
        FloorMaterialInstance = ArenaMesh->CreateAndSetMaterialInstanceDynamic(FloorMaterialSlotIndex);
    }

    ApplyTheme(ActiveMode);
}

void AArenaActor::ApplyTheme(EGameModeId Mode)
{
    FArenaTheme SelectedTheme;

    // Logic matching arena theme records by mode.
    switch (Mode)
    {
    case EGameModeId::DUNK_CONTEST_VENICE:
        SelectedTheme.WallColor = FLinearColor(0.02f, 0.02f, 0.05f);   // Deep blue
        SelectedTheme.WallAccent = FLinearColor(0.0f, 0.95f, 1.0f);    // Cyan
        SelectedTheme.FloorColor = FLinearColor(0.04f, 0.04f, 0.08f);  // Dark slate
        SelectedTheme.LightIntensity = 1.15f;
        break;
    case EGameModeId::BASKETBALL_HEAD_TO_HEAD:
        SelectedTheme.WallColor = FLinearColor(0.04f, 0.03f, 0.02f);   // Asphalt brown
        SelectedTheme.WallAccent = FLinearColor(1.0f, 0.56f, 0.15f);   // Street orange
        SelectedTheme.FloorColor = FLinearColor(0.12f, 0.08f, 0.04f);  // Court wood
        SelectedTheme.LightIntensity = 1.0f;
        break;
    case EGameModeId::BASKETBALL_3V3:
        SelectedTheme.WallColor = FLinearColor(0.03f, 0.05f, 0.03f);   // Night court green
        SelectedTheme.WallAccent = FLinearColor(0.2f, 0.95f, 0.5f);    // Neon green
        SelectedTheme.FloorColor = FLinearColor(0.08f, 0.09f, 0.06f);  // Desaturated turf
        SelectedTheme.LightIntensity = 1.1f;
        break;
    case EGameModeId::FOOTBALL_QB_DRILL:
        SelectedTheme.WallColor = FLinearColor(0.05f, 0.02f, 0.01f);   // Deep orange
        SelectedTheme.WallAccent = FLinearColor(1.0f, 0.49f, 0.15f);   // Orange
        SelectedTheme.FloorColor = FLinearColor(0.05f, 0.09f, 0.05f);  // Field green
        SelectedTheme.LightIntensity = 1.05f;
        break;
    case EGameModeId::SOCCER_PENALTY:
        SelectedTheme.WallColor = FLinearColor(0.02f, 0.08f, 0.05f);   // Pitch green
        SelectedTheme.WallAccent = FLinearColor(0.95f, 0.95f, 0.95f);  // White line
        SelectedTheme.FloorColor = FLinearColor(0.03f, 0.14f, 0.08f);  // Grass tone
        SelectedTheme.LightIntensity = 1.0f;
        break;
    case EGameModeId::TENNIS_SERVE:
        SelectedTheme.WallColor = FLinearColor(0.06f, 0.06f, 0.02f);   // Clay dusk
        SelectedTheme.WallAccent = FLinearColor(0.95f, 0.88f, 0.2f);   // Tennis yellow
        SelectedTheme.FloorColor = FLinearColor(0.05f, 0.1f, 0.06f);   // Court green
        SelectedTheme.LightIntensity = 1.0f;
        break;
    case EGameModeId::VOLLEYBALL_SPIKE:
        SelectedTheme.WallColor = FLinearColor(0.02f, 0.08f, 0.12f);   // Beach dusk blue
        SelectedTheme.WallAccent = FLinearColor(0.98f, 0.75f, 0.14f);  // Sand gold
        SelectedTheme.FloorColor = FLinearColor(0.18f, 0.14f, 0.08f);  // Sand tone
        SelectedTheme.LightIntensity = 1.08f;
        break;
    default:
        break;
    }

    if (WallMaterialInstance != nullptr)
    {
        WallMaterialInstance->SetVectorParameterValue(TEXT("BaseColor"), SelectedTheme.WallColor);
        WallMaterialInstance->SetVectorParameterValue(TEXT("AccentColor"), SelectedTheme.WallAccent);
    }

    if (FloorMaterialInstance != nullptr)
    {
        FloorMaterialInstance->SetVectorParameterValue(TEXT("BaseColor"), SelectedTheme.FloorColor);
        FloorMaterialInstance->SetVectorParameterValue(TEXT("AccentColor"), SelectedTheme.WallAccent);
    }

    if (ArenaLight != nullptr)
    {
        ArenaLight->SetIntensity(1800.0f * SelectedTheme.LightIntensity);
        ArenaLight->SetLightColor(FLinearColor(
            SelectedTheme.WallAccent.R,
            SelectedTheme.WallAccent.G,
            SelectedTheme.WallAccent.B,
            1.0f
        ));
    }

    ActiveMode = Mode;
}
