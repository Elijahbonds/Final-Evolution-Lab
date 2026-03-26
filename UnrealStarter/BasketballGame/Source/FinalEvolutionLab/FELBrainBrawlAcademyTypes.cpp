// Copyright (c) Final Evolution Lab.

#include "FELBrainBrawlAcademyTypes.h"

EFELBrainBrawlCurriculumDomain FEL_ParseBrainBrawlDomain(const FString& Name)
{
	FString L = Name;
	L.TrimStartAndEndInline();
	L.ToLowerInline();
	if (L == TEXT("compute"))
	{
		return EFELBrainBrawlCurriculumDomain::Compute;
	}
	if (L == TEXT("identify"))
	{
		return EFELBrainBrawlCurriculumDomain::Identify;
	}
	if (L == TEXT("memorize"))
	{
		return EFELBrainBrawlCurriculumDomain::Memorize;
	}
	if (L == TEXT("visualize"))
	{
		return EFELBrainBrawlCurriculumDomain::Visualize;
	}
	return EFELBrainBrawlCurriculumDomain::Analyze;
}
