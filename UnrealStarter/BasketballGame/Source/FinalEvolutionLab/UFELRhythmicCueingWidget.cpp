// Copyright (c) Final Evolution Lab.

#include "UFELRhythmicCueingWidget.h"
#include "UFELBiometricOverlays.h"
#include "UFELInputManager.h"
#include "FELNativeBridge.h"
#include "HAL/Platform.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"

void UFELRhythmicCueingWidget::StartPenultimateStrideLoop()
{
	if (bRunning || !GetWorld())
	{
		return;
	}
	bRunning = true;
	BeatIndex = 0;
	GetWorld()->GetTimerManager().SetTimer(BeatHandle, this, &UFELRhythmicCueingWidget::OnBeat, BeatIntervalSec, true);
}

void UFELRhythmicCueingWidget::StopPenultimateStrideLoop()
{
	bRunning = false;
	if (GetWorld())
	{
		GetWorld()->GetTimerManager().ClearTimer(BeatHandle);
	}
}

void UFELRhythmicCueingWidget::NativeDestruct()
{
	StopPenultimateStrideLoop();
	Super::NativeDestruct();
}

void UFELRhythmicCueingWidget::OnBeat()
{
	if (ClickSound)
	{
		UGameplayStatics::PlaySound2D(this, ClickSound, 0.55f);
	}
	const int32 Phase = BeatIndex;
	BeatIndex = (BeatIndex + 1) % 3;
	OnClinicalBeat.Broadcast(Phase);
	UFELInputManager::PlayPushTwelveClinicalHaptic(this, Phase);
	UFELBiometricOverlays::ApplyGlobalRhythmPulse(this, Phase);
#if PLATFORM_IOS
	FELNativeBridge::NotifyPenultimateStrideRhythm(Phase);
#endif
}
