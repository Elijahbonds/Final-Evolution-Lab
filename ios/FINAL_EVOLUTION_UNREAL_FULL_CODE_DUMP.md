# Final Evolution Lab Unreal — Full Code Dump

Generated from branch `cursor/unity-project-ios-setup-deeb` at commit `5eb2213` on 2026-03-15T04:55:39.493248+00:00.

This document contains the full Unreal project scaffold and source under `FinalEvolutionLab_Unreal/`.

## FinalEvolutionLab_Unreal/Config/DefaultEngine.ini
```ini
[/Script/Engine.Engine]
+ActiveGameNameRedirects=(OldGameName="/Script/FinalEvolutionLab",NewGameName="/Script/FinalEvolutionLab")
```

## FinalEvolutionLab_Unreal/Config/DefaultGame.ini
```ini
[/Script/EngineSettings.GeneralProjectSettings]
ProjectID=091156524AF9E5A7B6A1C0A902F40E73
ProjectName=Final Evolution Lab
Description=Unreal scaffold for Final Evolution Lab bridge integration.
CompanyName=ElijahBonds1
CompanyDistinguishedName=ElijahBonds1
Homepage=github.com/Elijahbonds/rork-final-evolution-lab
SupportContact=elijahbonds1@gmail.com

[/Script/EngineSettings.GameMapsSettings]
GameDefaultMap=/Engine/Maps/Entry
EditorStartupMap=/Engine/Maps/Entry
GameInstanceClass=/Script/FinalEvolutionLab.FE_GameInstance
```

## FinalEvolutionLab_Unreal/Config/DefaultInput.ini
```ini
[/Script/Engine.InputSettings]
DefaultPlayerInputClass=/Script/EnhancedInput.EnhancedPlayerInput
DefaultInputComponentClass=/Script/EnhancedInput.EnhancedInputComponent
```

## FinalEvolutionLab_Unreal/FinalEvolutionLab.uproject
```json
{
  "FileVersion": 3,
  "EngineAssociation": "5.4",
  "Category": "Games",
  "Description": "Final Evolution Lab Unreal Engine scaffold with native iOS bridge support.",
  "Modules": [
    {
      "Name": "FinalEvolutionLab",
      "Type": "Runtime",
      "LoadingPhase": "Default"
    }
  ],
  "Plugins": [
    {
      "Name": "EnhancedInput",
      "Enabled": true
    },
    {
      "Name": "CommonUI",
      "Enabled": true
    }
  ]
}
```

## FinalEvolutionLab_Unreal/REACT_TO_UNREAL_MAPPING.md
```markdown
# React to Unreal Mapping Guide

| Web Component (React/Three.js) | Unreal Engine Equivalent |
|---|---|
| `App.tsx` / `UserContext` | `UFE_GameInstance` |
| `BasketballLab.tsx` | `AFE_LabManager` actor (or `ALevelScriptActor`) |
| `DunkerModel.tsx` | Skeletal mesh actor/character + Animation Blueprint |
| `ArenaRoom.tsx` | Level + PostProcessVolume + `AArenaActor` dynamic materials |
| `saveSystem.ts` | `UFE_SaveGame` + `UGameplayStatics` save/load in `UFE_GameInstance` |
| `CoachingPortal.tsx` | `UFE_CoachingPortalWidget` (UMG / CommonUI) |
| Rapier Physics | Chaos Physics (built-in Unreal) |

## Implemented in this scaffold

- `UFE_GameInstance` stores shards, PRQ, streak, and player attributes.
- `UFE_SaveGame` serializes shards/PRQ/attributes.
- `UFE_GameInstance::SavePlayerState()` and `LoadPlayerState()` handle persistence.
- `AArenaActor::ApplyTheme(EGameModeId)` applies mode-based wall/floor/light themes.
- `AFE_LabManager` manages current mode and syncs state from game instance.
- `UFE_CoachingPortalWidget` exposes portal actions and refresh hooks for UMG.

## UI + Input guidance

- Build portal and vault views in UMG.
- Prefer CommonUI widgets for cross-platform controller/touch behavior.
- Use Enhanced Input assets for gameplay and UI actions.

## Character guidance

- Import dunker GLB as skeletal mesh.
- Drive state transitions via Animation Blueprint (Idle/Run/Dunk/Special).
- Bind gameplay state (`EGameModeId`, PRQ, Neural Drive) into animation parameters.

## Material guidance

- Use a master material with:
  - `BaseColor` (Vector)
  - `AccentColor` (Vector)
  - `EmissiveIntensity` (Scalar)
- `AArenaActor` applies runtime values via dynamic material instances.

## Blueprint-first workflow

- Keep systems in C++ for deterministic core logic.
- Expose knobs with `UPROPERTY(EditAnywhere, BlueprintReadWrite)` and `UFUNCTION(BlueprintCallable)`.
- Tune balance in Blueprint/Editor without recompilation.
```

