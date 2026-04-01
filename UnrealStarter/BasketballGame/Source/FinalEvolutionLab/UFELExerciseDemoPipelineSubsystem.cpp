// Copyright (c) Final Evolution Lab.

#include "UFELExerciseDemoPipelineSubsystem.h"
#include "FinalEvolutionLab.h"
#include "UFELAcademyMocapCatalogSubsystem.h"
#include "UFELAssetRegistrySubsystem.h"
#include "UFELDemoManager.h"
#include "Animation/AnimMontage.h"
#include "Engine/GameInstance.h"

void UFELExerciseDemoPipelineSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	SeedModeToModuleMapping();
}

void UFELExerciseDemoPipelineSubsystem::SeedModeToModuleMapping()
{
	ModeToModuleKey.Add(EFELArenaMode::BasketballHeadToHead, TEXT("mod1"));
	ModeToModuleKey.Add(EFELArenaMode::BasketballDunkContest, TEXT("mod2"));
	ModeToModuleKey.Add(EFELArenaMode::Basketball3v3, TEXT("mod3"));
	ModeToModuleKey.Add(EFELArenaMode::Karate, TEXT("mod4"));
	ModeToModuleKey.Add(EFELArenaMode::Baseball, TEXT("mod5"));
	ModeToModuleKey.Add(EFELArenaMode::Football, TEXT("mod6"));
	ModeToModuleKey.Add(EFELArenaMode::Soccer, TEXT("mod7"));
	ModeToModuleKey.Add(EFELArenaMode::Golf, TEXT("mod8"));
	ModeToModuleKey.Add(EFELArenaMode::Tennis, TEXT("mod9"));
	ModeToModuleKey.Add(EFELArenaMode::Volleyball, TEXT("mod10"));
	ModeToModuleKey.Add(EFELArenaMode::Gymnastics, TEXT("mod11"));
	ModeToModuleKey.Add(EFELArenaMode::BrainBrawl, TEXT("mod12"));

	ModeToExerciseName.Add(EFELArenaMode::BasketballHeadToHead, TEXT("Bio-Electric Freeway — Triple Threat Stance"));
	ModeToExerciseName.Add(EFELArenaMode::BasketballDunkContest, TEXT("Vertical Velocity Takeoff — Dunk Approach"));
	ModeToExerciseName.Add(EFELArenaMode::Basketball3v3, TEXT("Lateral Shuffle — Defensive Slide"));
	ModeToExerciseName.Add(EFELArenaMode::Karate, TEXT("Neural Tempest — Spiral Strike Sequence"));
	ModeToExerciseName.Add(EFELArenaMode::Baseball, TEXT("Rotational Power — Bat Swing Kinetic Chain"));
	ModeToExerciseName.Add(EFELArenaMode::Football, TEXT("Isometric Split Stance Wall Push — NMS Reset"));
	ModeToExerciseName.Add(EFELArenaMode::Soccer, TEXT("Driven Shot Mechanics — Curve Stabilization"));
	ModeToExerciseName.Add(EFELArenaMode::Golf, TEXT("Downswing Plane — Hip Hinge Sequence"));
	ModeToExerciseName.Add(EFELArenaMode::Tennis, TEXT("Serve Toss Kinetic Chain — Ace Cone Pattern"));
	ModeToExerciseName.Add(EFELArenaMode::Volleyball, TEXT("Spike Approach — Penultimate Step Timing"));
	ModeToExerciseName.Add(EFELArenaMode::Gymnastics, TEXT("Floor Routine Entry — Tumbling Run Sequence"));
	ModeToExerciseName.Add(EFELArenaMode::BrainBrawl, TEXT("Cloud Cortex — Neuro Academy Integration"));
	ModeToModuleKey.Add(EFELArenaMode::Surfing, TEXT("mod13"));
	ModeToModuleKey.Add(EFELArenaMode::Skateboarding, TEXT("mod14"));
	ModeToModuleKey.Add(EFELArenaMode::Snowboarding, TEXT("mod15"));
	ModeToExerciseName.Add(EFELArenaMode::Surfing, TEXT("Line Balance — Swell Mitigation Stance"));
	ModeToExerciseName.Add(EFELArenaMode::Skateboarding, TEXT("Line Stability — Approach Plate Load"));
	ModeToExerciseName.Add(EFELArenaMode::Snowboarding, TEXT("Edge Grip — Carve Tension Sequence"));
}

