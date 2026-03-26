// Copyright (c) Final Evolution Lab.

#include "FELMatchResultsWidget.h"
#include "FELArenaModeDefinitions.h"
#include "FELArenaModePresentation.h"
#include "FELBasketballCharacter.h"
#include "FELBranding.h"
#include "FELCinematicCameraComponent.h"
#include "FELNativeBridge.h"
#include "Blueprint/WidgetTree.h"
#include "Components/Button.h"
#include "Components/PanelWidget.h"
#include "Components/TextBlock.h"
#include "Components/VerticalBox.h"
#include "Components/VerticalBoxSlot.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"

void UFELMatchResultsWidget::NativeConstruct()
{
	Super::NativeConstruct();
	BuildFallbackLayoutIfNeeded();
	EnsureShareButton();
	WireShareButton();
	WireReplayButton();
	WireRematchButton();
}

void UFELMatchResultsWidget::WireShareButton()
{
	if (!ShareButton)
	{
		return;
	}
	ShareButton->OnClicked.Clear();
	ShareButton->OnClicked.AddDynamic(this, &UFELMatchResultsWidget::OnShareEvolutionClicked);
}

void UFELMatchResultsWidget::OnShareEvolutionClicked()
{
	FELNativeBridge::NotifyShareEvolutionRequested();
}

void UFELMatchResultsWidget::WireReplayButton()
{
	if (!ReplayBestMomentButton)
	{
		return;
	}
	ReplayBestMomentButton->OnClicked.Clear();
	ReplayBestMomentButton->OnClicked.AddDynamic(this, &UFELMatchResultsWidget::OnReplayBestMomentClicked);
}

void UFELMatchResultsWidget::WireRematchButton()
{
	if (!RematchButton)
	{
		return;
	}
	RematchButton->OnClicked.Clear();
	RematchButton->OnClicked.AddDynamic(this, &UFELMatchResultsWidget::OnRematchClicked);
}

void UFELMatchResultsWidget::OnRematchClicked()
{
	if (APlayerController* PC = GetOwningPlayer())
	{
		PC->SetShowMouseCursor(false);
		FInputModeGameOnly Mode;
		PC->SetInputMode(Mode);
	}
	RemoveFromParent();
	if (UWorld* W = GetWorld())
	{
		UGameplayStatics::OpenLevel(W, FName(*UGameplayStatics::GetCurrentLevelName(W, true)));
	}
}

void UFELMatchResultsWidget::OnReplayBestMomentClicked()
{
	SetVisibility(ESlateVisibility::HitTestInvisible);

	if (APlayerController* PC = GetOwningPlayer())
	{
		if (AFELBasketballCharacter* C = Cast<AFELBasketballCharacter>(PC->GetPawn()))
		{
			if (C->CinematicCamera)
			{
				C->CinematicCamera->BeginReplayHighlight(3.f);
			}
		}
	}

	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(ReplayRestoreTimerHandle);
		W->GetTimerManager().SetTimer(ReplayRestoreTimerHandle, this, &UFELMatchResultsWidget::RestoreAfterReplayHighlight, 3.f, false);
	}
}

void UFELMatchResultsWidget::RestoreAfterReplayHighlight()
{
	SetVisibility(ESlateVisibility::Visible);
}

void UFELMatchResultsWidget::EnsureShareButton()
{
	if (ShareButton || !ReturnButton || !WidgetTree)
	{
		return;
	}
	UPanelWidget* Parent = Cast<UPanelWidget>(ReturnButton->GetParent());
	UVerticalBox* VBox = Cast<UVerticalBox>(Parent);
	if (!VBox)
	{
		return;
	}
	ShareButton = WidgetTree->ConstructWidget<UButton>(UButton::StaticClass());
	UTextBlock* ShareLabel = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	ShareLabel->SetText(NSLOCTEXT("FEL", "ShareEvolution", "Share Your Evolution"));
	ShareLabel->SetJustification(ETextJustify::Center);
	ShareLabel->SetColorAndOpacity(FSlateColor(FELBranding::NeuroAccentCyan()));
	ShareButton->AddChild(ShareLabel);
	VBox->RemoveChild(ReturnButton);
	if (UVerticalBoxSlot* S = VBox->AddChildToVerticalBox(ShareButton))
	{
		S->SetPadding(FMargin(24.f, 4.f, 24.f, 8.f));
	}
	if (UVerticalBoxSlot* S = VBox->AddChildToVerticalBox(ReturnButton))
	{
		S->SetPadding(FMargin(24.f, 8.f, 24.f, 32.f));
	}
}

