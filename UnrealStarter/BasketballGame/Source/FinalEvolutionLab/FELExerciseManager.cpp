// Copyright (c) Final Evolution Lab.
// Exercise Manager implementation.

#include "FELExerciseManager.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Animation/AnimMontage.h"
#include "Kismet/GameplayStatics.h"

DEFINE_LOG_CATEGORY_STATIC(LogFELExercise, Log, All);

/* ─────────────────────────  LIFECYCLE  ───────────────────────────── */

void UFELExerciseManager::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	LoadExerciseDatabase();
	LoadProgressFromSave();
	UE_LOG(LogFELExercise, Log, TEXT("ExerciseManager: loaded %d exercises, %d progress records."),
		ExerciseDB.Num(), ProgressMap.Num());
}

void UFELExerciseManager::Deinitialize()
{
	SaveProgressToSave();
	Super::Deinitialize();
}

/* ─────────────────────────  DATABASE LOAD  ───────────────────────── */

static EExerciseCategory ParseCategory(const FString& S)
{
	if (S == TEXT("warmup"))        return EExerciseCategory::WarmUp;
	if (S == TEXT("strength"))      return EExerciseCategory::Strength;
	if (S == TEXT("mobility"))      return EExerciseCategory::Mobility;
	if (S == TEXT("plyometrics"))   return EExerciseCategory::Plyometrics;
	if (S == TEXT("recovery"))      return EExerciseCategory::Recovery;
	// fallback for sport_specific -> Plyometrics
	if (S == TEXT("sport_specific")) return EExerciseCategory::Plyometrics;
	return EExerciseCategory::WarmUp;
}

static EExerciseDifficulty DifficultyFromFloat(float D)
{
	if (D <= 0.25f) return EExerciseDifficulty::Beginner;
	if (D <= 0.50f) return EExerciseDifficulty::Intermediate;
	if (D <= 0.75f) return EExerciseDifficulty::Advanced;
	return EExerciseDifficulty::Elite;
}

void UFELExerciseManager::LoadExerciseDatabase()
{
	FString JsonPath = FPaths::ProjectContentDir() / TEXT("FEL/Config/ExerciseCatalog.json");
	FString JsonStr;
	if (!FFileHelper::LoadFileToString(JsonStr, *JsonPath))
	{
		UE_LOG(LogFELExercise, Warning, TEXT("ExerciseManager: cannot read %s"), *JsonPath);
		return;
	}

	TSharedPtr<FJsonObject> Root;
	if (!FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(JsonStr), Root) || !Root.IsValid())
	{
		UE_LOG(LogFELExercise, Error, TEXT("ExerciseManager: JSON parse failed."));
		return;
	}

	const TArray<TSharedPtr<FJsonValue>>* Categories;
	if (!Root->TryGetArrayField(TEXT("categories"), Categories)) return;

	for (auto& CatVal : *Categories)
	{
		const TSharedPtr<FJsonObject>& CatObj = CatVal->AsObject();
		FString CatID;
		CatObj->TryGetStringField(TEXT("id"), CatID);

		const TArray<TSharedPtr<FJsonValue>>* Exercises;
		if (!CatObj->TryGetArrayField(TEXT("exercises"), Exercises)) continue;

		for (auto& ExVal : *Exercises)
		{
			const TSharedPtr<FJsonObject>& ExObj = ExVal->AsObject();
			FExerciseData Data;
			ExObj->TryGetStringField(TEXT("id"), Data.ExerciseID);
			ExObj->TryGetStringField(TEXT("name"), Data.DisplayName);
			ExObj->TryGetStringField(TEXT("description"), Data.Description);
			Data.Category = ParseCategory(CatID);

			double Diff = 0.5;
			ExObj->TryGetNumberField(TEXT("difficulty"), Diff);
			Data.Difficulty = DifficultyFromFloat((float)Diff);

			FString Montage;
			if (ExObj->TryGetStringField(TEXT("animMontage"), Montage))
				Data.AnimationPaths.Add(Montage);

			int32 Tmp = 0;
			if (ExObj->TryGetNumberField(TEXT("sets"), Diff)) Data.DefaultSets = (int32)Diff;
			if (ExObj->TryGetNumberField(TEXT("reps"), Diff)) Data.DefaultReps = (int32)Diff;
			if (ExObj->TryGetNumberField(TEXT("duration_seconds"), Diff)) Data.DefaultDuration = (float)Diff;

			const TArray<TSharedPtr<FJsonValue>>* Arr;
			if (ExObj->TryGetArrayField(TEXT("targetMuscles"), Arr))
				for (auto& V : *Arr) Data.MuscleGroups.Add(V->AsString());

			if (ExObj->TryGetArrayField(TEXT("sportRelevance"), Arr))
				for (auto& V : *Arr) Data.RelevantGameModes.Add(V->AsString());

			if (ExObj->TryGetArrayField(TEXT("equipment"), Arr))
				for (auto& V : *Arr) Data.Equipment.Add(V->AsString());

			ExerciseDB.Add(Data.ExerciseID, Data);
		}
	}
}

