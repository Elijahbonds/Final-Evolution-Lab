// Copyright (c) Final Evolution Lab.

#include "FELArenaRulesRegistry.h"
#include "FELGameModeDefinitions.h"
#include "Animation/AnimInstance.h"
#include "Engine/SkeletalMesh.h"
#include "UObject/SoftObjectPath.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"

namespace FELArenaRulesRegistryInternal
{
	/** Default production avatar under /Game/Models/Avatar/ — override per mode in JSON or the switch below. */
	static void ApplyDefaultDemonstratorAssets(FFELSportNeuroConstants& C)
	{
		C.DemonstratorSkeletalMesh = TSoftObjectPtr<USkeletalMesh>(
			FSoftObjectPath(TEXT("/Game/Models/Avatar/SKM_FELAvatar.SKM_FELAvatar")));
		C.DemonstratorAnimInstanceClass = TSoftClassPtr<UAnimInstance>(
			FSoftObjectPath(TEXT("/Game/Models/Avatar/ABP_FELAvatar.ABP_FELAvatar_C")));
	}

	/** Sport-specific neuro constants for all 12 Arena modes (PROJECT_FLOWS). */
	static void ApplySportNeuroDefaults(const EFELArenaMode Mode, FFELArenaRules& R)
	{
		FFELSportNeuroConstants& C = R.SportNeuro;
		ApplyDefaultDemonstratorAssets(C);
		switch (Mode)
		{
		case EFELArenaMode::BasketballHeadToHead:
			C.BasketballDriveExplosionScale = 1.0f;
			break;
		case EFELArenaMode::BasketballDunkContest:
			C.BasketballDriveExplosionScale = 1.08f;
			break;
		case EFELArenaMode::Basketball3v3:
			C.BasketballDriveExplosionScale = 1.0f;
			break;
		case EFELArenaMode::Soccer:
			C.SoccerKickPower = 1.12f;
			C.SoccerLateralStrainThreshold = 0.48f;
			C.LateralNeuralDriveRequired = 74.f;
			C.LateralWalkPenaltyMin = 0.65f;
			break;
		case EFELArenaMode::Tennis:
			C.TennisLateralStrainThreshold = 0.50f;
			C.LateralNeuralDriveRequired = 73.f;
			break;
		case EFELArenaMode::Volleyball:
			C.VolleyballReactionWindowMs = 165.f;
			break;
		case EFELArenaMode::Football:
			C.FootballLateralStrainThreshold = 0.56f;
			C.LateralNeuralDriveRequired = 76.f;
			break;
		case EFELArenaMode::Baseball:
			C.BaseballSwingWindowMs = 78.f;
			C.BaseballPerfectWindowPRQExpandMs = 48.f;
			break;
		case EFELArenaMode::Golf:
			C.GolfSliceMultiplier = 1.08f;
			break;
		case EFELArenaMode::Karate:
			C.KarateStrikeWindowMs = 65.f;
			C.KaratePerfectWindowPRQExpandMs = 52.f;
			break;
		case EFELArenaMode::Gymnastics:
			C.GymnasticsTempoScale = 1.0f;
			break;
		case EFELArenaMode::BrainBrawl:
			C.BrainBrawlCognitionWeight = 1.05f;
			break;
		case EFELArenaMode::MarketBrowse:
			break;
		default:
			break;
		}
	}

	static EFELBasketballPlayMode ParseSlice(const FString& S)
	{
		if (S.Equals(TEXT("StreetBall"), ESearchCase::IgnoreCase))
		{
			return EFELBasketballPlayMode::StreetBall;
		}
		if (S.Equals(TEXT("HalfCourtShootout"), ESearchCase::IgnoreCase))
		{
			return EFELBasketballPlayMode::HalfCourtShootout;
		}
		if (S.Equals(TEXT("TimedBlitz"), ESearchCase::IgnoreCase))
		{
			return EFELBasketballPlayMode::TimedBlitz;
		}
		if (S.Equals(TEXT("Practice"), ESearchCase::IgnoreCase))
		{
			return EFELBasketballPlayMode::Practice;
		}
		if (S.Equals(TEXT("FirstToTwentyOne"), ESearchCase::IgnoreCase))
		{
			return EFELBasketballPlayMode::FirstToTwentyOne;
		}
		return EFELBasketballPlayMode::StreetBall;
	}

	static EFELArenaBallSpawnType ParseBallSpawn(const FString& S)
	{
		if (S.Equals(TEXT("None"), ESearchCase::IgnoreCase))
		{
			return EFELArenaBallSpawnType::None;
		}
		if (S.Equals(TEXT("DualHalfCourt"), ESearchCase::IgnoreCase))
		{
			return EFELArenaBallSpawnType::DualHalfCourt;
		}
		return EFELArenaBallSpawnType::SingleAtPrimary;
	}