void UFELMatchResultsWidget::BuildFallbackLayoutIfNeeded()
{
	if (TitleText && ReturnButton && RematchButton)
	{
		return;
	}
	if (!WidgetTree)
	{
		return;
	}

	TitleText = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	TitleText->SetJustification(ETextJustify::Center);
	TitleText->SetColorAndOpacity(FSlateColor(FELBranding::NeuroAccentBlue()));
	InspirationLine = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	InspirationLine->SetJustification(ETextJustify::Center);
	InspirationLine->SetColorAndOpacity(FSlateColor(FLinearColor(0.75f, 0.82f, 1.f)));
	ScoreSummaryLine = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	ScoreSummaryLine->SetJustification(ETextJustify::Center);
	ScoreSummaryLine->SetColorAndOpacity(FSlateColor(FLinearColor::White));
	PrqEstimateLine = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	PrqEstimateLine->SetJustification(ETextJustify::Center);
	PrqEstimateLine->SetColorAndOpacity(FSlateColor(FLinearColor::White));
	NeuroLine = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	NeuroLine->SetJustification(ETextJustify::Center);
	NeuroLine->SetColorAndOpacity(FSlateColor(FELBranding::NeuroAccentCyan()));
	ShardsLine = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	ShardsLine->SetJustification(ETextJustify::Center);
	ShardsLine->SetColorAndOpacity(FSlateColor(FELBranding::NeuroAccentCyan()));
	MentalSharpnessLine = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	MentalSharpnessLine->SetJustification(ETextJustify::Center);
	MentalSharpnessLine->SetColorAndOpacity(FSlateColor(FELBranding::NeuroAccentCyan()));

	ReplayBestMomentButton = WidgetTree->ConstructWidget<UButton>(UButton::StaticClass());
	UTextBlock* ReplayLabel = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	ReplayLabel->SetText(NSLOCTEXT("FEL", "ReplayBestMoment", "Replay Best Moment (3s)"));
	ReplayLabel->SetJustification(ETextJustify::Center);
	ReplayLabel->SetColorAndOpacity(FSlateColor(FELBranding::NeuroAccentCyan()));
	ReplayBestMomentButton->AddChild(ReplayLabel);
	ReplayBestMomentButton->SetVisibility(ESlateVisibility::Collapsed);

	RematchButton = WidgetTree->ConstructWidget<UButton>(UButton::StaticClass());
	UTextBlock* RematchLabel = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	RematchLabel->SetText(NSLOCTEXT("FEL", "Rematch", "Rematch — Enter / A"));
	RematchLabel->SetJustification(ETextJustify::Center);
	RematchLabel->SetColorAndOpacity(FSlateColor(FLinearColor::White));
	RematchButton->AddChild(RematchLabel);
	RematchButton->OnClicked.AddDynamic(this, &UFELMatchResultsWidget::OnRematchClicked);

	ShareButton = WidgetTree->ConstructWidget<UButton>(UButton::StaticClass());
	UTextBlock* ShareLabel = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	ShareLabel->SetText(NSLOCTEXT("FEL", "ShareEvolution", "Share Your Evolution"));
	ShareLabel->SetJustification(ETextJustify::Center);
	ShareLabel->SetColorAndOpacity(FSlateColor(FELBranding::NeuroAccentCyan()));
	ShareButton->AddChild(ShareLabel);

	ReturnButton = WidgetTree->ConstructWidget<UButton>(UButton::StaticClass());
	UTextBlock* BtnLabel = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	BtnLabel->SetText(NSLOCTEXT("FEL", "ReturnDashboard", "Return to Dashboard"));
	BtnLabel->SetJustification(ETextJustify::Center);
	BtnLabel->SetColorAndOpacity(FSlateColor(FELBranding::NeuroAccentBlue()));
	ReturnButton->AddChild(BtnLabel);
	ReturnButton->OnClicked.AddDynamic(this, &UFELMatchResultsWidget::OnReturnToDashboardClicked);

	UVerticalBox* Root = WidgetTree->ConstructWidget<UVerticalBox>(UVerticalBox::StaticClass());
	WidgetTree->RootWidget = Root;
	if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(TitleText))
	{
		S->SetPadding(FMargin(24.f, 32.f, 24.f, 8.f));
	}
	if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(InspirationLine))
	{
		S->SetPadding(FMargin(24.f, 4.f, 24.f, 8.f));
	}
	if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(ScoreSummaryLine))
	{
		S->SetPadding(FMargin(24.f, 6.f, 24.f, 4.f));
	}
	if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(PrqEstimateLine))
	{
		S->SetPadding(FMargin(24.f, 4.f, 24.f, 6.f));
	}
	if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(NeuroLine))
	{
		S->SetPadding(FMargin(24.f, 8.f, 24.f, 4.f));
	}
	if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(MentalSharpnessLine))
	{
		S->SetPadding(FMargin(24.f, 4.f, 24.f, 4.f));
	}
	if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(ShardsLine))
	{
		S->SetPadding(FMargin(24.f, 8.f, 24.f, 8.f));
	}
	if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(ReplayBestMomentButton))
	{
		S->SetPadding(FMargin(24.f, 4.f, 24.f, 8.f));
	}
	if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(ShareButton))
	{
		S->SetPadding(FMargin(24.f, 4.f, 24.f, 8.f));
	}
	if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(ReturnButton))
	{
		S->SetPadding(FMargin(24.f, 8.f, 24.f, 32.f));
	}
}

