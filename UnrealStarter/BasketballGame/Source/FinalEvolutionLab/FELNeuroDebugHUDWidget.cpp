// Copyright (c) Final Evolution Lab.

#include "FELNeuroDebugHUDWidget.h"
#include "Blueprint/WidgetTree.h"
#include "Components/OverlaySlot.h"
#include "FELNeuroMechanicBridgeSubsystem.h"
#include "FELNeuroMechanicDisplay.h"
#include "FELReadinessTypes.h"
#include "FELArenaRulesTypes.h"
#include "Components/Overlay.h"
#include "Components/TextBlock.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "Layout/Margin.h"
#include "Styling/CoreStyle.h"

void UFELNeuroDebugHUDWidget::NativeConstruct()
{
	Super::NativeConstruct();

#if UE_BUILD_SHIPPING
	return;
#else
	RebuildDebugTextIfNeeded();

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Bridge = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			Bridge->OnNeuroHUDStatsRefresh.AddDynamic(this, &UFELNeuroDebugHUDWidget::NotifyStatsChanged);
		}
	}

	NotifyStatsChanged();
#endif
}

void UFELNeuroDebugHUDWidget::NativeDestruct()
{
#if !UE_BUILD_SHIPPING
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Bridge = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			Bridge->OnNeuroHUDStatsRefresh.RemoveDynamic(this, &UFELNeuroDebugHUDWidget::NotifyStatsChanged);
		}
	}
#endif
	Super::NativeDestruct();
}

void UFELNeuroDebugHUDWidget::RebuildDebugTextIfNeeded()
{
#if UE_BUILD_SHIPPING
	return;
#else
	if (NeuroStatsText)
	{
		return;
	}

	if (!WidgetTree)
	{
		return;
	}

	UOverlay* const Overlay = WidgetTree->ConstructWidget<UOverlay>(UOverlay::StaticClass(), TEXT("FELNeuroOverlay"));
	NeuroStatsText = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass(), TEXT("FELNeuroStatsText"));
	NeuroStatsText->SetColorAndOpacity(FLinearColor(0.2f, 1.f, 0.45f, 1.f));
	NeuroStatsText->SetFont(FCoreStyle::GetDefaultFontStyle("Regular", 14));
	NeuroStatsText->SetShadowOffset(FVector2D(1.f, 1.f));

	if (UOverlaySlot* const Slot = Overlay->AddChildToOverlay(NeuroStatsText))
	{
		Slot->SetPadding(FMargin(28.f, 28.f, 0.f, 0.f));
		Slot->SetHorizontalAlignment(HAlign_Left);
		Slot->SetVerticalAlignment(VAlign_Top);
	}

	WidgetTree->RootWidget = Overlay;
#endif
}

void UFELNeuroDebugHUDWidget::RefreshDisplay()
{
#if UE_BUILD_SHIPPING
	return;
#else
	if (!NeuroStatsText)
	{
		return;
	}

	FFELReadinessSnapshot Snap;
	FFELArenaRules Rules;
	float JumpZ = 0.f;
	float WalkSpeed = 0.f;
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Bridge = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			Bridge->GetCachedSnapshot(Snap);
			Bridge->GetCurrentArenaSettings(Rules);
		}
	}
	FELNeuroMechanicDisplay::ComputeEffectiveJumpAndWalk(Snap, JumpZ, WalkSpeed);
	FString Metric3Label;
	FString Metric3Value;
	FELNeuroMechanicDisplay::GetSportHudMetric3(Snap, Rules, Metric3Label, Metric3Value);

	const FString Line = FString::Printf(
		TEXT("Clinical HUD (diagnostic)\nVenue: %s\nMode id: %s\n---\nAthlete readiness\n  Vertical estimate: %.1f in\n  PRQ: %.1f\n  Jump velocity: %.0f  Locomotion cap: %.0f\n  %s: %s\n[R] Reload readiness snapshot"),
		*Rules.ModeDisplayName,
		*Snap.ActiveArenaMode,
		Snap.VerticalEstimateInches,
		Snap.PRQScore,
		JumpZ,
		WalkSpeed,
		*Metric3Label,
		*Metric3Value);
	NeuroStatsText->SetText(FText::FromString(Line));
#endif
}

void UFELNeuroDebugHUDWidget::NotifyStatsChanged()
{
	RefreshDisplay();
}