## FinalEvolutionLab_Unreal/README.md
```markdown
# Final Evolution Lab (Unreal Project Scaffold)

This is a real Unreal project scaffold you can open in Unreal Editor after generating project files.

## Structure

- `FinalEvolutionLab.uproject`
- `Config/`
  - `DefaultGame.ini`
  - `DefaultEngine.ini`
  - `DefaultInput.ini`
- `Source/`
  - `FinalEvolutionLab.Target.cs`
  - `FinalEvolutionLabEditor.Target.cs`
  - `FinalEvolutionLab/`
    - module bootstrap files
    - bridge and gameplay classes

## Included gameplay/bridge classes

- `ARorkPlayerCharacter`
  - Enhanced Input movement.
  - Dunk action updates local score first, then posts score to native.
- `APlayerScoreManager`
  - Centralized local score actor.
- `URorkNativeBridgeComponent`
  - Calls `_PostRorkScore(int32)` on iOS.
  - Exposes native score update callback/event hooks.
- `UMotionDataReceiverComponent`
  - Parses incoming motion JSON (`ax, ay, az, gx, gy, gz, t`).
- `URorkBridgeRoutingLibrary`
  - Utility route functions for native/plugin bridge calls into scene components.
- `AArenaActor`
  - Applies `FArenaTheme` by `EGameModeId`.
  - Pushes wall/floor colors into dynamic material parameters (`BaseColor`, `AccentColor`).
- `UFE_GameInstance` + `UFE_SaveGame`
  - Global player state (`Shards`, `PRQ`, `Attributes`) with save/load.
- `AFE_LabManager`
  - Session coordinator equivalent to lab-screen controller logic.
- `UFE_CoachingPortalWidget`
  - UMG portal widget base for progression/economy actions.

## Unreal setup steps

1. Open `FinalEvolutionLab.uproject` in Unreal Engine 5.4+.
2. Let Unreal generate/build C++ project files.
3. Create a character blueprint from `ARorkPlayerCharacter`.
4. Add in-world actors/components:
   - `APlayerScoreManager` actor in level.
   - `URorkNativeBridgeComponent` on player (or a dedicated bridge actor).
   - `UMotionDataReceiverComponent` on player or dedicated receiver actor.
5. Create Enhanced Input assets:
   - `IMC_Gameplay` mapping context.
   - `IA_Move` (Axis2D) bound to WASD/left stick.
   - `IA_Dunk` (Boolean) bound to Space / gamepad south button.
6. Assign those input assets on `ARorkPlayerCharacter` properties.
7. Review `REACT_TO_UNREAL_MAPPING.md` for component-level migration guidance.

## iOS native symbol compatibility

This repo's native iOS host already exports:

- `_PostRorkScore` via Swift `@_cdecl("_PostRorkScore")`

So Unreal can call the symbol directly on iOS builds.

Keep `Source/FinalEvolutionLab/Private/IOS/RorkNativeBridgeIOSStub.mm` as a stub only.
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab.Target.cs
```csharp
using UnrealBuildTool;
using System.Collections.Generic;

public class FinalEvolutionLabTarget : TargetRules
{
    public FinalEvolutionLabTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_4;

        ExtraModuleNames.Add("FinalEvolutionLab");
    }
}
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/FinalEvolutionLab.Build.cs
```csharp
using UnrealBuildTool;

public class FinalEvolutionLab : ModuleRules
{
    public FinalEvolutionLab(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(
            new[]
            {
                "Core",
                "CoreUObject",
                "Engine",
                "InputCore",
                "EnhancedInput",
                "CommonUI",
                "UMG",
                "Json",
                "JsonUtilities"
            }
        );
    }
}
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/FinalEvolutionLab.h
```cpp
#pragma once

#include "CoreMinimal.h"
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Private/ArenaActor.cpp
```cpp
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
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Private/FE_CoachingPortalWidget.cpp
```cpp
#include "FE_CoachingPortalWidget.h"