	static FFELArenaRules BuildFactoryDefaults(EFELArenaMode Mode)
	{
		FFELArenaRules R;
		switch (Mode)
		{
		case EFELArenaMode::BasketballHeadToHead:
			R.ModeDisplayName = TEXT("Street Ball");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::StreetBall;
			R.BallCount = 1;
			R.TargetScore = 3;
			R.bNeuroKineticLeakageForDunkParity = true;
			break;
		case EFELArenaMode::BasketballDunkContest:
			// GAMEPLAY_STATUS: Arena Dunk vs Lab Dunk — same NeuroKineticLeakage in ApplyReadiness; optional scales from JSON only.
			R.ModeDisplayName = TEXT("Dunk Contest");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = true;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::FirstToTwentyOne;
			R.BallCount = 1;
			R.TargetScore = 21;
			R.bNeuroKineticLeakageForDunkParity = true;
			break;
		case EFELArenaMode::Basketball3v3:
			R.ModeDisplayName = TEXT("Half-Court Shootout");
			R.BallSpawnType = EFELArenaBallSpawnType::DualHalfCourt;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::HalfCourtShootout;
			R.BallCount = 2;
			R.TargetScore = 11;
			R.bNeuroKineticLeakageForDunkParity = true;
			break;
		case EFELArenaMode::BrainBrawl:
			R.ModeDisplayName = TEXT("Brain Brawl");
			R.BallSpawnType = EFELArenaBallSpawnType::None;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			R.BallCount = 0;
			R.TargetScore = 5;
			R.bScoringEnabled = false;
			R.bNeuroKineticLeakageForDunkParity = true;
			break;
		case EFELArenaMode::MarketBrowse:
			R.ModeDisplayName = TEXT("Sovereign Shop");
			R.BallSpawnType = EFELArenaBallSpawnType::None;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			R.BallCount = 0;
			R.TargetScore = 0;
			R.bScoringEnabled = false;
			R.bNeuroKineticLeakageForDunkParity = false;
			break;
		case EFELArenaMode::Golf:
			R.ModeDisplayName = TEXT("Golf (slice)");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			R.TargetScore = 3;
			break;
		case EFELArenaMode::Soccer:
			R.ModeDisplayName = TEXT("Soccer (slice)");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::StreetBall;
			R.TargetScore = 5;
			break;
		case EFELArenaMode::Tennis:
			R.ModeDisplayName = TEXT("Tennis (slice)");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::TimedBlitz;
			R.TimeLimitSeconds = 120.f;
			R.TargetScore = 5;
			break;
		case EFELArenaMode::Volleyball:
			R.ModeDisplayName = TEXT("Volleyball (slice)");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::TimedBlitz;
			R.TimeLimitSeconds = 120.f;
			R.TargetScore = 5;
			break;
		case EFELArenaMode::Karate:
			R.ModeDisplayName = TEXT("Karate (slice)");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::StreetBall;
			R.TargetScore = 5;
			break;
		case EFELArenaMode::Football:
			R.ModeDisplayName = TEXT("Football (slice)");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::StreetBall;
			R.TargetScore = 5;
			break;
		case EFELArenaMode::Baseball:
			R.ModeDisplayName = TEXT("Baseball (slice)");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			R.TargetScore = 3;
			break;
		case EFELArenaMode::Gymnastics:
			R.ModeDisplayName = TEXT("Gymnastics (slice)");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			R.TargetScore = 3;
			break;
		default:
			R.ModeDisplayName = TEXT("Practice");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			break;
		}
		ApplySportNeuroDefaults(Mode, R);
		return R;
	}

	static const FString& JsonPath()
	{
		static const FString Path = FPaths::ProjectContentDir() / TEXT("FEL/Config/ArenaSettings.json");
		return Path;
	}

	static void ApplyJsonOverridesToRulesImpl(EFELArenaMode Mode, FFELArenaRules& InOut)
	{
		const FString SwiftId = FELArenaModeToSwiftId(Mode);
		FString Json;
		if (!FFileHelper::LoadFileToString(Json, *JsonPath()))
		{
			return;
		}

		TSharedPtr<FJsonObject> Root;
		const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Json);
		if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
		{
			return;
		}

		TSharedPtr<FJsonObject> ModesObj;
		if (!Root->TryGetObjectField(TEXT("modes"), ModesObj) || !ModesObj.IsValid())
		{
			return;
		}

		TSharedPtr<FJsonObject> RuleObj;
		if (!ModesObj->TryGetObjectField(SwiftId, RuleObj) || !RuleObj.IsValid())
		{
			return;
		}

		FString S;
		double D = 0.0;
		bool B = false;

