// Copyright (c) Final Evolution Lab.

#include "FELReadinessIO.h"
#include "FELArenaModeDefinitions.h"
#include "FELDigitalTwinVenuePaths.h"
#include "FELPlatformPaths.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Engine/World.h"
#include "Engine/PostProcessVolume.h"
#include "Kismet/GameplayStatics.h"
#include "FELCameraCompatibility.h"

// UE 5.7: If you branched code that used `FMinimalViewInfo::POV`, replace with flattened fields from
// `PlayerCameraManager->GetCameraCacheView()` — use `.Location`, `.Rotation`, `.FOV` (see FELCameraCompatibility.h).
// Example: `const FVector Loc = FELCameraCompatUE57::GetCameraCacheLocation(PCM);`

bool FELReadinessIO::ParseSnapshotJsonString(const FString& JsonStr, FFELReadinessSnapshot& Out, FString* OutError, UWorld* WorldForTravel, bool* OutIssuedVenueTravel)
{
	TSharedPtr<FJsonObject> Root;
	const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonStr);
	if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
	{
		if (OutError)
		{
			*OutError = TEXT("Invalid JSON");
		}
		return false;
	}

	auto GetD = [&](const TCHAR* Key, double Default) -> double
	{
		double V = Default;
		if (Root->TryGetNumberField(Key, V) && FMath::IsFinite(V))
		{
			return V;
		}
		return Default;
	};

	Out.EfficiencyScore = GetD(TEXT("efficiencyScore"), 0.0);
	Out.PRQScore = GetD(TEXT("prqScore"), 75.0);
	Out.ReadinessScore = GetD(TEXT("readinessScore"), 0.0);
	Out.VerticalPotential = GetD(TEXT("verticalPotential"), 0.0);
	Out.NeuralDrive = GetD(TEXT("neuralDrive"), 0.0);
	Out.PopForce = GetD(TEXT("popForce"), 0.0);
	Out.VerticalEstimateInches = GetD(TEXT("verticalEstimateInches"), 0.0);
	Out.HangTimeScale = GetD(TEXT("hangTimeScale"), 1.0);
	Out.KineticLeakageMultiplier = GetD(TEXT("kineticLeakageMultiplier"), 1.0);
	FString Outfit = TEXT("standard");
	(void)Root->TryGetStringField(TEXT("currentOutfit"), Outfit);
	Out.CurrentOutfit = Outfit.IsEmpty() ? TEXT("standard") : Outfit;

	// Canonical Swift ids: `basketball_h2h`, `basketball_dunk` (aliases `dunk_contest` normalized in `FELArenaModeFromSwiftId`).
	FString ActiveMode = TEXT("basketball_h2h");
	(void)Root->TryGetStringField(TEXT("active_mode"), ActiveMode);
	Out.ActiveArenaMode = ActiveMode.IsEmpty() ? TEXT("basketball_h2h") : ActiveMode;

	FString MoveGrade;
	if (Root->TryGetStringField(TEXT("movementGrade"), MoveGrade))
	{
		Out.MovementGrade = MoveGrade;
	}
	(void)Root->TryGetNumberField(TEXT("flightTimeSeconds"), Out.FlightTimeSeconds);
	(void)Root->TryGetBoolField(TEXT("isPrimed"), Out.bAthletePrimed);
	(void)Root->TryGetNumberField(TEXT("ankleKineticHeat"), Out.KineticHeatAnkle);
	(void)Root->TryGetNumberField(TEXT("kneeKineticHeat"), Out.KineticHeatKnee);
	(void)Root->TryGetNumberField(TEXT("hipKineticHeat"), Out.KineticHeatHip);
	Out.KineticHeatAnkle = FMath::Clamp(Out.KineticHeatAnkle, 0.0, 1.0);
	Out.KineticHeatKnee = FMath::Clamp(Out.KineticHeatKnee, 0.0, 1.0);
	Out.KineticHeatHip = FMath::Clamp(Out.KineticHeatHip, 0.0, 1.0);

	double PlyosBonus = 0.0;
	(void)Root->TryGetNumberField(TEXT("academyPlyosMasteryBonus"), PlyosBonus);
	Out.AcademyPlyosMasteryBonus = FMath::Clamp(PlyosBonus, 0.0, 0.25);

	FString NMLogo;
	if (Root->TryGetStringField(TEXT("neuroMechanicLogoTexture"), NMLogo))
	{
		Out.NeuroMechanicLogoTexturePath = NMLogo;
	}
	FString BBLogo;
	if (Root->TryGetStringField(TEXT("bondsBounceLogoTexture"), BBLogo))
	{
		Out.BondsBounceLogoTexturePath = BBLogo;
	}
	const TArray<TSharedPtr<FJsonValue>>* CardArr = nullptr;
	if (Root->TryGetArrayField(TEXT("creatorCardTextures"), CardArr) && CardArr)
	{
		Out.CreatorCardTexturePaths.Reset();
		for (const TSharedPtr<FJsonValue>& V : *CardArr)
		{
			if (!V.IsValid())
			{
				continue;
			}
			const FString S = V->AsString();
			if (!S.IsEmpty())
			{
				Out.CreatorCardTexturePaths.Add(S);
				if (Out.CreatorCardTexturePaths.Num() >= 3)
				{
					break;
				}
			}
		}
	}

	bool TwinBirth = false;
	if (Root->TryGetBoolField(TEXT("playTwinBirthCinematicOnce"), TwinBirth))
	{
		Out.bPlayTwinBirthCinematicOnce = TwinBirth;
	}
	bool SfmaPass = true;
	// Swift `FelReadinessSnapshotExport` emits camelCase; accept snake_case alias for external tooling.
	if (Root->TryGetBoolField(TEXT("sfmaMultiSegmentalRotationPassed"), SfmaPass) ||
		Root->TryGetBoolField(TEXT("sfma_multi_segmental_rotation_passed"), SfmaPass))
	{
		Out.bSFMASpiralRotationScreenPass = SfmaPass;
	}
	FString WelcomeToast;
	if (Root->TryGetStringField(TEXT("labWelcomeToast"), WelcomeToast) && !WelcomeToast.IsEmpty())
	{
		Out.LabWelcomeToast = WelcomeToast;
	}

	FString JerseyTex;
	if (Root->TryGetStringField(TEXT("jerseyTexturePath"), JerseyTex) && !JerseyTex.IsEmpty())
	{
		Out.JerseyTexturePath = JerseyTex;
	}
	FString ShoeTex;
	if (Root->TryGetStringField(TEXT("shoeTexturePath"), ShoeTex) && !ShoeTex.IsEmpty())
	{
		Out.ShoeTexturePath = ShoeTex;
	}

	(void)Root->TryGetNumberField(TEXT("gearMotionWarpMultiplier"), Out.GearMotionWarpMultiplier);
	(void)Root->TryGetNumberField(TEXT("gearJumpVelocityMultiplier"), Out.GearJumpVelocityMultiplier);
	Out.GearMotionWarpMultiplier = FMath::Clamp(Out.GearMotionWarpMultiplier, 1.0, 1.06);
	Out.GearJumpVelocityMultiplier = FMath::Clamp(Out.GearJumpVelocityMultiplier, 1.0, 1.06);

	FString StoodCard;
	if (Root->TryGetStringField(TEXT("stoodCreatorCardId"), StoodCard))
	{
		Out.StoodCreatorCardId = StoodCard;
	}
	(void)Root->TryGetNumberField(TEXT("neuroFlowIntensityScale"), Out.NeuroFlowIntensityScale);
	Out.NeuroFlowIntensityScale = FMath::Clamp(Out.NeuroFlowIntensityScale, 1.0, 1.2);

	FString TraitLine;
	if (Root->TryGetStringField(TEXT("stoodCreatorCardTraitLine"), TraitLine))
	{
		Out.StoodCreatorCardTraitLine = TraitLine;
	}

	(void)Root->TryGetNumberField(TEXT("stoodCardJumpScale"), Out.StoodCardJumpScale);
	(void)Root->TryGetNumberField(TEXT("stoodCardNeuralDriveAlpha"), Out.StoodCardNeuralDriveAlpha);
	Out.StoodCardJumpScale = FMath::Clamp(Out.StoodCardJumpScale, 1.0, 1.12);
	Out.StoodCardNeuralDriveAlpha = FMath::Clamp(Out.StoodCardNeuralDriveAlpha, 1.0, 1.15);

	FString Tier;
	if (Root->TryGetStringField(TEXT("stoodCardTier"), Tier) && !Tier.IsEmpty())
	{
		Out.StoodCardTier = Tier;
	}

	FString SigTraitId;
	if (Root->TryGetStringField(TEXT("signature_trait_id"), SigTraitId) && !SigTraitId.IsEmpty())
	{
		Out.SignatureTrait = FEL_ParseSignatureTraitId(SigTraitId);
	}

	Out.AvatarHeightScale = GetD(TEXT("avatarHeightScale"), 1.0);
	Out.AvatarWeightScale = GetD(TEXT("avatarWeightScale"), 1.0);
	Out.AvatarHeightScale = FMath::Clamp(Out.AvatarHeightScale, 0.65, 1.35);
	Out.AvatarWeightScale = FMath::Clamp(Out.AvatarWeightScale, 0.65, 1.35);

	Out.PRQScore = FMath::Clamp(Out.PRQScore, 0.0, 100.0);
	Out.HangTimeScale = FMath::Clamp(Out.HangTimeScale, 0.5, 1.25);
	Out.KineticLeakageMultiplier = FMath::Clamp(Out.KineticLeakageMultiplier, 0.45, 1.0);

	if (OutIssuedVenueTravel)
	{
		*OutIssuedVenueTravel = false;
	}
	if (WorldForTravel)
	{
		const bool bTraveled = TryMandatoryVenueTravelForActiveMode(WorldForTravel, Out);
		if (OutIssuedVenueTravel)
		{
			*OutIssuedVenueTravel = bTraveled;
		}
	}
	return true;
}