void UFELExerciseManager::LoadProgressFromSave()
{
	FString ProgPath = FPaths::ProjectSavedDir() / TEXT("FEL/exercise_progress.json");
	FString JsonStr;
	if (!FFileHelper::LoadFileToString(JsonStr, *ProgPath)) return;

	TSharedPtr<FJsonObject> Root;
	if (!FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(JsonStr), Root) || !Root.IsValid()) return;

	for (auto& Pair : Root->Values)
	{
		FExerciseProgress P;
		P.ExerciseID = Pair.Key;
		const auto& Obj = Pair.Value->AsObject();
		double D;
		if (Obj->TryGetNumberField(TEXT("totalCompletions"), D)) P.TotalCompletions = (int32)D;
		if (Obj->TryGetNumberField(TEXT("totalCalories"), D)) P.TotalCaloriesBurned = (float)D;
		if (Obj->TryGetNumberField(TEXT("totalMinutes"), D)) P.TotalDurationMinutes = (float)D;
		ProgressMap.Add(P.ExerciseID, P);
	}
}

void UFELExerciseManager::SaveProgressToSave()
{
	TSharedPtr<FJsonObject> Root = MakeShared<FJsonObject>();
	for (auto& Pair : ProgressMap)
	{
		TSharedPtr<FJsonObject> Obj = MakeShared<FJsonObject>();
		Obj->SetNumberField(TEXT("totalCompletions"), Pair.Value.TotalCompletions);
		Obj->SetNumberField(TEXT("totalCalories"), Pair.Value.TotalCaloriesBurned);
		Obj->SetNumberField(TEXT("totalMinutes"), Pair.Value.TotalDurationMinutes);
		Root->SetObjectField(Pair.Key, Obj);
	}

	FString Out;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&Out);
	FJsonSerializer::Serialize(Root.ToSharedRef(), Writer);

	FString ProgPath = FPaths::ProjectSavedDir() / TEXT("FEL/exercise_progress.json");
	FFileHelper::SaveStringToFile(Out, *ProgPath);
}

/* ─────────────────────────  QUERIES  ─────────────────────────────── */

TArray<FExerciseData> UFELExerciseManager::GetAllExercises() const
{
	TArray<FExerciseData> Result;
	ExerciseDB.GenerateValueArray(Result);
	return Result;
}

TArray<FExerciseData> UFELExerciseManager::GetExercisesByCategory(EExerciseCategory Category) const
{
	TArray<FExerciseData> Result;
	for (auto& Pair : ExerciseDB)
		if (Pair.Value.Category == Category)
			Result.Add(Pair.Value);
	return Result;
}

TArray<FExerciseData> UFELExerciseManager::GetExercisesByDifficulty(EExerciseDifficulty Difficulty) const
{
	TArray<FExerciseData> Result;
	for (auto& Pair : ExerciseDB)
		if (Pair.Value.Difficulty == Difficulty)
			Result.Add(Pair.Value);
	return Result;
}

bool UFELExerciseManager::GetExerciseByID(const FString& ExerciseID, FExerciseData& OutExercise) const
{
	const FExerciseData* Found = ExerciseDB.Find(ExerciseID);
	if (Found)
	{
		OutExercise = *Found;
		return true;
	}
	return false;
}