FString UFELExerciseDemoPipelineSubsystem::GetModuleKeyForArenaMode(const EFELArenaMode Mode) const
{
	if (Mode == EFELArenaMode::MarketBrowse || Mode == EFELArenaMode::Unknown)
	{
		return FString();
	}
	if (const FString* Key = ModeToModuleKey.Find(Mode))
	{
		return *Key;
	}
	return TEXT("mod1");
}

FString UFELExerciseDemoPipelineSubsystem::GetExerciseNameForArenaMode(const EFELArenaMode Mode) const
{
	if (const FString* Name = ModeToExerciseName.Find(Mode))
	{
		return *Name;
	}
	return TEXT("Perfect Form Demonstration");
}

void UFELExerciseDemoPipelineSubsystem::PreloadExerciseDemoForMode(const EFELArenaMode Mode)
{
	const FString ModuleKey = GetModuleKeyForArenaMode(Mode);
	if (ModuleKey.IsEmpty())
	{
		return;
	}
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELAssetRegistrySubsystem* Registry = GI->GetSubsystem<UFELAssetRegistrySubsystem>())
		{
			if (TSharedPtr<FStreamableHandle>* Existing = ActiveLoadHandles.Find(Mode))
			{
				if (Existing->IsValid())
				{
					return;
				}
			}

			TSharedPtr<FStreamableHandle> Handle = Registry->RequestAsyncDemonstrationMontage(
				ModuleKey,
				FStreamableDelegate::CreateUObject(this, &UFELExerciseDemoPipelineSubsystem::OnMontageLoaded, Mode));

			if (Handle.IsValid())
			{
				ActiveLoadHandles.Add(Mode, Handle);
			}
		}
	}
}

void UFELExerciseDemoPipelineSubsystem::OnMontageLoaded(const EFELArenaMode Mode)
{
	ActiveLoadHandles.Remove(Mode);
}

UAnimMontage* UFELExerciseDemoPipelineSubsystem::GetCachedMontageForMode(const EFELArenaMode Mode)
{
	const FString ModuleKey = GetModuleKeyForArenaMode(Mode);
	if (ModuleKey.IsEmpty())
	{
		return nullptr;
	}
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELAssetRegistrySubsystem* Registry = GI->GetSubsystem<UFELAssetRegistrySubsystem>())
		{
			return Registry->ResolveModuleDemonstrationMontage(ModuleKey, false);
		}
	}
	return nullptr;
}

void UFELExerciseDemoPipelineSubsystem::TriggerExerciseDemoForMode(
	const EFELArenaMode Mode,
	UFELDemoManager* DemoManager,
	const float PRQ0to100)
{
	if (!DemoManager)
	{
		return;
	}

	UAnimMontage* DemoMontage = nullptr;
	if (UGameInstance* const GI = GetGameInstance())
	{
		if (UFELAcademyMocapCatalogSubsystem* const Cat = GI->GetSubsystem<UFELAcademyMocapCatalogSubsystem>())
		{
			DemoMontage = Cat->ResolvePerfectFormMontage(Mode, true);
		}
		if (!DemoMontage)
		{
			const FString ModuleKey = GetModuleKeyForArenaMode(Mode);
			if (!ModuleKey.IsEmpty())
			{
				if (UFELAssetRegistrySubsystem* const Reg = GI->GetSubsystem<UFELAssetRegistrySubsystem>())
				{
					DemoMontage = Reg->ResolveModuleDemonstrationMontage(ModuleKey, true);
				}
			}
		}
	}

#if !UE_BUILD_SHIPPING
	if (!DemoMontage && Mode != EFELArenaMode::MarketBrowse && Mode != EFELArenaMode::Unknown)
	{
		const FString Mk = GetModuleKeyForArenaMode(Mode);
		if (!Mk.IsEmpty())
		{
			UE_LOG(LogFinalEvolutionLab, Verbose,
				TEXT("TriggerExerciseDemoForMode: no montage resolved for arena mode (module key '%s'). Assign PerfectForm montage or cook /Game/FEL/DeepMotion/Demo_* assets."),
				*Mk);
		}
	}
#endif

	PreloadExerciseDemoForMode(Mode);
	DemoManager->TriggerExerciseDemo(DemoMontage, PRQ0to100);
}