bool FELReadinessIO::TryMandatoryVenueTravelForActiveMode(UWorld* World, const FFELReadinessSnapshot& Snap)
{
	if (!World || !World->IsGameWorld())
	{
		UE_LOG(LogTemp, Warning, TEXT("FELReadiness: TryMandatoryVenueTravel — no game world (viewport may stay uninitialized)."));
		return false;
	}
	if (Snap.ActiveArenaMode.IsEmpty())
	{
		return false;
	}
	const EFELArenaMode Mode = FELArenaModeFromSwiftId(Snap.ActiveArenaMode);
	FName TargetLevel;
	const FString Current = UGameplayStatics::GetCurrentLevelName(World, true);

	switch (Mode)
	{
	case EFELArenaMode::BasketballHeadToHead:
	case EFELArenaMode::BasketballDunkContest:
	case EFELArenaMode::Basketball3v3:
		if (Current.Contains(TEXT("VeniceBeach")) || Current.Contains(TEXT("VeniceBeach_Arena")))
		{
			UE_LOG(LogTemp, Log, TEXT("FELReadiness: already on Venice (current='%s'); skip OpenLevel."), *Current);
			return false;
		}
		// Cooked .umap must exist at this soft path (see CONFIG_DefaultGame_FEL.ini MapsToCook + FELDigitalTwinVenuePaths).
		TargetLevel = FName(FELDigitalTwinVenuePaths::VeniceBeachArena);
		break;
	case EFELArenaMode::Karate:
		if (Current.Contains(TEXT("Dojo_Stadium")) || Current.Contains(TEXT("Dojo")))
		{
			UE_LOG(LogTemp, Log, TEXT("FELReadiness: already on Dojo (current='%s'); skip OpenLevel."), *Current);
			return false;
		}
		TargetLevel = FName(FELDigitalTwinVenuePaths::DojoStadium);
		break;
	case EFELArenaMode::MarketBrowse:
		// Gold Master: `active_mode` market_browse → `/Game/FEL/Venues/Luma_Venice_Shop` (Luma Venice Shop; see CONFIG_DefaultGame_FEL.ini MapsToCook).
		if (Current.Contains(TEXT("SovereignShop")) || Current.Contains(TEXT("L_SovereignShop_Luma"))
			|| Current.Contains(TEXT("Luma_Venice_Shop")))
		{
			return false;
		}
		TargetLevel = FName(FELDigitalTwinVenuePaths::LumaVeniceShop);
		UE_LOG(LogTemp, Display, TEXT("FELReadiness: market_browse → OpenLevel %s"), FELDigitalTwinVenuePaths::LumaVeniceShop);
		break;
	default:
		UE_LOG(LogTemp, Verbose, TEXT("FELReadiness: mode not mapped to venue travel (active_mode='%s')."), *Snap.ActiveArenaMode);
		return false;
	}

	UE_LOG(LogTemp, Warning, TEXT("FELReadiness: OpenLevel — active_mode='%s' current='%s' target=%s (if load fails, confirm .umap is cooked under this path)."),
		*Snap.ActiveArenaMode,
		*Current,
		*TargetLevel.ToString());
	UGameplayStatics::OpenLevel(World, TargetLevel);
	return true;
}

