// Copyright (c) Final Evolution Lab.
// Attach to the Athlete Hub avatar; implement outline + comparison in Blueprint (post-process material or mesh overlay).

#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "FELAvatarLeakHighlightComponent.generated.h"

UCLASS(ClassGroup = (Custom), meta = (BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELAvatarLeakHighlightComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	/** Drive stencil / custom depth mask from scan heat (Blueprint: post-process outline per joint). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Decoder")
	void SetLeakHighlightMask(bool bAnkle, bool bKnee, bool bHip);

	/** Blueprint implements outline + material params. */
	UFUNCTION(BlueprintImplementableEvent, Category = "FEL|Decoder")
	void ApplyPostProcessOutlineMask(bool bAnkle, bool bKnee, bool bHip);

	/** JointIndex: 0 ankle, 1 knee, 2 hip — override in Blueprint or extend _Implementation for montage / sequencer (~3s). */
	UFUNCTION(BlueprintCallable, BlueprintNativeEvent, Category = "FEL|Decoder")
	void PlayPerfectVsLeakyComparison(int32 JointIndex, float DurationSeconds);
};
