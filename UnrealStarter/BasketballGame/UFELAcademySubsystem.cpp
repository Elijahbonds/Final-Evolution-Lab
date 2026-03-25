// Copyright (c) Final Evolution Lab.

#include "UFELAcademySubsystem.h"
#include "FELAcademyPrescription.h"
#include "FELNativeBridge.h"

void UFELAcademySubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
}

void UFELAcademySubsystem::EnsureRegistryBuilt() const
{
	if (bRegistryBuilt)
	{
		return;
	}
	bRegistryBuilt = true;
	ModuleRegistry.Reset();

	auto Add = [&](EFELAcademyModuleId E, const TCHAR* Key, const TCHAR* Title, const TCHAR* Cat)
	{
		FFELAcademyModuleEntry R;
		R.ModuleIdEnum = E;
		R.ModuleKey = Key;
		R.Title = FText::FromString(Title);
		R.CategoryTag = FText::FromString(Cat);
		ModuleRegistry.Add(R);
	};

	Add(EFELAcademyModuleId::Mod1_CNSFreeway, TEXT("mod1"), TEXT("The Bio-Electric Freeway"), TEXT("CNS / Tensegrity"));
	Add(EFELAcademyModuleId::Mod2_SFMAFMS, TEXT("mod2"), TEXT("The Internal GPS"), TEXT("SFMA / FMS"));
	Add(EFELAcademyModuleId::Mod3_IAP, TEXT("mod3"), TEXT("The Piston"), TEXT("IAP"));
	Add(EFELAcademyModuleId::Mod4_MovementSnacks, TEXT("mod4"), TEXT("The 24/7 Athlete"), TEXT("Movement Snacks"));
	Add(EFELAcademyModuleId::Mod5_Slings, TEXT("mod5"), TEXT("Anatomy of the Sling"), TEXT("Slings"));
	Add(EFELAcademyModuleId::Mod6_Correctives, TEXT("mod6"), TEXT("Clearing the Path"), TEXT("NMS Correctives"));
	Add(EFELAcademyModuleId::Mod7_PJFTBB, TEXT("mod7"), TEXT("The Loaded Spring"), TEXT("PJF / TBB"));
	Add(EFELAcademyModuleId::Mod8_RFDPenultimate, TEXT("mod8"), TEXT("The Rhythmic Penultimate"), TEXT("RFD"));
	Add(EFELAcademyModuleId::Mod9_Plyos, TEXT("mod9"), TEXT("The Elastic Engine"), TEXT("Plyos"));
	Add(EFELAcademyModuleId::Mod10_FlightBlueprint, TEXT("mod10"), TEXT("The Flight Blueprint"), TEXT("Programming"));
	Add(EFELAcademyModuleId::Mod11_Nutrition, TEXT("mod11"), TEXT("The Bio-Molecular Fuel"), TEXT("Nutrition"));
	Add(EFELAcademyModuleId::Mod12_SupplementSling, TEXT("mod12"), TEXT("Supplementing the Sling"), TEXT("PJF / Fuel"));
}

void UFELAcademySubsystem::GetAllModules(TArray<FFELAcademyModuleEntry>& OutModules) const
{
	EnsureRegistryBuilt();
	OutModules = ModuleRegistry;
}

void UFELAcademySubsystem::BuildPrescriptionFromKineticHeat(double AnkleHeat01, double KneeHeat01, double HipHeat01, FFELAcademyPrescriptionResult& OutResult) const
{
	FELAcademyPrescription::ComputePrescription(AnkleHeat01, KneeHeat01, HipHeat01, OutResult);
}

void UFELAcademySubsystem::RecordSessionModuleCompletion(const FString& ModuleKey, int32 EvolutionShardsForModule)
{
	if (ModuleKey.IsEmpty() || SessionAcademyModules.Contains(ModuleKey))
	{
		return;
	}
	SessionAcademyModules.Add(ModuleKey);
	SessionAcademyShardTotal += FMath::Max(0, EvolutionShardsForModule);
	FELNativeBridge::NotifyAcademyModuleCompletionPulse();
}

void UFELAcademySubsystem::GetSessionAcademyProgress(TArray<FString>& OutCompletedModuleKeys, int32& OutEvolutionShardsTotal) const
{
	OutCompletedModuleKeys = SessionAcademyModules.Array();
	OutCompletedModuleKeys.Sort();
	OutEvolutionShardsTotal = SessionAcademyShardTotal;
}

void UFELAcademySubsystem::ClearSessionAcademyProgressAfterExport()
{
	SessionAcademyModules.Reset();
	SessionAcademyShardTotal = 0;
}
