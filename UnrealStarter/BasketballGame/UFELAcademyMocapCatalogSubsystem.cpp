// Copyright (c) Final Evolution Lab.

#include "UFELAcademyMocapCatalogSubsystem.h"
#include "UFELAssetRegistrySubsystem.h"
#include "Animation/AnimMontage.h"

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
