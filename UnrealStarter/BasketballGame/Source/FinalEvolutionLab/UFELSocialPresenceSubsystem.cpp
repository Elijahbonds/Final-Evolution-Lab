// Copyright (c) Final Evolution Lab.

#include "UFELSocialPresenceSubsystem.h"
#include "Engine/GameInstance.h"
#include "AFELSocialGhostActor.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/Actor.h"

namespace
{
	const FName SpectatorTag(TEXT("FEL_Lab_Spectator"));
}

void UFELSocialPresenceSubsystem::SetFriendPresence(const bool bActiveInApp, const FString& OptionalAvatarMeshPath)
{
	SetFriendPresenceWithPRQ(bActiveInApp, OptionalAvatarMeshPath, FriendPRQScore);
}

void UFELSocialPresenceSubsystem::SetFriendPresenceWithPRQ(
	const bool bActiveInApp,
	const FString& OptionalAvatarMeshPath,
	const int32 FriendPRQ)
{
	bFriendActiveInApp = bActiveInApp;
	FriendPRQScore = FriendPRQ;
	if (!OptionalAvatarMeshPath.IsEmpty())
	{
		FriendAvatarMeshPath = OptionalAvatarMeshPath;
	}
	RefreshSocialGhost();
}

void UFELSocialPresenceSubsystem::RefreshSocialGhost()
{
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* W = GI->GetWorld())
		{
			if (CachedGhost.IsValid())
			{
				CachedGhost->Destroy();
				CachedGhost = nullptr;
			}

			if (!bFriendActiveInApp)
			{
				return;
			}

			FVector Loc(0.f, 800.f, 120.f);
			FRotator Rot(0.f, 180.f, 0.f);
			for (TActorIterator<AActor> It(W); It; ++It)
			{
				if ((*It)->ActorHasTag(SpectatorTag))
				{
					Loc = (*It)->GetActorLocation();
					Rot = (*It)->GetActorRotation();
					break;
				}
			}

			FActorSpawnParameters Params;
			Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
			AFELSocialGhostActor* G = W->SpawnActor<AFELSocialGhostActor>(AFELSocialGhostActor::StaticClass(), Loc, Rot, Params);
			if (G)
			{
				G->ApplyFriendAvatarMeshPath(FriendAvatarMeshPath);
				G->SetFriendPRQDisplay(FriendPRQScore);
				CachedGhost = G;
			}
		}
	}
}
