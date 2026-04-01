// Copyright (c) Final Evolution Lab.
// Optional JSON policy for clinical / fitness UI copy and first-run gating (Phase 7).

#pragma once

#include "CoreMinimal.h"

struct FFELClinicalUIPolicy
{
	int32 Version = 1;

	/** When false, first-run lab onboarding widget is never shown (match starts immediately). */
	bool bShowLabOnboardingFirstRun = true;

	/** When false, extra clinical footers on the retail splash/menu are skipped. */
	bool bShowRetailClinicalCopy = true;

	/** If non-empty, replaces default `InitializeLabOnboarding` body text (plain string, \\n newlines). */
	FString LabOnboardingBodyOverride;

	/** Appended to splash body when `bShowRetailClinicalCopy` is true. */
	FString RetailSplashClinicalExtra;

	/** Appended to main menu body when `bShowRetailClinicalCopy` is true. */
	FString RetailMenuClinicalFootnote;
};

namespace FELClinicalUIPolicyLoader
{
	/** Loads `Content/FEL/Config/FEL_ClinicalUIPolicy.json` if present; otherwise leaves `Out` at defaults. Returns false on parse error (defaults still valid). */
	bool TryLoadFromContent(FFELClinicalUIPolicy& Out, FString* OutError = nullptr);
}
