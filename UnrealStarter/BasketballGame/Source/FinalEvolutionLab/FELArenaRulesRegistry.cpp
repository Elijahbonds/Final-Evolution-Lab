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
			C.BasketballDriveExplosionScale = 1.06f;
			C.StreetJamTrickDecayPerSecond = 0.2f;
			C.StreetJamTrickGainGatherPerfect = 13.f;
			C.StreetJamTrickGainOnBucket = 10.f;
			C.StreetJamBucketChainGraceSeconds = 3.85f;
			C.StreetJamMultiplierCapBase = 2.75f;
			C.SwitchCourtWalkBonusMax = 0.036f;
			break;
		case EFELArenaMode::BasketballDunkContest:
			C.BasketballDriveExplosionScale = 1.08f;
			// THPS-style meter + PRQ/Creator Card scaling (see `UFELDunkContestSessionSubsystem`).
			C.DunkContestStyleDecayPerSecond = 0.32f;
			C.DunkContestStyleGainPerfect = 22.f;
			C.DunkContestStyleGainGood = 9.f;
			C.DunkContestStyleLeakPenalty = 7.f;
			C.DunkContestChainGraceSeconds = 3.05f;
			C.DunkContestMultiplierCapBase = 3.35f;
			C.DunkContestMultiplierCapPerPRQPoint = 0.02f;
			C.DunkContestPRQStyleFillBonus = 0.26f;
			break;
		case EFELArenaMode::Basketball3v3:
			C.BasketballDriveExplosionScale = 1.08f;
			C.StreetJamTrickDecayPerSecond = 0.24f;
			C.StreetJamTrickGainOnBucket = 11.f;
			C.StreetJamBucketChainGraceSeconds = 3.25f;
			C.StreetJamMultiplierCapBase = 2.85f;
			C.StreetJamGamebreakerBonusPoints = 5.f;
			C.SwitchCourtWalkBonusMax = 0.038f;
			break;
		case EFELArenaMode::Soccer:
			C.SoccerKickPower = 1.12f;
			C.SoccerLateralStrainThreshold = 0.48f;
			C.LateralNeuralDriveRequired = 74.f;
			C.LateralWalkPenaltyMin = 0.65f;
			break;
		case EFELArenaMode::Tennis:
			C.TennisLateralStrainThreshold = 0.46f;
			C.LateralNeuralDriveRequired = 70.f;
			C.SwitchTennisExtraConeDeg = 1.f;
			C.SwitchTennisConeBonusPerPRQDeg = 0.016f;
			C.SwitchCourtWalkBonusMax = 0.048f;
			break;
		case EFELArenaMode::Volleyball:
			C.VolleyballReactionWindowMs = 198.f;
			C.SwitchVolleyballExtraSpikeMarginMs = 16.f;
			C.SwitchVolleyballSpikeMarginPerPRQMs = 0.13f;
			C.SwitchCourtWalkBonusMax = 0.046f;
			break;
		case EFELArenaMode::Football:
			C.FootballLateralStrainThreshold = 0.52f;
			C.LateralNeuralDriveRequired = 72.f;
			C.KickReturnBaseYardsPerSecond = 11.5f;
			C.KickReturnPRQSpeedCoef = 0.48f;
			C.KickReturnPRQDurabilityCoef = 0.58f;
			C.KickReturnGaugeFillPerSecond = 0.2f;
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
		case EFELArenaMode::Surfing:
		case EFELArenaMode::Skateboarding:
		case EFELArenaMode::Snowboarding:
			C.BoardSportBaseLineScorePerSecond = 1.42f;
			C.BoardSportPRQLineCoef = 0.44f;
			C.BoardSportTrickGaugeFillPerSecond = 0.2f;
			C.BoardSportPRQTrickCoef = 0.38f;
			C.BoardSportBalanceLeakPerSecond = 0.11f;
			C.BoardSportPRQBalanceMitigation = 0.58f;
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
			R.ModeDisplayName = TEXT("Street · 1v1");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.bStreetJamArcade = true;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::StreetBall;
			R.BallCount = 1;
			R.TargetScore = 3;
			R.PhysicsWalkScale = 1.045f;
			R.PhysicsJumpScale = 1.03f;
			R.bNeuroKineticLeakageForDunkParity = true;
			break;
		case EFELArenaMode::BasketballDunkContest:
			// GAMEPLAY_STATUS: Arena Dunk vs Lab Dunk — same NeuroKineticLeakage in ApplyReadiness; optional scales from JSON only.
			R.ModeDisplayName = TEXT("Dunk Contest");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = true;
			R.bStreetJamArcade = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::FirstToTwentyOne;
			R.BallCount = 1;
			R.TargetScore = 21;
			R.bNeuroKineticLeakageForDunkParity = true;
			break;
		case EFELArenaMode::Basketball3v3:
			R.ModeDisplayName = TEXT("Street · 3v3");
			R.BallSpawnType = EFELArenaBallSpawnType::DualHalfCourt;
			R.bIsDunkContest = false;
			R.bStreetJamArcade = true;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::HalfCourtShootout;
			R.BallCount = 2;
			R.TargetScore = 11;
			R.PhysicsWalkScale = 1.055f;
			R.PhysicsJumpScale = 1.035f;
			R.bNeuroKineticLeakageForDunkParity = true;
			break;
		case EFELArenaMode::BrainBrawl:
			R.ModeDisplayName = TEXT("Academy · Brain Brawl");
			R.BallSpawnType = EFELArenaBallSpawnType::None;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			R.BallCount = 0;
			R.TargetScore = 0;
			R.bScoringEnabled = false;
			R.bNeuroKineticLeakageForDunkParity = true;
			R.TimeLimitSeconds = 120.f;
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
			R.ModeDisplayName = TEXT("Golf · Links");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			R.TargetScore = 5;
			R.TimeLimitSeconds = 300.f;
			break;
		case EFELArenaMode::Soccer:
			R.ModeDisplayName = TEXT("Soccer · stadium");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::StreetBall;
			R.TargetScore = 5;
			R.TimeLimitSeconds = 180.f;
			break;
		case EFELArenaMode::Tennis:
			R.ModeDisplayName = TEXT("Tennis · Court");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::TimedBlitz;
			R.TimeLimitSeconds = 120.f;
			R.TargetScore = 5;
			R.PhysicsWalkScale = 1.04f;
			break;
		case EFELArenaMode::Volleyball:
			R.ModeDisplayName = TEXT("Volleyball · Sand court");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::TimedBlitz;
			R.TimeLimitSeconds = 120.f;
			R.TargetScore = 5;
			R.PhysicsWalkScale = 1.04f;
			break;
		case EFELArenaMode::Karate:
			R.ModeDisplayName = TEXT("Karate · Dojo");
			R.KarateLabMode = EFELKarateLabMode::HeadToHeadStorm;
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::StreetBall;
			R.TargetScore = 5;
			R.TimeLimitSeconds = 150.f;
			break;
		case EFELArenaMode::Football:
			R.ModeDisplayName = TEXT("Football · kick return");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::StreetBall;
			R.TargetScore = 3;
			R.TimeLimitSeconds = 240.f;
			R.PhysicsWalkScale = 1.05f;
			break;
		case EFELArenaMode::Baseball:
			R.ModeDisplayName = TEXT("Baseball · Ballpark");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			R.TargetScore = 6;
			R.TimeLimitSeconds = 300.f;
			break;
		case EFELArenaMode::Gymnastics:
			R.ModeDisplayName = TEXT("Gymnastics · Floor");
			R.BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			R.TargetScore = 5;
			R.TimeLimitSeconds = 240.f;
			break;
		case EFELArenaMode::Surfing:
			R.ModeDisplayName = TEXT("Surf · Line");
			R.BallSpawnType = EFELArenaBallSpawnType::None;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			R.BallCount = 0;
			R.TargetScore = 0;
			R.bScoringEnabled = true;
			R.TimeLimitSeconds = 180.f;
			R.PhysicsWalkScale = 1.06f;
			R.PhysicsJumpScale = 1.04f;
			break;
		case EFELArenaMode::Skateboarding:
			R.ModeDisplayName = TEXT("Skate · Line");
			R.BallSpawnType = EFELArenaBallSpawnType::None;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			R.BallCount = 0;
			R.TargetScore = 0;
			R.bScoringEnabled = true;
			R.TimeLimitSeconds = 180.f;
			R.PhysicsWalkScale = 1.05f;
			R.PhysicsJumpScale = 1.06f;
			break;
		case EFELArenaMode::Snowboarding:
			R.ModeDisplayName = TEXT("Snow · Line");
			R.BallSpawnType = EFELArenaBallSpawnType::None;
			R.bIsDunkContest = false;
			R.UnrealBasketballSlice = EFELBasketballPlayMode::Practice;
			R.BallCount = 0;
			R.TargetScore = 0;
			R.bScoringEnabled = true;
			R.TimeLimitSeconds = 180.f;
			R.PhysicsWalkScale = 1.04f;
			R.PhysicsJumpScale = 1.05f;
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
		const FString ModeId = FELArenaModeToIdString(Mode);
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

		const TSharedPtr<FJsonObject> ModesObj = Root->GetObjectField(TEXT("modes"));
		if (!ModesObj.IsValid())
		{
			return;
		}

		const TSharedPtr<FJsonObject> RuleObj = ModesObj->GetObjectField(ModeId);
		if (!RuleObj.IsValid())
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
		if (RuleObj->TryGetBoolField(TEXT("bStreetJamArcade"), B))
		{
			InOut.bStreetJamArcade = B;
		}
		if (RuleObj->TryGetStringField(TEXT("unrealOpenLevelPackage"), S))
		{
			InOut.UnrealOpenLevelPackage = S.TrimStartAndEnd();
		}
		if (RuleObj->TryGetStringField(TEXT("unrealVenuePresenceToken"), S))
		{
			InOut.UnrealVenuePresenceToken = S.TrimStartAndEnd();
		}
		if (Mode == EFELArenaMode::Karate)
		{
			FString KS;
			if (RuleObj->TryGetStringField(TEXT("karateLabMode"), KS))
			{
				const FString L = KS.TrimStartAndEnd().ToLower();
				if (L == TEXT("matrix_revolutions") || L == TEXT("revolutions_siege") || L == TEXT("revolutions")
					|| L == TEXT("smith_waves") || L == TEXT("matrix_siege") || L == TEXT("dock_siege"))
				{
					InOut.KarateLabMode = EFELKarateLabMode::MatrixRevolutionsSiege;
				}
				else if (L == TEXT("endless") || L == TEXT("agents") || L == TEXT("matrix") || L == TEXT("matrix_endless"))
				{
					InOut.KarateLabMode = EFELKarateLabMode::EndlessAgentWaves;
				}
				else if (L == TEXT("h2h") || L == TEXT("head_to_head") || L == TEXT("storm"))
				{
					InOut.KarateLabMode = EFELKarateLabMode::HeadToHeadStorm;
				}
			}
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
		SN.DunkContestStyleDecayPerSecond = FMath::Clamp(SN.DunkContestStyleDecayPerSecond, 0.05f, 2.5f);
		SN.DunkContestStyleGainPerfect = FMath::Clamp(SN.DunkContestStyleGainPerfect, 1.f, 80.f);
		SN.DunkContestStyleGainGood = FMath::Clamp(SN.DunkContestStyleGainGood, 0.f, 40.f);
		SN.DunkContestStyleLeakPenalty = FMath::Clamp(SN.DunkContestStyleLeakPenalty, 0.f, 40.f);
		SN.DunkContestChainGraceSeconds = FMath::Clamp(SN.DunkContestChainGraceSeconds, 0.5f, 8.f);
		SN.DunkContestMultiplierCapBase = FMath::Clamp(SN.DunkContestMultiplierCapBase, 1.f, 6.f);
		SN.DunkContestMultiplierCapPerPRQPoint = FMath::Clamp(SN.DunkContestMultiplierCapPerPRQPoint, 0.f, 0.06f);
		SN.DunkContestPRQStyleFillBonus = FMath::Clamp(SN.DunkContestPRQStyleFillBonus, 0.f, 1.f);
		SN.StreetJamTrickDecayPerSecond = FMath::Clamp(SN.StreetJamTrickDecayPerSecond, 0.05f, 2.5f);
		SN.StreetJamTrickGainGatherPerfect = FMath::Clamp(SN.StreetJamTrickGainGatherPerfect, 1.f, 60.f);
		SN.StreetJamTrickGainGatherGood = FMath::Clamp(SN.StreetJamTrickGainGatherGood, 0.f, 30.f);
		SN.StreetJamTrickLeakPenalty = FMath::Clamp(SN.StreetJamTrickLeakPenalty, 0.f, 30.f);
		SN.StreetJamGatherChainGraceSeconds = FMath::Clamp(SN.StreetJamGatherChainGraceSeconds, 0.5f, 8.f);
		SN.StreetJamTrickGainOnBucket = FMath::Clamp(SN.StreetJamTrickGainOnBucket, 0.f, 40.f);
		SN.StreetJamBucketChainGraceSeconds = FMath::Clamp(SN.StreetJamBucketChainGraceSeconds, 0.5f, 10.f);
		SN.StreetJamMultiplierCapBase = FMath::Clamp(SN.StreetJamMultiplierCapBase, 1.f, 5.5f);
		SN.StreetJamMultiplierCapPerPRQPoint = FMath::Clamp(SN.StreetJamMultiplierCapPerPRQPoint, 0.f, 0.05f);
		SN.StreetJamPRQTrickFillBonus = FMath::Clamp(SN.StreetJamPRQTrickFillBonus, 0.f, 1.f);
		SN.StreetJamGamebreakerBonusPoints = FMath::Clamp(SN.StreetJamGamebreakerBonusPoints, 0.f, 24.f);
		SN.SwitchTennisExtraConeDeg = FMath::Clamp(SN.SwitchTennisExtraConeDeg, 0.f, 4.f);
		SN.SwitchTennisConeBonusPerPRQDeg = FMath::Clamp(SN.SwitchTennisConeBonusPerPRQDeg, 0.f, 0.05f);
		SN.SwitchVolleyballExtraSpikeMarginMs = FMath::Clamp(SN.SwitchVolleyballExtraSpikeMarginMs, 0.f, 80.f);
		SN.SwitchVolleyballSpikeMarginPerPRQMs = FMath::Clamp(SN.SwitchVolleyballSpikeMarginPerPRQMs, 0.f, 0.4f);
		SN.SwitchCreatorTimingMin = FMath::Clamp(SN.SwitchCreatorTimingMin, 0.75f, 1.f);
		SN.SwitchCreatorTimingMax = FMath::Clamp(SN.SwitchCreatorTimingMax, 1.f, 1.25f);
		SN.SwitchCourtWalkBonusMax = FMath::Clamp(SN.SwitchCourtWalkBonusMax, 0.f, 0.12f);
		SN.KickReturnBaseYardsPerSecond = FMath::Clamp(SN.KickReturnBaseYardsPerSecond, 4.f, 28.f);
		SN.KickReturnPRQSpeedCoef = FMath::Clamp(SN.KickReturnPRQSpeedCoef, 0.f, 1.2f);
		SN.KickReturnPRQDurabilityCoef = FMath::Clamp(SN.KickReturnPRQDurabilityCoef, 0.f, 1.2f);
		SN.KickReturnGaugeFillPerSecond = FMath::Clamp(SN.KickReturnGaugeFillPerSecond, 0.05f, 0.55f);
		SN.KickReturnWaveRamp = FMath::Clamp(SN.KickReturnWaveRamp, 0.f, 0.2f);
		SN.KickReturnTackleDurabilityMult = FMath::Clamp(SN.KickReturnTackleDurabilityMult, 0.5f, 1.f);
		SN.KickReturnTdDurabilityRecover = FMath::Clamp(SN.KickReturnTdDurabilityRecover, 0.f, 0.45f);
		SN.KickReturnGhostOpponentPRQ = FMath::Clamp(SN.KickReturnGhostOpponentPRQ, 40.f, 98.f);
		SN.BoardSportBaseLineScorePerSecond = FMath::Clamp(SN.BoardSportBaseLineScorePerSecond, 0.2f, 8.f);
		SN.BoardSportPRQLineCoef = FMath::Clamp(SN.BoardSportPRQLineCoef, 0.f, 2.f);
		SN.BoardSportTrickGaugeFillPerSecond = FMath::Clamp(SN.BoardSportTrickGaugeFillPerSecond, 0.02f, 0.55f);
		SN.BoardSportPRQTrickCoef = FMath::Clamp(SN.BoardSportPRQTrickCoef, 0.f, 1.2f);
		SN.BoardSportBalanceLeakPerSecond = FMath::Clamp(SN.BoardSportBalanceLeakPerSecond, 0.02f, 0.45f);
		SN.BoardSportPRQBalanceMitigation = FMath::Clamp(SN.BoardSportPRQBalanceMitigation, 0.f, 1.2f);
		SN.BoardSportWipeoutBalanceLoss = FMath::Clamp(SN.BoardSportWipeoutBalanceLoss, 0.f, 1.f);

		if (R.bIsDunkContest)
		{
			R.bStreetJamArcade = false;
		}

		// Parity: dunk slice always uses leakage path in ApplyReadiness (GAMEPLAY_STATUS).
		if (Mode == EFELArenaMode::BasketballDunkContest)
		{
			R.bNeuroKineticLeakageForDunkParity = true;
			R.bIsDunkContest = true;
			R.bStreetJamArcade = false;
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
