// Copyright (c) Final Evolution Lab.

#include "FELProgressionSubsystem.h"
#include "FELPlatformPaths.h"
#include "Dom/JsonObject.h"
#include "Dom/JsonValue.h"
#include "Misc/Paths.h"
#include "Misc/DateTime.h"
#include "HAL/PlatformFilemanager.h"
#include "Misc/FileHelper.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

void UFELProgressionSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	LoadFromDisk();
}

void UFELProgressionSubsystem::ResetSessionCounters()
{
	SessionShardsEarned = 0;
	SessionXPEarned = 0;
}

void UFELProgressionSubsystem::ApplyMatchRewards(const FFELMatchResultSummary& Summary)
{
	const int64 DS = FMath::Max(0, Summary.ShardsEarned);
	const int64 DX = FMath::Max(0, Summary.XPEarned);
	SessionShardsEarned += DS;
	SessionXPEarned += DX;
	LifetimeShards += DS;
	LifetimeXP += DX;
	if (DS > 0)
	{
		AppendLedger(TEXT("MatchRewards"), DS);
	}
	SaveToDisk();
}

int64 UFELProgressionSubsystem::GetShardAmountForReason(EFELShardRewardReason Reason) const
{
	return FELShardRewardTable::GetAmount(Reason);
}

int64 UFELProgressionSubsystem::AwardShardsForReason(EFELShardRewardReason Reason, int32 StackCount)
{
	const int64 Per = FELShardRewardTable::GetAmount(Reason);
	if (Per <= 0 || StackCount <= 0)
	{
		return 0;
	}
	const int64 Total = Per * static_cast<int64>(StackCount);
	SessionShardsEarned += Total;
	LifetimeShards += Total;
	AppendLedger(FELShardRewardTable::ReasonToKey(Reason), Total);
	SaveToDisk();
	return Total;
}

int64 UFELProgressionSubsystem::AwardMealNutritionShards(bool bStructuralRepair, bool bFascialElasticity, bool bSignalVelocity, bool bCongestionCleared)
{
	int64 Total = 0;
	if (bStructuralRepair)
	{
		Total += FELShardRewardTable::GetAmount(EFELShardRewardReason::StructuralRepair);
	}
	if (bFascialElasticity)
	{
		Total += FELShardRewardTable::GetAmount(EFELShardRewardReason::FascialElasticity);
	}
	if (bSignalVelocity)
	{
		Total += FELShardRewardTable::GetAmount(EFELShardRewardReason::SignalVelocity);
	}
	if (bCongestionCleared)
	{
		Total += FELShardRewardTable::GetAmount(EFELShardRewardReason::CongestionCleared);
	}
	if (Total <= 0)
	{
		return 0;
	}
	SessionShardsEarned += Total;
	LifetimeShards += Total;
	AppendLedger(TEXT("MealNutrition"), Total);
	SaveToDisk();
	return Total;
}

int64 UFELProgressionSubsystem::AwardShardsRaw(int64 Amount, const FString& LedgerReasonKey)
{
	const int64 A = FMath::Max<int64>(0, Amount);
	if (A == 0)
	{
		return 0;
	}
	SessionShardsEarned += A;
	LifetimeShards += A;
	const FString Key = LedgerReasonKey.IsEmpty() ? TEXT("Custom") : LedgerReasonKey;
	AppendLedger(Key, A);
	SaveToDisk();
	return A;
}

void UFELProgressionSubsystem::AppendLedger(const FString& ReasonKey, int64 Amount)
{
	FFELShardLedgerEntry E;
	E.ReasonKey = ReasonKey;
	E.Amount = Amount;
	E.TimeUnix = static_cast<double>(FDateTime::UtcNow().ToUnixTimestamp());
	RecentShardLedger.Insert(E, 0);
	if (RecentShardLedger.Num() > MaxLedgerEntries)
	{
		RecentShardLedger.SetNum(MaxLedgerEntries);
	}
}

void UFELProgressionSubsystem::LoadFromDisk()
{
	const FString Path = FELPlatformPaths::GetProgressionSaveJsonPath();
	FString Json;
	if (!FFileHelper::LoadFileToString(Json, *Path))
	{
		return;
	}
	TSharedPtr<FJsonObject> Root;
	const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Json);
	if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
	{
		return;
	}
	double LS = 0.0;
	double LX = 0.0;
	(void)Root->TryGetNumberField(TEXT("lifetimeShards"), LS);
	(void)Root->TryGetNumberField(TEXT("lifetimeXP"), LX);
	LifetimeShards = static_cast<int64>(FMath::Max(0.0, LS));
	LifetimeXP = static_cast<int64>(FMath::Max(0.0, LX));

	RecentShardLedger.Reset();
	const TArray<TSharedPtr<FJsonValue>>* LedgerArr = nullptr;
	if (Root->TryGetArrayField(TEXT("shardLedger"), LedgerArr) && LedgerArr != nullptr)
	{
		for (const TSharedPtr<FJsonValue>& V : *LedgerArr)
		{
			const TSharedPtr<FJsonObject>* O = nullptr;
			if (!V.IsValid() || !V->TryGetObject(O) || !O->IsValid())
			{
				continue;
			}
			FFELShardLedgerEntry E;
			(void)(*O)->TryGetStringField(TEXT("reason"), E.ReasonKey);
			double Amt = 0.0;
			(void)(*O)->TryGetNumberField(TEXT("amount"), Amt);
			E.Amount = static_cast<int64>(FMath::Max(0.0, Amt));
			double TU = 0.0;
			(void)(*O)->TryGetNumberField(TEXT("t"), TU);
			E.TimeUnix = TU;
			if (E.Amount > 0 && !E.ReasonKey.IsEmpty())
			{
				RecentShardLedger.Add(E);
			}
		}
		if (RecentShardLedger.Num() > MaxLedgerEntries)
		{
			RecentShardLedger.SetNum(MaxLedgerEntries);
		}
	}
}

void UFELProgressionSubsystem::SaveToDisk() const
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetNumberField(TEXT("lifetimeShards"), static_cast<double>(LifetimeShards));
	O->SetNumberField(TEXT("lifetimeXP"), static_cast<double>(LifetimeXP));

	TArray<TSharedPtr<FJsonValue>> LedgerJson;
	LedgerJson.Reserve(RecentShardLedger.Num());
	for (const FFELShardLedgerEntry& E : RecentShardLedger)
	{
		TSharedPtr<FJsonObject> Row = MakeShared<FJsonObject>();
		Row->SetStringField(TEXT("reason"), E.ReasonKey);
		Row->SetNumberField(TEXT("amount"), static_cast<double>(E.Amount));
		Row->SetNumberField(TEXT("t"), E.TimeUnix);
		LedgerJson.Add(MakeShared<FJsonValueObject>(Row));
	}
	O->SetArrayField(TEXT("shardLedger"), LedgerJson);

	FString OutStr;
	const TSharedRef<TJsonWriter<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>> Writer =
		TJsonWriterFactory<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>::Create(&OutStr);
	if (!FJsonSerializer::Serialize(O.ToSharedRef(), Writer))
	{
		return;
	}

	const FString Path = FELPlatformPaths::GetProgressionSaveJsonPath();
	const FString Dir = FPaths::GetPath(Path);
	IPlatformFile& PF = FPlatformFileManager::Get().GetPlatformFile();
	if (!PF.DirectoryExists(*Dir))
	{
		PF.CreateDirectoryTree(*Dir);
	}
	FFileHelper::SaveStringToFile(OutStr, *Path);
}