#include "FE_GameInstance.h"

void UFE_CoachingPortalWidget::RefreshFromGameInstance()
{
    UFE_GameInstance* GI = GetWorld() ? GetWorld()->GetGameInstance<UFE_GameInstance>() : nullptr;
    if (GI == nullptr)
    {
        return;
    }

    DisplayShards = GI->EvolutionShards;
    DisplayPRQ = GI->PRQScore;
    DisplayAttributes = GI->PlayerAttributes;
    OnPortalStateUpdated();
}

bool UFE_CoachingPortalWidget::SpendShardsFromPortal(int32 Amount)
{
    UFE_GameInstance* GI = GetWorld() ? GetWorld()->GetGameInstance<UFE_GameInstance>() : nullptr;
    if (GI == nullptr)
    {
        return false;
    }

    const bool bSpent = GI->SpendShards(Amount);
    if (bSpent)
    {
        GI->SavePlayerState();
    }

    RefreshFromGameInstance();
    return bSpent;
}

void UFE_CoachingPortalWidget::ApplySessionReward(int32 ShardReward, float PRQDelta)
{
    UFE_GameInstance* GI = GetWorld() ? GetWorld()->GetGameInstance<UFE_GameInstance>() : nullptr;
    if (GI == nullptr)
    {
        return;
    }

    GI->EvolutionShards = FMath::Max(0, GI->EvolutionShards + ShardReward);
    GI->PRQScore = FMath::Clamp(GI->PRQScore + PRQDelta, 0.0f, 100.0f);
    GI->SavePlayerState();
    RefreshFromGameInstance();
}
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Private/FE_GameInstance.cpp
```cpp
#include "FE_GameInstance.h"

#include "FE_SaveGame.h"
#include "Kismet/GameplayStatics.h"

UFE_GameInstance::UFE_GameInstance()
    : EvolutionShards(0)
    , PRQScore(50.0f)
    , StreakDays(0)
    , PlayerAttributes()
{
}

bool UFE_GameInstance::SpendShards(int32 Amount)
{
    if (Amount <= 0)
    {
        return false;
    }

    if (EvolutionShards >= Amount)
    {
        EvolutionShards -= Amount;
        return true;
    }
    return false;
}

bool UFE_GameInstance::SavePlayerState()
{
    UFE_SaveGame* SaveObject = Cast<UFE_SaveGame>(UGameplayStatics::CreateSaveGameObject(UFE_SaveGame::StaticClass()));
    if (SaveObject == nullptr)
    {
        return false;
    }

    SaveObject->SavedShards = EvolutionShards;
    SaveObject->SavedPRQ = PRQScore;
    SaveObject->SavedAttributes = PlayerAttributes;

    return UGameplayStatics::SaveGameToSlot(SaveObject, SaveSlotName, SaveUserIndex);
}

bool UFE_GameInstance::LoadPlayerState()
{
    if (!UGameplayStatics::DoesSaveGameExist(SaveSlotName, SaveUserIndex))
    {
        return false;
    }

    UFE_SaveGame* SaveObject = Cast<UFE_SaveGame>(UGameplayStatics::LoadGameFromSlot(SaveSlotName, SaveUserIndex));
    if (SaveObject == nullptr)
    {
        return false;
    }

    EvolutionShards = SaveObject->SavedShards;
    PRQScore = SaveObject->SavedPRQ;
    PlayerAttributes = SaveObject->SavedAttributes;
    return true;
}
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Private/FE_LabManager.cpp
```cpp
#include "FE_LabManager.h"

#include "ArenaActor.h"
#include "EngineUtils.h"
#include "FE_GameInstance.h"

AFE_LabManager::AFE_LabManager()
{
    PrimaryActorTick.bCanEverTick = false;
}

void AFE_LabManager::BeginPlay()
{
    Super::BeginPlay();

    SyncFromGameInstance();

    if (bApplyArenaThemeOnBeginPlay)
    {
        SetGameMode(CurrentMode);
    }
}

void AFE_LabManager::SetGameMode(EGameModeId NewMode)
{
    CurrentMode = NewMode;

    if (ArenaActor == nullptr)
    {
        UWorld* World = GetWorld();
        if (IsValid(World))
        {
            for (TActorIterator<AArenaActor> It(World); It; ++It)
            {
                ArenaActor = *It;
                break;
            }
        }
    }

    if (ArenaActor != nullptr)
    {
        ArenaActor->ApplyTheme(CurrentMode);
    }
}

