// Copyright (c) Final Evolution Lab.

#include "UFELExerciseCatalogSubsystem.h"
#include "FELExerciseDemonstrator.h"
#include "FELPlatformPaths.h"
#include "FinalEvolutionLab.h"
#include "Dom/JsonObject.h"
#include "Dom/JsonValue.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Engine/World.h"
#include "Engine/SkeletalMesh.h"
#include "Animation/AnimMontage.h"
#include "Kismet/GameplayStatics.h"

void UFELExerciseCatalogSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	LoadCatalog();
}

void UFELExerciseCatalogSubsystem::Deinitialize()
{
	StopExerciseDemo();
	Super::Deinitialize();
}

bool UFELExerciseCatalogSubsystem::LoadCatalog()
{
	AllExercises.Empty();
	ExerciseLookup.Empty();

	// Try content directory first, then project config
	FString JsonPath = FPaths::Combine(FPaths::ProjectContentDir(), TEXT("FEL/Config/ExerciseCatalog.json"));
	FString JsonContent;

	if (!FFileHelper::LoadFileToString(JsonContent, *JsonPath))
	{
		// Fallback: embedded path
		JsonPath = FPaths::Combine(FPaths::ProjectDir(), TEXT("Content/FEL/Config/ExerciseCatalog.json"));
		if (!FFileHelper::LoadFileToString(JsonContent, *JsonPath))
		{
			UE_LOG(LogFinalEvolutionLab, Warning, TEXT("ExerciseCatalog: Could not load from '%s'"), *JsonPath);
			return false;
		}
	}

	ParseCatalogJSON(JsonContent);
	UE_LOG(LogFinalEvolutionLab, Log, TEXT("ExerciseCatalog: Loaded %d exercises."), AllExercises.Num());
	return AllExercises.Num() > 0;
}

void UFELExerciseCatalogSubsystem::ParseCatalogJSON(const FString& JsonContent)
{
	TSharedPtr<FJsonObject> Root;
	TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonContent);
	if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid()) return;

	const TArray<TSharedPtr<FJsonValue>>* CategoriesArray;
	if (!Root->TryGetArrayField(TEXT("categories"), CategoriesArray)) return;

	for (const TSharedPtr<FJsonValue>& CatVal : *CategoriesArray)
	{
		const TSharedPtr<FJsonObject>& CatObj = CatVal->AsObject();
		if (!CatObj.IsValid()) continue;

		FString CategoryId;
		CatObj->TryGetStringField(TEXT("id"), CategoryId);
		const EFELExerciseCategory Category = ParseCategoryId(CategoryId);

		const TArray<TSharedPtr<FJsonValue>>* ExercisesArray;
		if (!CatObj->TryGetArrayField(TEXT("exercises"), ExercisesArray)) continue;

		for (const TSharedPtr<FJsonValue>& ExVal : *ExercisesArray)
		{
			const TSharedPtr<FJsonObject>& ExObj = ExVal->AsObject();
			if (!ExObj.IsValid()) continue;

			FFELExerciseDefinition Def;
			ExObj->TryGetStringField(TEXT("id"), Def.ExerciseId);
			ExObj->TryGetStringField(TEXT("name"), Def.DisplayName);
			ExObj->TryGetStringField(TEXT("description"), Def.Description);
			Def.Category = Category;

			int32 IntVal;
			if (ExObj->TryGetNumberField(TEXT("duration_seconds"), IntVal)) Def.DurationSeconds = IntVal;
			if (ExObj->TryGetNumberField(TEXT("reps"), IntVal)) Def.Reps = IntVal;
			if (ExObj->TryGetNumberField(TEXT("sets"), IntVal)) Def.Sets = IntVal;

			double DblVal;
			if (ExObj->TryGetNumberField(TEXT("difficulty"), DblVal)) Def.Difficulty = static_cast<float>(DblVal);

			ExObj->TryGetStringField(TEXT("prqBenefit"), Def.PRQBenefit);

			const TArray<TSharedPtr<FJsonValue>>* MusclesArray;
			if (ExObj->TryGetArrayField(TEXT("targetMuscles"), MusclesArray))
			{
				for (const auto& M : *MusclesArray)
					Def.TargetMuscles.Add(M->AsString());
			}

			const TArray<TSharedPtr<FJsonValue>>* SportArray;
			if (ExObj->TryGetArrayField(TEXT("sportRelevance"), SportArray))
			{
				for (const auto& S : *SportArray)
					Def.SportRelevance.Add(S->AsString());
			}

			FString MontagePath;
			if (ExObj->TryGetStringField(TEXT("animMontage"), MontagePath))
			{
				Def.AnimMontage = TSoftObjectPtr<UAnimMontage>(FSoftObjectPath(MontagePath));
			}

			FString MeshPath;
			if (ExObj->TryGetStringField(TEXT("demonstratorMesh"), MeshPath))
			{
				Def.DemonstratorMesh = TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath(MeshPath));
			}

			AllExercises.Add(Def);
			ExerciseLookup.Add(Def.ExerciseId, Def);
		}
	}
}

