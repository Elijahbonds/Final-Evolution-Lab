// UFELAIAssetManagerSubsystem.cpp
#include "UFELAIAssetManagerSubsystem.h"
#include "FELGeneratedAssetPaths.h"
#include "FELPlatformPaths.h"
#include "FinalEvolutionLab.h"

#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Engine/SkeletalMesh.h"
#include "Engine/StaticMesh.h"
#include "Animation/AnimMontage.h"

void UFELAIAssetManagerSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	UE_LOG(LogFEL, Log, TEXT("UFELAIAssetManagerSubsystem::Initialize — loading AI asset manifest"));
	LoadManifest();
}

void UFELAIAssetManagerSubsystem::Deinitialize()
{
	AnimCache.Empty();
	MeshCache.Empty();
	ManifestEntries.Empty();
	Super::Deinitialize();
}

void UFELAIAssetManagerSubsystem::LoadManifest()
{
	// Try multiple locations for the manifest
	TArray<FString> SearchPaths;
	SearchPaths.Add(FPaths::ProjectContentDir() / TEXT("FEL/Generated/asset_manifest.json"));
	SearchPaths.Add(FPaths::ProjectDir() / TEXT("GeneratedAssets/asset_manifest.json"));

	FString ManifestJson;
	for (const FString& P : SearchPaths)
	{
		if (FFileHelper::LoadFileToString(ManifestJson, *P))
		{
			UE_LOG(LogFEL, Log, TEXT("Loaded AI asset manifest from: %s"), *P);
			break;
		}
	}

	if (ManifestJson.IsEmpty())
	{
		UE_LOG(LogFEL, Warning, TEXT("No AI asset manifest found — generated assets not available"));
		return;
	}

	// Parse top-level JSON object
	TSharedPtr<FJsonObject> Root;
	TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(ManifestJson);
	if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
	{
		UE_LOG(LogFEL, Error, TEXT("Failed to parse AI asset manifest JSON"));
		return;
	}

	for (auto& Pair : Root->Values)
	{
		FString ValStr;
		TSharedRef<FJsonValueObject> ValObj = MakeShareable(new FJsonValueObject(Pair.Value->AsObject()));
		TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&ValStr);
		FJsonSerializer::Serialize(Pair.Value->AsObject().ToSharedRef(), Writer);
		ManifestEntries.Add(Pair.Key, ValStr);
	}

	UE_LOG(LogFEL, Log, TEXT("AI asset manifest loaded: %d entries"), ManifestEntries.Num());
}

UAnimMontage* UFELAIAssetManagerSubsystem::LoadExerciseAnimation(const FString& ExerciseId)
{
	FString CacheKey = ExerciseId + TEXT("_mocap");

	// Check cache
	if (TWeakObjectPtr<UAnimMontage>* Cached = AnimCache.Find(CacheKey))
	{
		if (Cached->IsValid())
		{
			return Cached->Get();
		}
	}

	// Build path from generated assets
	FString AssetPath = FString::Printf(TEXT("%s/deepmotion/%s"), FELGeneratedAssets::GENERATED_ROOT, *CacheKey);

	// Try loading
	UAnimMontage* Montage = Cast<UAnimMontage>(StaticLoadObject(UAnimMontage::StaticClass(), nullptr, *AssetPath));
	if (Montage)
	{
		AnimCache.Add(CacheKey, Montage);
		UE_LOG(LogFEL, Log, TEXT("Loaded AI exercise animation: %s"), *AssetPath);
	}
	else
	{
		UE_LOG(LogFEL, Warning, TEXT("AI exercise animation not found: %s (run asset pipeline first)"), *AssetPath);
	}

	return Montage;
}

UStaticMesh* UFELAIAssetManagerSubsystem::LoadExerciseProp(const FString& ExerciseId)
{
	FString CacheKey = ExerciseId + TEXT("_prop");

	if (TWeakObjectPtr<UStaticMesh>* Cached = MeshCache.Find(CacheKey))
	{
		if (Cached->IsValid())
		{
			return Cached->Get();
		}
	}

	FString AssetPath = FString::Printf(TEXT("%s/meshy/%s"), FELGeneratedAssets::GENERATED_ROOT, *CacheKey);
	UStaticMesh* Mesh = Cast<UStaticMesh>(StaticLoadObject(UStaticMesh::StaticClass(), nullptr, *AssetPath));
	if (Mesh)
	{
		MeshCache.Add(CacheKey, Mesh);
		UE_LOG(LogFEL, Log, TEXT("Loaded AI exercise prop: %s"), *AssetPath);
	}

	return Mesh;
}

UStaticMesh* UFELAIAssetManagerSubsystem::LoadEnvironmentMesh(const FString& VenueKey)
{
	FString CacheKey = FString::Printf(TEXT("env_%s_3d_model"), *VenueKey);

	if (TWeakObjectPtr<UStaticMesh>* Cached = MeshCache.Find(CacheKey))
	{
		if (Cached->IsValid())
		{
			return Cached->Get();
		}
	}

	FString AssetPath = FString::Printf(TEXT("%s/meshy/%s"), FELGeneratedAssets::GENERATED_ROOT, *CacheKey);
	UStaticMesh* Mesh = Cast<UStaticMesh>(StaticLoadObject(UStaticMesh::StaticClass(), nullptr, *AssetPath));
	if (Mesh)
	{
		MeshCache.Add(CacheKey, Mesh);
		UE_LOG(LogFEL, Log, TEXT("Loaded AI environment mesh: %s"), *AssetPath);
	}

	return Mesh;
}

int32 UFELAIAssetManagerSubsystem::GetLoadedAssetCount() const
{
	return ManifestEntries.Num();
}

bool UFELAIAssetManagerSubsystem::IsAssetAvailable(const FString& AssetKey) const
{
	return ManifestEntries.Contains(AssetKey);
}

FString UFELAIAssetManagerSubsystem::GetAssetManifestJSON() const
{
	FString Result = TEXT("{");
	bool First = true;
	for (auto& Pair : ManifestEntries)
	{
		if (!First) Result += TEXT(",");
		Result += FString::Printf(TEXT("\"%s\":%s"), *Pair.Key, *Pair.Value);
		First = false;
	}
	Result += TEXT("}");
	return Result;
}