void AFE_LabManager::StartLabSession()
{
    SyncFromGameInstance();
    SetGameMode(CurrentMode);
}

void AFE_LabManager::SyncFromGameInstance()
{
    UFE_GameInstance* GI = Cast<UFE_GameInstance>(GetGameInstance());
    if (GI == nullptr)
    {
        return;
    }

    CurrentShards = GI->EvolutionShards;
    CurrentPRQ = GI->PRQScore;
    CurrentAttributes = GI->PlayerAttributes;
}
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Private/FinalEvolutionLab.cpp
```cpp
#include "Modules/ModuleManager.h"

IMPLEMENT_PRIMARY_GAME_MODULE(FDefaultGameModuleImpl, FinalEvolutionLab, "FinalEvolutionLab");
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Private/IOS/RorkNativeBridgeIOSStub.mm
```objectivec
// RorkNativeBridgeIOSStub.mm
// Unreal iOS bridge stub.
//
// IMPORTANT:
// - Do not define _PostRorkScore here if it is exported by the host iOS app
//   in Swift via @_cdecl("_PostRorkScore").
// - Keeping this as a stub prevents duplicate symbol linker errors.

```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Private/MotionDataReceiverComponent.cpp
```cpp
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
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Private/PlayerScoreManager.cpp
```cpp
#include "PlayerScoreManager.h"

#include "EngineUtils.h"

TWeakObjectPtr<APlayerScoreManager> APlayerScoreManager::Instance = nullptr;

APlayerScoreManager::APlayerScoreManager()
{
    PrimaryActorTick.bCanEverTick = false;
}

void APlayerScoreManager::BeginPlay()
{
    Super::BeginPlay();

    if (Instance.IsValid() && Instance.Get() != this)
    {
        UE_LOG(LogTemp, Warning, TEXT("[PlayerScoreManager] Duplicate manager found. Destroying duplicate."));
        Destroy();
        return;
    }

    Instance = this;
}

void APlayerScoreManager::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (Instance.Get() == this)
    {
        Instance = nullptr;
    }

    Super::EndPlay(EndPlayReason);
}

int32 APlayerScoreManager::GetPlayerScore() const
{
    return Score;
}

void APlayerScoreManager::UpdatePlayerScore(int32 NewScore)
{
    Score = NewScore;
    UE_LOG(LogTemp, Log, TEXT("[PlayerScoreManager] Local score updated: %d"), Score);
    OnPlayerScoreUpdated.Broadcast(Score);
}

APlayerScoreManager* APlayerScoreManager::Get(UObject* WorldContextObject)
{
    if (Instance.IsValid())
    {
        return Instance.Get();
    }

    if (!IsValid(WorldContextObject))
    {
        return nullptr;
    }

    UWorld* World = WorldContextObject->GetWorld();
    if (!IsValid(World))
    {
        return nullptr;
    }

    for (TActorIterator<APlayerScoreManager> It(World); It; ++It)
    {
        Instance = *It;
        return *It;
    }

    return nullptr;
}
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Private/RorkBridgeRoutingLibrary.cpp
```cpp
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
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Private/RorkNativeBridgeComponent.cpp
```cpp
#include "RorkNativeBridgeComponent.h"

#include "PlayerScoreManager.h"

#if PLATFORM_IOS && !WITH_EDITOR
extern "C" void _PostRorkScore(int32 Score);
#endif

URorkNativeBridgeComponent::URorkNativeBridgeComponent()
{
    PrimaryComponentTick.bCanEverTick = false;
}

void URorkNativeBridgeComponent::BeginPlay()
{
    Super::BeginPlay();
    UpdateInternalPRQDisplayPublic();
    UE_LOG(LogTemp, Log, TEXT("[RorkNativeBridge] Initialized."));
}

void URorkNativeBridgeComponent::PostRorkScoreToNative(int32 Score)
{
    UE_LOG(LogTemp, Log, TEXT("[RorkNativeBridge] Sending PRQ score %d to native iOS."), Score);

    CurrentInternalPrq = Score;
    OnInternalPrqUpdated.Broadcast(CurrentInternalPrq);

#if PLATFORM_IOS && !WITH_EDITOR
    _PostRorkScore(Score);
#else
    UE_LOG(LogTemp, Warning, TEXT("[RorkNativeBridge] _PostRorkScore outside iOS build. Simulating callback."));
    OnRorkScoreUpdated(Score);
#endif
}

void URorkNativeBridgeComponent::OnRorkScoreUpdated(int32 Score)
{
    UE_LOG(LogTemp, Log, TEXT("[RorkNativeBridge] Received PRQ score from native: %d"), Score);
    OnNativePrqUpdated.Broadcast(Score);
}

void URorkNativeBridgeComponent::UpdateInternalPRQDisplayPublic()
{
    if (APlayerScoreManager* ScoreManager = APlayerScoreManager::Get(this))
    {
        CurrentInternalPrq = ScoreManager->GetPlayerScore();
    }

    OnInternalPrqUpdated.Broadcast(CurrentInternalPrq);
}

void URorkNativeBridgeComponent::UpdateUnityPRQDisplayPublic()
{
    UpdateInternalPRQDisplayPublic();
}
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Private/RorkPlayerCharacter.cpp
```cpp
#include "RorkPlayerCharacter.h"