EFELExerciseCategory UFELExerciseCatalogSubsystem::ParseCategoryId(const FString& CategoryId) const
{
	if (CategoryId == TEXT("warmup")) return EFELExerciseCategory::WarmUp;
	if (CategoryId == TEXT("strength")) return EFELExerciseCategory::Strength;
	if (CategoryId == TEXT("mobility")) return EFELExerciseCategory::Mobility;
	if (CategoryId == TEXT("sport_specific")) return EFELExerciseCategory::SportSpecific;
	if (CategoryId == TEXT("recovery")) return EFELExerciseCategory::Recovery;
	return EFELExerciseCategory::WarmUp;
}

TArray<FFELExerciseDefinition> UFELExerciseCatalogSubsystem::GetExercisesByCategory(EFELExerciseCategory Category) const
{
	TArray<FFELExerciseDefinition> Result;
	for (const auto& Ex : AllExercises)
	{
		if (Ex.Category == Category)
			Result.Add(Ex);
	}
	return Result;
}

TArray<FFELExerciseDefinition> UFELExerciseCatalogSubsystem::GetExercisesForMode(const FString& ModeKey) const
{
	TArray<FFELExerciseDefinition> Result;
	for (const auto& Ex : AllExercises)
	{
		if (Ex.SportRelevance.Contains(ModeKey))
			Result.Add(Ex);
	}
	return Result;
}

bool UFELExerciseCatalogSubsystem::GetExerciseById(const FString& ExerciseId, FFELExerciseDefinition& OutExercise) const
{
	const FFELExerciseDefinition* Found = ExerciseLookup.Find(ExerciseId);
	if (Found)
	{
		OutExercise = *Found;
		return true;
	}
	return false;
}

FFELExerciseSession UFELExerciseCatalogSubsystem::GenerateWarmUpSession(const FString& ModeKey, float AvailableMinutes) const
{
	FFELExerciseSession Session;
	Session.SessionId = FGuid::NewGuid().ToString();

	const float AvailableSec = AvailableMinutes * 60.f;
	float TotalSec = 0.f;

	// Add warmup exercises relevant to the mode
	TArray<FFELExerciseDefinition> WarmUps = GetExercisesByCategory(EFELExerciseCategory::WarmUp);
	for (const auto& Ex : WarmUps)
	{
		if (Ex.SportRelevance.Contains(ModeKey) || ModeKey.IsEmpty())
		{
			const float ExDuration = Ex.DurationSeconds > 0 ? Ex.DurationSeconds : (Ex.Reps * 3.f * Ex.Sets);
			if (TotalSec + ExDuration <= AvailableSec)
			{
				Session.ExerciseIds.Add(Ex.ExerciseId);
				TotalSec += ExDuration;
			}
		}
	}

	Session.SessionDurationSeconds = TotalSec;
	Session.EstimatedPRQGain = TotalSec * 0.02f; // Rough estimate
	return Session;
}

FFELExerciseSession UFELExerciseCatalogSubsystem::GenerateFullTrainingSession(const FString& ModeKey, float AvailableMinutes) const
{
	FFELExerciseSession Session;
	Session.SessionId = FGuid::NewGuid().ToString();

	const float AvailableSec = AvailableMinutes * 60.f;
	float TotalSec = 0.f;

	// Phase 1: Warm-up (20% of time)
	const float WarmUpBudget = AvailableSec * 0.2f;
	for (const auto& Ex : GetExercisesByCategory(EFELExerciseCategory::WarmUp))
	{
		if (!Ex.SportRelevance.Contains(ModeKey) && !ModeKey.IsEmpty()) continue;
		const float D = Ex.DurationSeconds > 0 ? Ex.DurationSeconds : (Ex.Reps * 3.f * Ex.Sets);
		if (TotalSec + D <= WarmUpBudget) { Session.ExerciseIds.Add(Ex.ExerciseId); TotalSec += D; }
	}

	// Phase 2: Strength (25% of time)
	const float StrengthBudget = TotalSec + AvailableSec * 0.25f;
	for (const auto& Ex : GetExercisesByCategory(EFELExerciseCategory::Strength))
	{
		if (!Ex.SportRelevance.Contains(ModeKey) && !ModeKey.IsEmpty()) continue;
		const float D = Ex.DurationSeconds > 0 ? Ex.DurationSeconds : (Ex.Reps * 3.f * Ex.Sets);
		if (TotalSec + D <= StrengthBudget) { Session.ExerciseIds.Add(Ex.ExerciseId); TotalSec += D; }
	}

	// Phase 3: Sport-specific (35% of time)
	const float SportBudget = TotalSec + AvailableSec * 0.35f;
	for (const auto& Ex : GetExercisesByCategory(EFELExerciseCategory::SportSpecific))
	{
		if (!Ex.SportRelevance.Contains(ModeKey) && !ModeKey.IsEmpty()) continue;
		const float D = Ex.DurationSeconds > 0 ? Ex.DurationSeconds : (Ex.Reps * 3.f * Ex.Sets);
		if (TotalSec + D <= SportBudget) { Session.ExerciseIds.Add(Ex.ExerciseId); TotalSec += D; }
	}

	// Phase 4: Recovery (20% of time)
	const float RecoveryBudget = TotalSec + AvailableSec * 0.2f;
	for (const auto& Ex : GetExercisesByCategory(EFELExerciseCategory::Recovery))
	{
		const float D = Ex.DurationSeconds > 0 ? Ex.DurationSeconds : 45.f;
		if (TotalSec + D <= RecoveryBudget) { Session.ExerciseIds.Add(Ex.ExerciseId); TotalSec += D; }
	}

	Session.SessionDurationSeconds = TotalSec;
	Session.EstimatedPRQGain = TotalSec * 0.03f;
	return Session;
}