TArray<FExerciseData> UFELExerciseManager::GetExercisesForGameMode(const FString& GameModeID) const
{
	TArray<FExerciseData> Result;
	for (auto& Pair : ExerciseDB)
		if (Pair.Value.RelevantGameModes.Contains(GameModeID))
			Result.Add(Pair.Value);
	return Result;
}

TArray<FExerciseData> UFELExerciseManager::SearchExercises(const FString& Query) const
{
	TArray<FExerciseData> Result;
	FString Q = Query.ToLower();
	for (auto& Pair : ExerciseDB)
	{
		if (Pair.Value.DisplayName.ToLower().Contains(Q) ||
			Pair.Value.Description.ToLower().Contains(Q) ||
			Pair.Value.ExerciseID.ToLower().Contains(Q))
		{
			Result.Add(Pair.Value);
		}
	}
	return Result;
}

/* ─────────────────────────  ANIMATION  ───────────────────────────── */

UAnimMontage* UFELExerciseManager::LoadExerciseAnimation(const FString& ExerciseID, int32 VariantIndex)
{
	FString CacheKey = FString::Printf(TEXT("%s_%d"), *ExerciseID, VariantIndex);
	if (UAnimMontage** Cached = AnimCache.Find(CacheKey))
		return *Cached;

	const FExerciseData* Data = ExerciseDB.Find(ExerciseID);
	if (!Data || !Data->AnimationPaths.IsValidIndex(VariantIndex))
		return nullptr;

	UAnimMontage* Montage = Cast<UAnimMontage>(
		StaticLoadObject(UAnimMontage::StaticClass(), nullptr, *Data->AnimationPaths[VariantIndex]));

	if (Montage)
		AnimCache.Add(CacheKey, Montage);

	return Montage;
}

/* ─────────────────────────  PROGRESS  ────────────────────────────── */

void UFELExerciseManager::RecordExerciseCompletion(const FString& ExerciseID, int32 Reps, float Weight, float DurationMinutes)
{
	FExerciseProgress& P = ProgressMap.FindOrAdd(ExerciseID);
	P.ExerciseID = ExerciseID;
	P.TotalCompletions++;
	P.TotalDurationMinutes += DurationMinutes;
	P.TotalCaloriesBurned += CalculateCaloriesBurned(ExerciseID, DurationMinutes);
	P.LastCompleted = FDateTime::UtcNow();

	// Update personal record
	if (Reps > P.PersonalRecord.MaxReps)
	{
		P.PersonalRecord.MaxReps = Reps;
		P.PersonalRecord.AchievedDate = FDateTime::UtcNow();
	}
	if (Weight > P.PersonalRecord.MaxWeight)
	{
		P.PersonalRecord.MaxWeight = Weight;
		P.PersonalRecord.AchievedDate = FDateTime::UtcNow();
	}

	SaveProgressToSave();
}

FExerciseProgress UFELExerciseManager::GetExerciseProgress(const FString& ExerciseID) const
{
	const FExerciseProgress* P = ProgressMap.Find(ExerciseID);
	return P ? *P : FExerciseProgress();
}

float UFELExerciseManager::CalculateCaloriesBurned(const FString& ExerciseID, float DurationMinutes) const
{
	const FExerciseData* Data = ExerciseDB.Find(ExerciseID);
	if (!Data) return 0.f;
	return Data->CaloriesPerMinute * DurationMinutes;
}

TArray<FExerciseData> UFELExerciseManager::GetRecommendedExercises(int32 Count) const
{
	// Recommend exercises the user hasn't done recently or hasn't done much
	TArray<FExerciseData> AllEx;
	ExerciseDB.GenerateValueArray(AllEx);

	// Sort by least completions first
	AllEx.Sort([this](const FExerciseData& A, const FExerciseData& B)
	{
		const FExerciseProgress* PA = ProgressMap.Find(A.ExerciseID);
		const FExerciseProgress* PB = ProgressMap.Find(B.ExerciseID);
		int32 CA = PA ? PA->TotalCompletions : 0;
		int32 CB = PB ? PB->TotalCompletions : 0;
		return CA < CB;
	});

	if (AllEx.Num() > Count)
		AllEx.SetNum(Count);

	return AllEx;
}
