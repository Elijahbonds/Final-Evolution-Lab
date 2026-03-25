// Copyright (c) Final Evolution Lab.

#include "FELAvatarLeakHighlightComponent.h"

void UFELAvatarLeakHighlightComponent::SetLeakHighlightMask(bool bAnkle, bool bKnee, bool bHip)
{
	ApplyPostProcessOutlineMask(bAnkle, bKnee, bHip);
}

void UFELAvatarLeakHighlightComponent::PlayPerfectVsLeakyComparison_Implementation(int32 JointIndex, float DurationSeconds)
{
	(void)JointIndex;
	(void)DurationSeconds;
}