bool UFELExerciseCatalogSubsystem::PlayExerciseDemo(const FString& ExerciseId, FVector SpawnLocation, FRotator SpawnRotation)
{
	StopExerciseDemo();

	FFELExerciseDefinition Def;
	if (!GetExerciseById(ExerciseId, Def))
	{
		UE_LOG(LogFinalEvolutionLab, Warning, TEXT("PlayExerciseDemo: exercise '%s' not found in catalog."), *ExerciseId);
		return false;
	}

	UWorld* W = GetWorld();
	if (!W) return false;

	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

	AFELExerciseDemonstrator* Demo = W->SpawnActor<AFELExerciseDemonstrator>(SpawnLocation, SpawnRotation, Params);
	if (!Demo) return false;

	// Load mesh and montage (synchronous for now; async via StreamableManager in production)
	USkeletalMesh* Mesh = Def.DemonstratorMesh.LoadSynchronous();
	UAnimMontage* Montage = Def.AnimMontage.LoadSynchronous();

	if (Mesh)
	{
		Demo->ConfigureDemonstrator(Mesh, nullptr, 1.0f);
	}

	if (Montage)
	{
		Demo->PlayDemonstrationMontage(Montage);
	}

	// Bind completion
	Demo->OnDemonstrationMontageEnded.AddDynamic(this, &UFELExerciseCatalogSubsystem::HandleDemonstrationEnded);

	ActiveDemonstrator = Demo;
	ActiveDemoExerciseId = ExerciseId;

	OnExerciseDemoStarted.Broadcast(ExerciseId);
	UE_LOG(LogFinalEvolutionLab, Log, TEXT("PlayExerciseDemo: started '%s' (%s)"), *ExerciseId, *Def.DisplayName);
	return true;
}

void UFELExerciseCatalogSubsystem::StopExerciseDemo()
{
	if (ActiveDemonstrator.IsValid())
	{
		ActiveDemonstrator->Destroy();
		ActiveDemonstrator = nullptr;
	}
	ActiveDemoExerciseId.Empty();
}

void UFELExerciseCatalogSubsystem::HandleDemonstrationEnded(bool bInterrupted)
{
	const FString CompletedId = ActiveDemoExerciseId;
	OnExerciseDemoCompleted.Broadcast(CompletedId, bInterrupted);

	if (!bInterrupted)
	{
		ActiveDemonstrator = nullptr;
		ActiveDemoExerciseId.Empty();
	}
}

FString UFELExerciseCatalogSubsystem::GetExerciseManifestJSON() const
{
	TSharedRef<FJsonObject> Root = MakeShared<FJsonObject>();
	TArray<TSharedPtr<FJsonValue>> ExArray;

	for (const auto& Ex : AllExercises)
	{
		TSharedRef<FJsonObject> Obj = MakeShared<FJsonObject>();
		Obj->SetStringField(TEXT("id"), Ex.ExerciseId);
		Obj->SetStringField(TEXT("name"), Ex.DisplayName);
		Obj->SetStringField(TEXT("description"), Ex.Description);
		Obj->SetNumberField(TEXT("difficulty"), Ex.Difficulty);
		Obj->SetStringField(TEXT("prqBenefit"), Ex.PRQBenefit);
		Obj->SetNumberField(TEXT("reps"), Ex.Reps);
		Obj->SetNumberField(TEXT("sets"), Ex.Sets);

		TArray<TSharedPtr<FJsonValue>> MuscleArr;
		for (const FString& M : Ex.TargetMuscles)
			MuscleArr.Add(MakeShared<FJsonValueString>(M));
		Obj->SetArrayField(TEXT("targetMuscles"), MuscleArr);

		TArray<TSharedPtr<FJsonValue>> SportArr;
		for (const FString& S : Ex.SportRelevance)
			SportArr.Add(MakeShared<FJsonValueString>(S));
		Obj->SetArrayField(TEXT("sportRelevance"), SportArr);

		ExArray.Add(MakeShared<FJsonValueObject>(Obj));
	}

	Root->SetArrayField(TEXT("exercises"), ExArray);

	FString Output;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&Output);
	FJsonSerializer::Serialize(Root, Writer);
	return Output;
}