void FELReadinessIO::ApplyNeuroFlowPostProcessFromSnapshot(UWorld* World, const FFELReadinessSnapshot& Snap)
{
	if (!World || !World->IsGameWorld())
	{
		return;
	}
	const float Prq01 = FMath::Clamp(static_cast<float>(Snap.PRQScore) / 100.f, 0.f, 1.f);
	TArray<AActor*> Found;
	UGameplayStatics::GetAllActorsOfClass(World, APostProcessVolume::StaticClass(), Found);
	for (AActor* A : Found)
	{
		if (!A || !A->ActorHasTag(FName(TEXT("FEL_NeuroFlow"))))
		{
			continue;
		}
		APostProcessVolume* PP = Cast<APostProcessVolume>(A);
		if (!PP)
		{
			continue;
		}
		FPostProcessSettings& S = PP->Settings;
		S.bOverride_BloomIntensity = true;
		S.BloomIntensity = FMath::Lerp(0.65f, 2.2f, Prq01);
		S.bOverride_VignetteIntensity = true;
		S.VignetteIntensity = FMath::Lerp(0.12f, 0.52f, Prq01);
		PP->BlendWeight = FMath::Lerp(0.35f, 1.f, Prq01);
		break;
	}
}

bool FELReadinessIO::TryLoadSnapshot(FFELReadinessSnapshot& Out, FString* OutError)
{
	TArray<FString> Paths;
	FELPlatformPaths::GetReadinessSnapshotCandidatePaths(Paths);

	for (const FString& Path : Paths)
	{
		if (!FPaths::FileExists(Path))
		{
			continue;
		}
		FString Json;
		if (!FFileHelper::LoadFileToString(Json, *Path))
		{
			if (OutError)
			{
				*OutError = FString::Printf(TEXT("Could not read %s"), *Path);
			}
			return false;
		}
		return ParseSnapshotJsonString(Json, Out, OutError);
	}

	if (OutError)
	{
		*OutError = TEXT("No readiness_snapshot.json (checked Documents/FEL, Saved/FEL, Content/FEL/Config)");
	}
	return false;
}

void FELReadinessIO::ApplySystemScanOptics(APlayerCameraManager* PCM)
{
	if (!PCM) return;
	// Use FELCameraCompatibility.h globally in FELReadinessIO.cpp to ensure System Scan optics are identical.
	const FVector Loc = FELCameraCompatUE57::GetCameraCacheLocation(PCM);
	const FRotator Rot = FELCameraCompatUE57::GetCameraCacheRotation(PCM);
	const float CurrentFOV = FELCameraCompatUE57::GetCameraCacheFOV(PCM);
	
	// Enforce default 90 FOV for System Scan parity across iOS, Mac, Switch, PS5
	PCM->SetFOV(90.f);
}
