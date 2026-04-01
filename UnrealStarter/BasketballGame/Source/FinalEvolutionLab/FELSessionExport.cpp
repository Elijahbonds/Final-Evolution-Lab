// Copyright (c) Final Evolution Lab.

#include "FELSessionExport.h"
#include "Engine/World.h"
#include "FELArenaBridge.h"
#include "FELBasketballGameState.h"
#include "FELPlatformPaths.h"
#include "HAL/PlatformFilemanager.h"
#include "Misc/FileHelper.h"
#include "Misc/Guid.h"
#include "Misc/Paths.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"
#include "Policies/CondensedJsonPrintPolicy.h"

static double SwiftReferenceDateSeconds()
{
	static const FDateTime kRef(2001, 1, 1);
	return (FDateTime::UtcNow() - kRef).GetTotalSeconds();
}

bool FELSessionExport::WriteLastSession(const AFELBasketballGameState* GS, UWorld* World, FString* OutError)
{
	if (!GS || !World)
	{
		return false;
	}

	const bool bEconomy = GS->IsScoringEnabled();
	const int32 Score = GS->GetScore();
	const double PRQ = GS->GetReadinessSnapshot().PRQScore;
	const FString& ModeId = GS->GetArenaGameModeId();

	const int32 Shards = FELArenaBridge::ComputeShardsEarned(Score, PRQ, ModeId, bEconomy);
	const double Bonus = FELArenaBridge::ComputePRQBonus(Score, PRQ, bEconomy);

	const double StartT = GS->GetMatchStartWorldTimeSeconds();
	const float Now = World->GetTimeSeconds();
	const int32 DurationSecs = FMath::Max(0, FMath::RoundToInt(static_cast<double>(Now) - StartT));

	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("id"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	O->SetStringField(TEXT("gameModeId"), ModeId);
	O->SetNumberField(TEXT("date"), SwiftReferenceDateSeconds());
	O->SetNumberField(TEXT("score"), static_cast<double>(Score));
	O->SetNumberField(TEXT("opponentScore"), 0.0);
	O->SetNumberField(TEXT("shardsEarned"), static_cast<double>(Shards));
	O->SetNumberField(TEXT("prqBonus"), Bonus);
	O->SetBoolField(TEXT("isMultiplayer"), false);
	O->SetNumberField(TEXT("duration"), static_cast<double>(DurationSecs));
	if (bEconomy)
	{
		O->SetNumberField(TEXT("roundsPlayed"), static_cast<double>(Score));
	}

	FString OutStr;
	const TSharedRef<TJsonWriter<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>> Writer =
		TJsonWriterFactory<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>::Create(&OutStr);
	if (!FJsonSerializer::Serialize(O.ToSharedRef(), Writer))
	{
		if (OutError)
		{
			*OutError = TEXT("JSON serialize failed");
		}
		return false;
	}

	const FString Dir = FELPlatformPaths::GetFELDataDirectory();
	IPlatformFile& PF = FPlatformFileManager::Get().GetPlatformFile();
	if (!PF.DirectoryExists(*Dir))
	{
		PF.CreateDirectoryTree(*Dir);
	}

	const FString Path = Dir / TEXT("last_session_result.json");
	if (!FFileHelper::SaveStringToFile(OutStr, *Path))
	{
		if (OutError)
		{
			*OutError = FString::Printf(TEXT("Could not write %s"), *Path);
		}
		return false;
	}
	return true;
}

bool FELSessionExport::WriteSessionResults(const FFELMatchResultSummary& Summary, const FString& ArenaGameModeId, FString* OutError)
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("id"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	O->SetStringField(TEXT("gameModeId"), ArenaGameModeId.IsEmpty() ? Summary.GameModeId : ArenaGameModeId);
	O->SetNumberField(TEXT("date"), SwiftReferenceDateSeconds());
	O->SetNumberField(TEXT("score"), static_cast<double>(Summary.Score));
	O->SetNumberField(TEXT("opponentScore"), static_cast<double>(Summary.OpponentScore));
	O->SetNumberField(TEXT("shardsEarned"), static_cast<double>(Summary.ShardsEarned));
	O->SetNumberField(TEXT("prqBonus"), Summary.PRQBonus);
	O->SetBoolField(TEXT("isMultiplayer"), false);
	O->SetNumberField(TEXT("duration"), static_cast<double>(Summary.DurationSeconds));
	if (Summary.bEconomyEnabled && Summary.Score > 0)
	{
		O->SetNumberField(TEXT("roundsPlayed"), static_cast<double>(Summary.Score));
	}
	// Optional for Swift; ignored by Codable if model not extended.
	O->SetNumberField(TEXT("neuroPerformance"), Summary.NeuroPerformanceScore);
	O->SetNumberField(TEXT("mentalSharpness"), Summary.MentalSharpnessScore);
	O->SetNumberField(TEXT("brainBrawlBoostCount"), static_cast<double>(Summary.BrainBrawlBoostCount));
	O->SetNumberField(TEXT("xpEarned"), static_cast<double>(Summary.XPEarned));
	O->SetNumberField(TEXT("masteryScore"), Summary.MasteryScore);
	O->SetStringField(TEXT("masteryMetric"), Summary.MasteryMetricId);

	if (Summary.AcademyCompletedModuleKeys.Num() > 0 || Summary.AcademyEvolutionShardsEarned > 0)
	{
		TSharedPtr<FJsonObject> AP = MakeShared<FJsonObject>();
		TArray<TSharedPtr<FJsonValue>> ModArr;
		ModArr.Reserve(Summary.AcademyCompletedModuleKeys.Num());
		for (const FString& K : Summary.AcademyCompletedModuleKeys)
		{
			ModArr.Add(MakeShared<FJsonValueString>(K));
		}
		AP->SetArrayField(TEXT("completed_module_ids"), ModArr);
		AP->SetNumberField(TEXT("evolution_shards_earned"), static_cast<double>(Summary.AcademyEvolutionShardsEarned));
		O->SetObjectField(TEXT("academy_progress"), AP);
	}

	if (!Summary.BrainBrawlLocalPathId.IsEmpty() || Summary.BrainBrawlRoundSeconds > 0)
	{
		TSharedPtr<FJsonObject> BB = MakeShared<FJsonObject>();
		BB->SetStringField(TEXT("local_path_id"), Summary.BrainBrawlLocalPathId);
		BB->SetStringField(TEXT("opponent_path_id"), Summary.BrainBrawlOpponentPathId);
		BB->SetNumberField(TEXT("local_correct"), static_cast<double>(Summary.BrainBrawlLocalCorrect));
		BB->SetNumberField(TEXT("opponent_correct"), static_cast<double>(Summary.BrainBrawlOpponentCorrect));
		BB->SetNumberField(TEXT("round_seconds"), static_cast<double>(Summary.BrainBrawlRoundSeconds));
		O->SetObjectField(TEXT("brain_brawl_academy"), BB);
	}

	{
		const FFELArenaResult& A = Summary.ArenaResult;
		TSharedPtr<FJsonObject> AR = MakeShared<FJsonObject>();
		AR->SetNumberField(TEXT("final_score"), static_cast<double>(A.FinalScore));
		AR->SetNumberField(TEXT("new_prq_estimate"), A.NewPRQEstimate);
		AR->SetNumberField(TEXT("evolution_shards_earned"), static_cast<double>(A.EvolutionShardsEarned));
		AR->SetNumberField(TEXT("perfect_timing_count"), static_cast<double>(A.PerfectTimingCount));
		AR->SetBoolField(TEXT("best_moment_replay_available"), A.bBestMomentReplayAvailable);
		O->SetObjectField(TEXT("arena_result"), AR);
	}

	FString OutStr;
	const TSharedRef<TJsonWriter<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>> Writer =
		TJsonWriterFactory<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>::Create(&OutStr);
	if (!FJsonSerializer::Serialize(O.ToSharedRef(), Writer))
	{
		if (OutError)
		{
			*OutError = TEXT("JSON serialize failed");
		}
		return false;
	}

	const FString Dir = FELPlatformPaths::GetFELDataDirectory();
	IPlatformFile& PF = FPlatformFileManager::Get().GetPlatformFile();
	if (!PF.DirectoryExists(*Dir))
	{
		PF.CreateDirectoryTree(*Dir);
	}

	const FString Path = FELPlatformPaths::GetSessionResultsJsonPath();
	if (!FFileHelper::SaveStringToFile(OutStr, *Path))
	{
		if (OutError)
		{
			*OutError = FString::Printf(TEXT("Could not write %s"), *Path);
		}
		return false;
	}
	return true;
}
