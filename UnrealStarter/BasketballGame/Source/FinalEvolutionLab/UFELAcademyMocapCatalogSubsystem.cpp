// Copyright (c) Final Evolution Lab.

#include "UFELAcademyMocapCatalogSubsystem.h"
#include "UFELAssetRegistrySubsystem.h"
#include "Animation/AnimMontage.h"
#include "Math/UnrealMathUtility.h"

UFELAcademyMocapCatalogSubsystem::UFELAcademyMocapCatalogSubsystem()
{
	if (HasAnyFlags(RF_ClassDefaultObject))
	{
		const int32 Max = static_cast<int32>(EFELDunkMocapArchetype::EFELDunkMocapArchetype_MAX);
		for (int32 i = 0; i < Max; ++i)
		{
			DunkMontagesByArchetype.FindOrAdd(static_cast<EFELDunkMocapArchetype>(i));
		}
	}
}

UAnimMontage* UFELAcademyMocapCatalogSubsystem::ResolveSoftMontageRef(
	const TSoftObjectPtr<UAnimMontage>& Ref,
	const bool bLoadSynchronously)
{
	if (Ref.IsNull())
	{
		return nullptr;
	}
	if (bLoadSynchronously)
	{
		return Ref.LoadSynchronous();
	}
	return Ref.Get();
}

UAnimMontage* UFELAcademyMocapCatalogSubsystem::ResolveMontageForModule(const FString& ModuleKey, bool bLoadSynchronously)
{
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELAssetRegistrySubsystem* Reg = GI->GetSubsystem<UFELAssetRegistrySubsystem>())
		{
			return Reg->ResolveModuleDemonstrationMontage(ModuleKey, bLoadSynchronously);
		}
	}
	return nullptr;
}

bool UFELAcademyMocapCatalogSubsystem::HasModuleMontage(const FString& ModuleKey)
{
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELAssetRegistrySubsystem* Reg = GI->GetSubsystem<UFELAssetRegistrySubsystem>())
		{
			return Reg->HasModuleDemonstrationMontage(ModuleKey);
		}
	}
	return false;
}

UAnimMontage* UFELAcademyMocapCatalogSubsystem::ResolvePerfectFormMontage(const EFELArenaMode Mode, const bool bLoadSynchronously)
{
	const TSoftObjectPtr<UAnimMontage>* Found = PerfectFormMontageByArenaMode.Find(Mode);
	if (!Found || Found->IsNull())
	{
		return nullptr;
	}
	if (bLoadSynchronously)
	{
		return Found->LoadSynchronous();
	}
	return Found->Get();
}

UAnimMontage* UFELAcademyMocapCatalogSubsystem::ResolveDunkerReferenceMontage(
	const FName DunkerId,
	const int32 ClipIndex,
	const bool bLoadSynchronously)
{
	const TArray<TSoftObjectPtr<UAnimMontage>>* Arr = nullptr;
	const FName Id = DunkerId;
	if (Id == FName(TEXT("ElijahBonds")) || Id == FName(TEXT("Bonds")))
	{
		Arr = &ElijahBondsDunkReferenceMontages;
	}
	else if (Id == FName(TEXT("AmirSmith")) || Id == FName(TEXT("Smith")))
	{
		Arr = &AmirSmithDunkReferenceMontages;
	}
	else
	{
		const FString IdStr = Id.ToString();
		for (const FFELNamedDunkerMocapList& Row : AdditionalNamedDunkerLists)
		{
			if (Row.DunkerSlug.IsNone())
			{
				continue;
			}
			if (Row.DunkerSlug == Id || Row.DunkerSlug.ToString().Equals(IdStr, ESearchCase::IgnoreCase))
			{
				Arr = &Row.Montages;
				break;
			}
		}
	}
	if (!Arr || !Arr->IsValidIndex(ClipIndex))
	{
		return nullptr;
	}
	return ResolveSoftMontageRef((*Arr)[ClipIndex], bLoadSynchronously);
}

UAnimMontage* UFELAcademyMocapCatalogSubsystem::ResolveDunkArchetypeMontage(
	const EFELDunkMocapArchetype Archetype,
	const int32 ClipIndex,
	const bool bLoadSynchronously)
{
	const FFELDunkArchetypeClipBucket* Bucket = DunkMontagesByArchetype.Find(Archetype);
	if (!Bucket || !Bucket->Montages.IsValidIndex(ClipIndex))
	{
		return nullptr;
	}
	return ResolveSoftMontageRef(Bucket->Montages[ClipIndex], bLoadSynchronously);
}

UAnimMontage* UFELAcademyMocapCatalogSubsystem::ResolveRandomDunkMontageForArchetype(
	const EFELDunkMocapArchetype Archetype,
	const int32 RandomSeed,
	const bool bLoadSynchronously)
{
	const FFELDunkArchetypeClipBucket* Bucket = DunkMontagesByArchetype.Find(Archetype);
	if (!Bucket || Bucket->Montages.Num() == 0)
	{
		Bucket = DunkMontagesByArchetype.Find(EFELDunkMocapArchetype::Generic);
	}
	if (!Bucket || Bucket->Montages.Num() == 0)
	{
		return nullptr;
	}
	int32 Idx = 0;
	if (Bucket->Montages.Num() > 1)
	{
		Idx = FMath::Abs(RandomSeed) % Bucket->Montages.Num();
	}
	return ResolveSoftMontageRef(Bucket->Montages[Idx], bLoadSynchronously);
}

int32 UFELAcademyMocapCatalogSubsystem::GetDunkArchetypeClipCount(const EFELDunkMocapArchetype Archetype) const
{
	const FFELDunkArchetypeClipBucket* Bucket = DunkMontagesByArchetype.Find(Archetype);
	return Bucket ? Bucket->Montages.Num() : 0;
}