#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "EngineUtils.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "InputAction.h"
#include "InputMappingContext.h"
#include "PlayerScoreManager.h"
#include "RorkNativeBridgeComponent.h"

ARorkPlayerCharacter::ARorkPlayerCharacter()
{
    PrimaryActorTick.bCanEverTick = false;
}

void ARorkPlayerCharacter::BeginPlay()
{
    Super::BeginPlay();

    GetCharacterMovement()->MaxWalkSpeed = MoveSpeed;
    CacheBridgeAndScoreManager();

    if (APlayerController* PC = Cast<APlayerController>(GetController()))
    {
        if (ULocalPlayer* LocalPlayer = PC->GetLocalPlayer())
        {
            if (UEnhancedInputLocalPlayerSubsystem* Subsystem = LocalPlayer->GetSubsystem<UEnhancedInputLocalPlayerSubsystem>())
            {
                if (GameplayMappingContext != nullptr)
                {
                    Subsystem->AddMappingContext(GameplayMappingContext, 0);
                }
            }
        }
    }
}

void ARorkPlayerCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
    Super::SetupPlayerInputComponent(PlayerInputComponent);

    UEnhancedInputComponent* EnhancedInput = Cast<UEnhancedInputComponent>(PlayerInputComponent);
    if (EnhancedInput == nullptr)
    {
        UE_LOG(LogTemp, Error, TEXT("[RorkPlayerCharacter] Missing EnhancedInputComponent."));
        return;
    }

    if (MoveAction != nullptr)
    {
        EnhancedInput->BindAction(MoveAction, ETriggerEvent::Triggered, this, &ARorkPlayerCharacter::Move);
    }

    if (DunkAction != nullptr)
    {
        EnhancedInput->BindAction(DunkAction, ETriggerEvent::Started, this, &ARorkPlayerCharacter::Dunk);
    }
}

void ARorkPlayerCharacter::Move(const FInputActionValue& Value)
{
    const FVector2D MoveInput = Value.Get<FVector2D>();
    if (Controller == nullptr)
    {
        return;
    }

    const FRotator ControlRotation = Controller->GetControlRotation();
    const FRotator YawRotation(0.f, ControlRotation.Yaw, 0.f);

    const FVector ForwardDirection = FRotationMatrix(YawRotation).GetUnitAxis(EAxis::X);
    const FVector RightDirection = FRotationMatrix(YawRotation).GetUnitAxis(EAxis::Y);

    AddMovementInput(ForwardDirection, MoveInput.Y);
    AddMovementInput(RightDirection, MoveInput.X);
}

void ARorkPlayerCharacter::Dunk(const FInputActionValue& Value)
{
    UE_UNUSED(Value);

    UE_LOG(LogTemp, Log, TEXT("[RorkPlayerCharacter] Dunk action performed."));
    LaunchCharacter(FVector(0.f, 0.f, DunkImpulse), false, true);

    CacheBridgeAndScoreManager();
    if (PlayerScoreManager == nullptr)
    {
        UE_LOG(LogTemp, Error, TEXT("[RorkPlayerCharacter] PlayerScoreManager not found."));
        return;
    }

    const int32 CurrentScore = PlayerScoreManager->GetPlayerScore();
    const int32 NewScore = CurrentScore + DunkScoreIncrement;
    PlayerScoreManager->UpdatePlayerScore(NewScore); // Local score first.

    if (RorkBridge != nullptr)
    {
        RorkBridge->PostRorkScoreToNative(NewScore); // Then post to native.
        UE_LOG(LogTemp, Log, TEXT("[RorkPlayerCharacter] Posted score %d to native."), NewScore);
    }
    else
    {
        UE_LOG(LogTemp, Error, TEXT("[RorkPlayerCharacter] RorkNativeBridgeComponent not found."));
    }
}

