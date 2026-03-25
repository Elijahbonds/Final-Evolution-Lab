// Copyright (c) Final Evolution Lab.

#include "UFELInputComponent.h"
#include "FELBasketballCharacter.h"
#include "Engine/World.h"

void UFELInputComponent::BufferJump()
{
	if (UWorld* W = GetWorld())
	{
		JumpBufferExpireWorldTime = W->GetTimeSeconds() + InputBufferWindowSeconds;
	}
}

void UFELInputComponent::BufferKick()
{
	if (UWorld* W = GetWorld())
	{
		KickBufferExpireWorldTime = W->GetTimeSeconds() + InputBufferWindowSeconds;
	}
}

void UFELInputComponent::BufferInteract()
{
	if (UWorld* W = GetWorld())
	{
		InteractBufferExpireWorldTime = W->GetTimeSeconds() + InputBufferWindowSeconds;
	}
}

void UFELInputComponent::ClearJumpBuffer()
{
	JumpBufferExpireWorldTime = -1.f;
}

void UFELInputComponent::ClearKickBuffer()
{
	KickBufferExpireWorldTime = -1.f;
}

void UFELInputComponent::ClearInteractBuffer()
{
	InteractBufferExpireWorldTime = -1.f;
}

bool UFELInputComponent::HasActiveJumpBuffer() const
{
	if (UWorld* W = GetWorld())
	{
		return JumpBufferExpireWorldTime > W->GetTimeSeconds();
	}
	return false;
}

bool UFELInputComponent::HasActiveKickBuffer() const
{
	if (UWorld* W = GetWorld())
	{
		return KickBufferExpireWorldTime > W->GetTimeSeconds();
	}
	return false;
}

void UFELInputComponent::TickInputBuffers(AFELBasketballCharacter* Character)
{
	if (!Character || !GetWorld())
	{
		return;
	}
	const float Now = GetWorld()->GetTimeSeconds();

	if (JumpBufferExpireWorldTime > 0.f)
	{
		const bool bBufferStillValid = JumpBufferExpireWorldTime > Now;
		if (bBufferStillValid && Character->CanJump())
		{
			JumpBufferExpireWorldTime = -1.f;
			Character->Jump();
		}
		else if (!bBufferStillValid)
		{
			JumpBufferExpireWorldTime = -1.f;
		}
	}

	if (KickBufferExpireWorldTime > 0.f && KickBufferExpireWorldTime <= Now)
	{
		KickBufferExpireWorldTime = -1.f;
	}
	if (InteractBufferExpireWorldTime > 0.f && InteractBufferExpireWorldTime <= Now)
	{
		InteractBufferExpireWorldTime = -1.f;
	}
}
