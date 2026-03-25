// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "AFELSocialGhostActor.generated.h"

class USkeletalMeshComponent;
class UTextRenderComponent;
class UMaterialInterface;
class UPostProcessComponent;

UCLASS()
class FINALEVOLUTIONLAB_API AFELSocialGhostActor : public AActor
{
	GENERATED_BODY()

public:
	AFELSocialGhostActor();

	virtual void Tick(float DeltaSeconds) override;

	UFUNCTION(BlueprintCallable, Category = "FEL|Social")
	void ApplyFriendAvatarMeshPath(const FString& Path);

	/** Floating “broadcast” PRQ tag above the ghost (friend’s current score from presence sync). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Social")
	void SetFriendPRQDisplay(int32 FriendPRQ);

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Social")
	float GhostOpacity = 0.35f;

	/** Translucent / holographic master (Fresnel + emissive). When set, overrides simple opacity MID pass. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Social")
	TObjectPtr<UMaterialInterface> GhostTranslucentMasterMaterial;

	/** Local post-process for Vault-style hologram fringe (assign hologram PP material in editor). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Social")
	TObjectPtr<UPostProcessComponent> GhostPostProcess;

protected:
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Social")
	TObjectPtr<USkeletalMeshComponent> GhostMesh;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Social")
	TObjectPtr<UTextRenderComponent> PRQTag;
};