void ARorkPlayerCharacter::CacheBridgeAndScoreManager()
{
    if (RorkBridge == nullptr)
    {
        RorkBridge = FindComponentByClass<URorkNativeBridgeComponent>();

        if (RorkBridge == nullptr)
        {
            UWorld* World = GetWorld();
            if (IsValid(World))
            {
                for (TActorIterator<AActor> It(World); It; ++It)
                {
                    if (URorkNativeBridgeComponent* Candidate = It->FindComponentByClass<URorkNativeBridgeComponent>())
                    {
                        RorkBridge = Candidate;
                        break;
                    }
                }
            }
        }
    }

    if (PlayerScoreManager == nullptr)
    {
        PlayerScoreManager = APlayerScoreManager::Get(this);
    }
}
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Public/ArenaActor.h
```cpp
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
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Public/FE_CoachingPortalWidget.h
```cpp
#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FinalEvolutionTypes.h"
#include "FE_CoachingPortalWidget.generated.h"

UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API UFE_CoachingPortalWidget : public UUserWidget
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintCallable, Category = "Portal")
    void RefreshFromGameInstance();

    UFUNCTION(BlueprintCallable, Category = "Portal")
    bool SpendShardsFromPortal(int32 Amount);

    UFUNCTION(BlueprintCallable, Category = "Portal")
    void ApplySessionReward(int32 ShardReward, float PRQDelta);

    UPROPERTY(BlueprintReadOnly, Category = "Portal")
    int32 DisplayShards = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Portal")
    float DisplayPRQ = 50.0f;

    UPROPERTY(BlueprintReadOnly, Category = "Portal")
    FGameAttributes DisplayAttributes;

    UFUNCTION(BlueprintImplementableEvent, Category = "Portal")
    void OnPortalStateUpdated();
};
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Public/FE_GameInstance.h
```cpp
#pragma once

#include "CoreMinimal.h"
#include "Engine/GameInstance.h"
#include "FinalEvolutionTypes.h"
#include "FE_GameInstance.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFE_GameInstance : public UGameInstance
{
    GENERATED_BODY()

public:
    UFE_GameInstance();

    UPROPERTY(BlueprintReadWrite, Category = "Player State")
    int32 EvolutionShards;

    UPROPERTY(BlueprintReadWrite, Category = "Player State")
    float PRQScore;

    UPROPERTY(BlueprintReadWrite, Category = "Player State")
    int32 StreakDays;

    UPROPERTY(BlueprintReadWrite, Category = "Attributes")
    FGameAttributes PlayerAttributes;

    UFUNCTION(BlueprintCallable, Category = "Economy")
    bool SpendShards(int32 Amount);

    UFUNCTION(BlueprintCallable, Category = "Save")
    bool SavePlayerState();

    UFUNCTION(BlueprintCallable, Category = "Save")
    bool LoadPlayerState();

private:
    UPROPERTY(EditDefaultsOnly, Category = "Save")
    FString SaveSlotName = TEXT("FinalEvolution_PlayerState");

    UPROPERTY(EditDefaultsOnly, Category = "Save")
    int32 SaveUserIndex = 0;
};
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Public/FE_LabManager.h
```cpp
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FinalEvolutionTypes.h"
#include "FE_LabManager.generated.h"

class AArenaActor;

UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API AFE_LabManager : public AActor
{
    GENERATED_BODY()

public:
    AFE_LabManager();

    UFUNCTION(BlueprintCallable, Category = "Lab")
    void SetGameMode(EGameModeId NewMode);

    UFUNCTION(BlueprintCallable, Category = "Lab")
    void StartLabSession();

    UFUNCTION(BlueprintCallable, Category = "Lab")
    void SyncFromGameInstance();

    UPROPERTY(BlueprintReadOnly, Category = "Lab")
    EGameModeId CurrentMode = EGameModeId::BASKETBALL_HEAD_TO_HEAD;

    UPROPERTY(BlueprintReadOnly, Category = "Lab")
    int32 CurrentShards = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Lab")
    float CurrentPRQ = 50.0f;

    UPROPERTY(BlueprintReadOnly, Category = "Lab")
    FGameAttributes CurrentAttributes;

protected:
    virtual void BeginPlay() override;

private:
    UPROPERTY(EditAnywhere, Category = "Lab")
    bool bApplyArenaThemeOnBeginPlay = true;

    UPROPERTY(EditAnywhere, Category = "Lab")
    TObjectPtr<AArenaActor> ArenaActor;
};
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Public/FE_SaveGame.h
```cpp
#pragma once

#include "GameFramework/SaveGame.h"
#include "FinalEvolutionTypes.h"
#include "FE_SaveGame.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFE_SaveGame : public USaveGame
{
    GENERATED_BODY()

public:
    UPROPERTY()
    int32 SavedShards;

    UPROPERTY()
    float SavedPRQ;

    UPROPERTY()
    FGameAttributes SavedAttributes;
};
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Public/FinalEvolutionTypes.h
```cpp
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
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Public/MotionDataReceiverComponent.h
```cpp
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
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Public/PlayerScoreManager.h
```cpp
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "PlayerScoreManager.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnPlayerScoreUpdated, int32, NewScore);

UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API APlayerScoreManager : public AActor
{
    GENERATED_BODY()

public:
    APlayerScoreManager();

    UFUNCTION(BlueprintPure, Category = "Rork|Score")
    int32 GetPlayerScore() const;

    UFUNCTION(BlueprintCallable, Category = "Rork|Score")
    void UpdatePlayerScore(int32 NewScore);

    UFUNCTION(BlueprintPure, Category = "Rork|Score")
    static APlayerScoreManager* Get(UObject* WorldContextObject);

    UPROPERTY(BlueprintAssignable, Category = "Rork|Score")
    FOnPlayerScoreUpdated OnPlayerScoreUpdated;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

private:
    UPROPERTY(EditAnywhere, Category = "Rork|Score")
    int32 Score = 0;

    static TWeakObjectPtr<APlayerScoreManager> Instance;
};
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Public/RorkBridgeRoutingLibrary.h
```cpp
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
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Public/RorkNativeBridgeComponent.h
```cpp
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "RorkNativeBridgeComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnInternalPrqUpdated, int32, Score);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnNativePrqUpdated, int32, Score);

UCLASS(ClassGroup=(Rork), BlueprintType, Blueprintable, meta=(BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API URorkNativeBridgeComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    URorkNativeBridgeComponent();

    UFUNCTION(BlueprintCallable, Category = "Rork|Bridge")
    void PostRorkScoreToNative(int32 Score);

    UFUNCTION(BlueprintCallable, Category = "Rork|Bridge")
    void OnRorkScoreUpdated(int32 Score);

    UFUNCTION(BlueprintCallable, Category = "Rork|Bridge")
    void UpdateInternalPRQDisplayPublic();

    // Legacy alias kept for parity with prior Unity-facing naming.
    UFUNCTION(BlueprintCallable, Category = "Rork|Bridge")
    void UpdateUnityPRQDisplayPublic();

    UFUNCTION(BlueprintPure, Category = "Rork|Bridge")
    int32 GetCurrentInternalPrq() const { return CurrentInternalPrq; }

    UPROPERTY(BlueprintAssignable, Category = "Rork|Bridge")
    FOnInternalPrqUpdated OnInternalPrqUpdated;

    UPROPERTY(BlueprintAssignable, Category = "Rork|Bridge")
    FOnNativePrqUpdated OnNativePrqUpdated;

protected:
    virtual void BeginPlay() override;

private:
    UPROPERTY(VisibleAnywhere, Category = "Rork|Bridge")
    int32 CurrentInternalPrq = 0;
};
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLab/Public/RorkPlayerCharacter.h
```cpp
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
```

## FinalEvolutionLab_Unreal/Source/FinalEvolutionLabEditor.Target.cs
```csharp
using UnrealBuildTool;
using System.Collections.Generic;

public class FinalEvolutionLabEditorTarget : TargetRules
{
    public FinalEvolutionLabEditorTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Editor;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_4;

        ExtraModuleNames.Add("FinalEvolutionLab");
    }
}
```

---
Included files: 32

Skipped files: 0
