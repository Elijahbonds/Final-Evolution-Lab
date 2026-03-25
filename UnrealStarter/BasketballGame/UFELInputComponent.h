// Copyright (c) Final Evolution Lab.
// Enhanced Input component + Bonds Bounce input buffering (default 100 ms — IA_ShootTap).

#pragma once

#include "CoreMinimal.h"
#include "EnhancedInputComponent.h"
#include "FELInputBufferTypes.h"
#include "UFELInputComponent.generated.h"

class AFELBasketballCharacter;

/**
 * Queues discrete actions for a short window so presses on early frames still resolve
 * when landing / gather windows open (professional platformer feel).
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELInputComponent : public UEnhancedInputComponent
{
	GENERATED_BODY()

public:
	static constexpr float InputBufferWindowSeconds = 0.1f;

	void BufferJump();
	void BufferKick();
	void BufferInteract();

	void ClearJumpBuffer();
	void ClearKickBuffer();
	void ClearInteractBuffer();

	/** Call from owning character Tick (after coyote decay): consumes buffer into Jump() when valid. */
	void TickInputBuffers(AFELBasketballCharacter* Character);

	bool HasActiveJumpBuffer() const;
	bool HasActiveKickBuffer() const;

private:
	float JumpBufferExpireWorldTime = -1.f;
	float KickBufferExpireWorldTime = -1.f;
	float InteractBufferExpireWorldTime = -1.f;
};
