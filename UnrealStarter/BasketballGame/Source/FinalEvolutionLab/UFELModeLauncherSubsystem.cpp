// Copyright (c) Final Evolution Lab.

#include "UFELModeLauncherSubsystem.h"
#include "FELArenaModeDefinitions.h"
#include "FELArenaRulesRegistry.h"
#include "FELPlatformPaths.h"
#include "FinalEvolutionLab.h"
#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"
#include "Misc/FileHelper.h"
#include "Serialization/JsonWriter.h"
#include "Serialization/JsonSerializer.h"
#include "Dom/JsonObject.h"
#include "Dom/JsonValue.h"

void UFELModeLauncherSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	UE_LOG(LogFinalEvolutionLab, Log, TEXT("ModeLauncherSubsystem initialized — 16 modes available."));
}

void UFELModeLauncherSubsystem::Deinitialize()
{
	Super::Deinitialize();
}

bool UFELModeLauncherSubsystem::LaunchModeByKey(const FString& ModeKey)
{
	const EFELArenaMode Mode = FELArenaModeFromIdString(ModeKey);
	if (Mode == EFELArenaMode::Unknown)
	{
		UE_LOG(LogFinalEvolutionLab, Warning, TEXT("LaunchModeByKey: unknown mode key '%s'"), *ModeKey);
		return false;
	}
	return LaunchMode(Mode);
}

bool UFELModeLauncherSubsystem::LaunchMode(EFELArenaMode Mode)
{
	if (Mode == EFELArenaMode::Unknown) return false;

	const FString ModeKey = FELArenaModeToIdString(Mode);
	UE_LOG(LogFinalEvolutionLab, Log, TEXT("LaunchMode: %s (%d)"), *ModeKey, static_cast<int32>(Mode));

	// Write readiness snapshot so GameMode picks up the active_mode
	WriteReadinessSnapshot(ModeKey);

	// Resolve venue from ArenaSettings.json
	FFELArenaRules Rules;
	FELArenaRulesRegistry::GetFactoryDefaultRules(Mode, Rules);

	CurrentActiveMode = Mode;
	bModeActive = true;

	// Travel to the venue level
	if (!Rules.UnrealOpenLevelPackage.IsEmpty())
	{
		TravelToVenue(Rules.UnrealOpenLevelPackage);
	}

	OnModeLaunched.Broadcast(Mode, ModeKey);
	return true;
}

void UFELModeLauncherSubsystem::ExitCurrentMode()
{
	if (!bModeActive) return;

	const EFELArenaMode Prev = CurrentActiveMode;
	CurrentActiveMode = EFELArenaMode::Unknown;
	bModeActive = false;

	OnModeExited.Broadcast(Prev);

	// Travel back to the main menu / lobby level
	if (UWorld* W = GetWorld())
	{
		UGameplayStatics::OpenLevel(W, TEXT("MainMenu"), true);
	}
}

TArray<FString> UFELModeLauncherSubsystem::GetAllAvailableModeKeys() const
{
	TArray<FString> Keys;
	Keys.Add(FELArenaModeIds::BasketballHeadToHead);
	Keys.Add(FELArenaModeIds::BasketballDunk);
	Keys.Add(FELArenaModeIds::Basketball3v3);
	Keys.Add(FELArenaModeIds::KarateHeadToHead);
	Keys.Add(FELArenaModeIds::KarateEndless);
	Keys.Add(FELArenaModeIds::Baseball);
	Keys.Add(FELArenaModeIds::Football);
	Keys.Add(FELArenaModeIds::Soccer);
	Keys.Add(FELArenaModeIds::Golf);
	Keys.Add(FELArenaModeIds::Tennis);
	Keys.Add(FELArenaModeIds::Volleyball);
	Keys.Add(FELArenaModeIds::Gymnastics);
	Keys.Add(FELArenaModeIds::BrainBrawl);
	Keys.Add(FELArenaModeIds::Surfing);
	Keys.Add(FELArenaModeIds::Skateboarding);
	Keys.Add(FELArenaModeIds::Snowboarding);
	Keys.Add(FELArenaModeIds::MarketBrowse);
	return Keys;
}

FString UFELModeLauncherSubsystem::GetModeManifestJSON() const
{
	TSharedRef<FJsonObject> Root = MakeShared<FJsonObject>();
	TArray<TSharedPtr<FJsonValue>> ModesArray;

	const TArray<FString> Keys = GetAllAvailableModeKeys();
	for (const FString& Key : Keys)
	{
		const EFELArenaMode Mode = FELArenaModeFromIdString(Key);
		FFELArenaRules Rules;
		FELArenaRulesRegistry::GetFactoryDefaultRules(Mode, Rules);

		TSharedRef<FJsonObject> ModeObj = MakeShared<FJsonObject>();
		ModeObj->SetStringField(TEXT("id"), Key);
		ModeObj->SetStringField(TEXT("displayName"), Rules.ModeDisplayName);
		ModeObj->SetStringField(TEXT("venue"), Rules.UnrealOpenLevelPackage);
		ModeObj->SetBoolField(TEXT("scoringEnabled"), Rules.bScoringEnabled);
		ModeObj->SetNumberField(TEXT("targetScore"), Rules.TargetScore);
		ModeObj->SetNumberField(TEXT("timeLimitSeconds"), Rules.TimeLimitSeconds);

		ModesArray.Add(MakeShared<FJsonValueObject>(ModeObj));
	}

	Root->SetArrayField(TEXT("modes"), ModesArray);

	FString Output;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&Output);
	FJsonSerializer::Serialize(Root, Writer);
	return Output;
}

void UFELModeLauncherSubsystem::WriteReadinessSnapshot(const FString& ModeKey)
{
	const FString Path = FELPlatformPaths::ReadinessSnapshotPath();

	TSharedRef<FJsonObject> Snap = MakeShared<FJsonObject>();
	Snap->SetStringField(TEXT("active_mode"), ModeKey);
	Snap->SetNumberField(TEXT("prq"), 75.0);
	Snap->SetNumberField(TEXT("vertical_estimate_inches"), 32.0);
	Snap->SetNumberField(TEXT("kinetic_leakage_multiplier"), 1.0);

	FString Json;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&Json);
	FJsonSerializer::Serialize(Snap, Writer);

	FFileHelper::SaveStringToFile(Json, *Path);
}

void UFELModeLauncherSubsystem::TravelToVenue(const FString& LevelPackage)
{
	if (UWorld* W = GetWorld())
	{
		// Extract level name from package path for OpenLevel
		FString LevelName = LevelPackage;
		int32 DotIdx;
		if (LevelName.FindLastChar('.', DotIdx))
		{
			LevelName = LevelName.Left(DotIdx);
		}
		UGameplayStatics::OpenLevel(W, *LevelName, true);
	}
}