void UFELMatchResultsWidget::InitializeWithSummary(const FFELMatchResultSummary& Summary)
{
	CachedSummary = Summary;
	BuildFallbackLayoutIfNeeded();
	if (TitleText)
	{
		TitleText->SetText(FText::FromString(Summary.MatchEndBanner.IsEmpty() ? FString(TEXT("Match Results")) : Summary.MatchEndBanner));
	}
	if (InspirationLine)
	{
		const EFELArenaMode Am = FELArenaModeFromSwiftId(Summary.GameModeId);
		const FString Tag = FELGetArenaModeInspirationTag(Am);
		InspirationLine->SetText(FText::FromString(Tag.IsEmpty() ? FString(TEXT("Inspiration — Final Evolution Lab")) : FString::Printf(TEXT("Inspiration: %s"), *Tag)));
	}
	if (ScoreSummaryLine)
	{
		ScoreSummaryLine->SetText(FText::FromString(FString::Printf(TEXT("Final Score: %d"), Summary.Score)));
	}
	if (PrqEstimateLine)
	{
		PrqEstimateLine->SetText(FText::FromString(FString::Printf(TEXT("New PRQ Estimate: %.1f"), Summary.FinalPRQ)));
	}
	if (NeuroLine)
	{
		NeuroLine->SetText(FText::FromString(FString::Printf(TEXT("Neural performance index: %.0f"), Summary.NeuroPerformanceScore)));
	}
	if (MentalSharpnessLine)
	{
		MentalSharpnessLine->SetText(FText::FromString(FString::Printf(TEXT("Mental Sharpness: %.0f"), Summary.MentalSharpnessScore)));
	}
	if (ShardsLine)
	{
		ShardsLine->SetText(FText::FromString(FString::Printf(TEXT("Evolution Shards Earned: %d"), Summary.ShardsEarned)));
	}
	if (ReplayBestMomentButton)
	{
		const bool bShow = Summary.ArenaResult.bBestMomentReplayAvailable;
		ReplayBestMomentButton->SetVisibility(bShow ? ESlateVisibility::Visible : ESlateVisibility::Collapsed);
	}
}

void UFELMatchResultsWidget::OnReturnToDashboardClicked()
{
	FELNativeBridge::NotifyExitToDashboardRequested();
	if (APlayerController* PC = GetOwningPlayer())
	{
		PC->SetShowMouseCursor(false);
		FInputModeGameOnly Mode;
		PC->SetInputMode(Mode);
	}
	RemoveFromParent();
}