		if (RuleObj->TryGetStringField(TEXT("modeDisplayName"), S))
		{
			InOut.ModeDisplayName = S;
		}
		if (RuleObj->TryGetStringField(TEXT("unrealBasketballSlice"), S))
		{
			InOut.UnrealBasketballSlice = ParseSlice(S);
		}
		if (RuleObj->TryGetNumberField(TEXT("timeLimitSeconds"), D))
		{
			InOut.TimeLimitSeconds = static_cast<float>(D);
		}
		if (RuleObj->TryGetNumberField(TEXT("ballCount"), D))
		{
			InOut.BallCount = FMath::RoundToInt(D);
		}
		if (RuleObj->TryGetNumberField(TEXT("targetScore"), D))
		{
			InOut.TargetScore = FMath::RoundToInt(D);
		}
		if (RuleObj->TryGetNumberField(TEXT("physicsJumpScale"), D))
		{
			InOut.PhysicsJumpScale = static_cast<float>(D);
		}
		if (RuleObj->TryGetNumberField(TEXT("physicsWalkScale"), D))
		{
			InOut.PhysicsWalkScale = static_cast<float>(D);
		}
		if (RuleObj->TryGetBoolField(TEXT("bScoringEnabled"), B))
		{
			InOut.bScoringEnabled = B;
		}
		if (RuleObj->TryGetBoolField(TEXT("bNeuroKineticLeakageForDunkParity"), B))
		{
			InOut.bNeuroKineticLeakageForDunkParity = B;
		}
		if (RuleObj->TryGetStringField(TEXT("ballSpawnType"), S))
		{
			InOut.BallSpawnType = ParseBallSpawn(S);
		}
		if (RuleObj->TryGetBoolField(TEXT("bIsDunkContest"), B))
		{
			InOut.bIsDunkContest = B;
		}
	}

	static void SanitizeRulesInPlaceImpl(FFELArenaRules& R, EFELArenaMode Mode)
	{
		R.PhysicsJumpScale = FMath::Clamp(R.PhysicsJumpScale, 0.25f, 3.f);
		R.PhysicsWalkScale = FMath::Clamp(R.PhysicsWalkScale, 0.25f, 3.f);

		FFELSportNeuroConstants& SN = R.SportNeuro;
		SN.SoccerKickPower = FMath::Clamp(SN.SoccerKickPower, 0.35f, 1.6f);
		SN.BaseballSwingWindowMs = FMath::Clamp(SN.BaseballSwingWindowMs, 40.f, 220.f);
		SN.BaseballPerfectWindowPRQExpandMs = FMath::Clamp(SN.BaseballPerfectWindowPRQExpandMs, 10.f, 120.f);
		SN.GolfSliceMultiplier = FMath::Clamp(SN.GolfSliceMultiplier, 0.75f, 1.35f);
		SN.TennisLateralStrainThreshold = FMath::Clamp(SN.TennisLateralStrainThreshold, 0.25f, 0.95f);
		SN.SoccerLateralStrainThreshold = FMath::Clamp(SN.SoccerLateralStrainThreshold, 0.25f, 0.95f);
		SN.FootballLateralStrainThreshold = FMath::Clamp(SN.FootballLateralStrainThreshold, 0.25f, 0.95f);
		SN.LateralNeuralDriveRequired = FMath::Clamp(SN.LateralNeuralDriveRequired, 50.f, 95.f);
		SN.LateralWalkPenaltyMin = FMath::Clamp(SN.LateralWalkPenaltyMin, 0.35f, 1.f);
		SN.KarateStrikeWindowMs = FMath::Clamp(SN.KarateStrikeWindowMs, 40.f, 200.f);
		SN.KaratePerfectWindowPRQExpandMs = FMath::Clamp(SN.KaratePerfectWindowPRQExpandMs, 10.f, 120.f);
		SN.VolleyballReactionWindowMs = FMath::Clamp(SN.VolleyballReactionWindowMs, 80.f, 320.f);
		SN.GymnasticsTempoScale = FMath::Clamp(SN.GymnasticsTempoScale, 0.5f, 1.5f);
		SN.BrainBrawlCognitionWeight = FMath::Clamp(SN.BrainBrawlCognitionWeight, 0.5f, 1.5f);
		SN.BasketballDriveExplosionScale = FMath::Clamp(SN.BasketballDriveExplosionScale, 0.5f, 1.5f);

		// Parity: dunk slice always uses leakage path in ApplyReadiness (GAMEPLAY_STATUS).
		if (Mode == EFELArenaMode::BasketballDunkContest)
		{
			R.bNeuroKineticLeakageForDunkParity = true;
			R.bIsDunkContest = true;
		}
	}
}

FFELArenaRules FELArenaRulesRegistry::GetMergedRules(EFELArenaMode Mode)
{
	if (Mode == EFELArenaMode::Unknown)
	{
		Mode = EFELArenaMode::BasketballHeadToHead;
	}

	FFELArenaRules R = FELArenaRulesRegistryInternal::BuildFactoryDefaults(Mode);
	FELArenaRulesRegistryInternal::ApplyJsonOverridesToRulesImpl(Mode, R);
	FELArenaRulesRegistryInternal::SanitizeRulesInPlaceImpl(R, Mode);
	return R;
}

void FELArenaRulesRegistry::ApplyJsonOverridesToRules(const EFELArenaMode Mode, FFELArenaRules& InOut)
{
	FELArenaRulesRegistryInternal::ApplyJsonOverridesToRulesImpl(Mode, InOut);
}

void FELArenaRulesRegistry::SanitizeRulesInPlace(FFELArenaRules& R, const EFELArenaMode Mode)
{
	FELArenaRulesRegistryInternal::SanitizeRulesInPlaceImpl(R, Mode);
}
