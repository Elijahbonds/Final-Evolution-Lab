// Copyright (c) Final Evolution Lab.

#include "FELClinicalUIPolicy.h"
#include "Dom/JsonObject.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"

namespace
{
	static const TCHAR* PolicyJsonRelative = TEXT("FEL/Config/FEL_ClinicalUIPolicy.json");
}

bool FELClinicalUIPolicyLoader::TryLoadFromContent(FFELClinicalUIPolicy& Out, FString* OutError)
{
	const FString Path = FPaths::ProjectContentDir() / PolicyJsonRelative;
	if (!FPaths::FileExists(Path))
	{
		return true;
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
	TSharedPtr<FJsonObject> Root;
	const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Json);
	if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
	{
		if (OutError)
		{
			*OutError = TEXT("Invalid JSON in FEL_ClinicalUIPolicy.json");
		}
		return false;
	}
	double Ver = static_cast<double>(Out.Version);
	if (Root->TryGetNumberField(TEXT("version"), Ver))
	{
		Out.Version = static_cast<int32>(Ver);
	}
	(void)Root->TryGetBoolField(TEXT("showLabOnboardingFirstRun"), Out.bShowLabOnboardingFirstRun);
	(void)Root->TryGetBoolField(TEXT("showRetailClinicalCopy"), Out.bShowRetailClinicalCopy);
	(void)Root->TryGetStringField(TEXT("labOnboardingBodyOverride"), Out.LabOnboardingBodyOverride);
	(void)Root->TryGetStringField(TEXT("retailSplashClinicalExtra"), Out.RetailSplashClinicalExtra);
	(void)Root->TryGetStringField(TEXT("retailMenuClinicalFootnote"), Out.RetailMenuClinicalFootnote);
	return true;
}
