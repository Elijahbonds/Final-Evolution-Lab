#include "FELFocusKeepaliveTickComponent.h"
#include "Engine/World.h"
#include "TimerManager.h"

UFELFocusKeepaliveTickComponent::UFELFocusKeepaliveTickComponent()
{
	PrimaryComponentTick.bCanEverTick = false;
}

void UFELFocusKeepaliveTickComponent::SetKeepaliveEnabled(bool bEnable)
{
	bActive = bEnable;
	UWorld* World = GetWorld();
	if (!World)
	{
		return;
	}
	World->GetTimerManager().ClearTimer(Timer);
	if (!bActive)
	{
		return;
	}
	const float T = FMath::Max(0.05f, IntervalSeconds);
	World->GetTimerManager().SetTimer(
		Timer, this, &UFELFocusKeepaliveTickComponent::Pulse, T, true);
}

void UFELFocusKeepaliveTickComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (UWorld* World = GetWorld())
	{
		World->GetTimerManager().ClearTimer(Timer);
	}
	Super::EndPlay(EndPlayReason);
}

void UFELFocusKeepaliveTickComponent::Pulse()
{
	OnKeepalive.Broadcast();
}
