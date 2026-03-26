// Copyright (c) Final Evolution Lab.
// Community pillar: show a low-opacity "social ghost" in the Lab spectator area when a friend is active in-app.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELSocialPresenceSubsystem.generated.h"

class AFELSocialGhostActor;

UCLASS()
class FINALEVOLUTIONLAB_API UFELSocialPresenceSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	/** When true, spawns/keeps a ghost at `FEL_Lab_Spectator` (or world origin fallback). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Social")
	bool bFriendActiveInApp = false;

	/** Optional soft path to skeletal mesh for the friend's avatar (e.g. same family as player twin). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Social")
	FString FriendAvatarMeshPath;

	/** Shown on floating tag above ghost (`AFELSocialGhostActor::PRQTag`). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Social")
	int32 FriendPRQScore = 0;

	UFUNCTION(BlueprintCallable, Category = "FEL|Social")
	void SetFriendPresence(bool bActiveInApp, const FString& OptionalAvatarMeshPath);

	UFUNCTION(BlueprintCallable, Category = "FEL|Social")
	void SetFriendPresenceWithPRQ(bool bActiveInApp, const FString& OptionalAvatarMeshPath, int32 FriendPRQ);

	UFUNCTION(BlueprintCallable, Category = "FEL|Social")
	void RefreshSocialGhost();

protected:
	UPROPERTY(Transient)
	TWeakObjectPtr<AFELSocialGhostActor> CachedGhost;
};
