// Copyright (c) Final Evolution Lab.

#include "UFELRetailStartupWidget.h"
#include "UFELGameInstance.h"
#include "Blueprint/WidgetTree.h"
#include "Components/Button.h"
#include "Components/TextBlock.h"
#include "Components/VerticalBox.h"
#include "Components/VerticalBoxSlot.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "TimerManager.h"

void UFELRetailStartupWidget::InitializeRetailFlow(UFELGameInstance* InOwner)
{
	OwnerGI = InOwner;
}

void UFELRetailStartupWidget::NativeConstruct()
{
	Super::NativeConstruct();
	BuildLayout();
	ShowSplashPhase();
}

void UFELRetailStartupWidget::BuildLayout()
{
	if (!WidgetTree || BodyText)
	{
		return;
	}
	BodyText = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	BodyText->SetJustification(ETextJustify::Center);
	BodyText->SetColorAndOpacity(FSlateColor(FLinearColor::White));
	BodyText->SetAutoWrapText(true);

	MenuBox = WidgetTree->ConstructWidget<UVerticalBox>(UVerticalBox::StaticClass());
	PlayButton = WidgetTree->ConstructWidget<UButton>(UButton::StaticClass());
	QuitButton = WidgetTree->ConstructWidget<UButton>(UButton::StaticClass());
	UTextBlock* PL = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	PL->SetText(NSLOCTEXT("FEL", "RetailPlay", "Play — Enter / A"));
	PL->SetJustification(ETextJustify::Center);
	PlayButton->AddChild(PL);
	PlayButton->OnClicked.AddDynamic(this, &UFELRetailStartupWidget::OnPlayClicked);
	UTextBlock* QL = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	QL->SetText(NSLOCTEXT("FEL", "RetailQuit", "Quit — Esc / B"));
	QL->SetJustification(ETextJustify::Center);
	QuitButton->AddChild(QL);
	QuitButton->OnClicked.AddDynamic(this, &UFELRetailStartupWidget::OnQuitClicked);

	if (UVerticalBoxSlot* S = MenuBox->AddChildToVerticalBox(PlayButton))
	{
		S->SetPadding(FMargin(0.f, 8.f, 0.f, 8.f));
	}
	if (UVerticalBoxSlot* S = MenuBox->AddChildToVerticalBox(QuitButton))
	{
		S->SetPadding(FMargin(0.f, 8.f, 0.f, 0.f));
	}
	MenuBox->SetVisibility(ESlateVisibility::Collapsed);

	UVerticalBox* Root = WidgetTree->ConstructWidget<UVerticalBox>(UVerticalBox::StaticClass());
	WidgetTree->RootWidget = Root;
	if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(BodyText))
	{
		S->SetPadding(FMargin(48.f, 120.f, 48.f, 24.f));
	}
	if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(MenuBox))
	{
		S->SetPadding(FMargin(48.f, 24.f, 48.f, 48.f));
	}
}

void UFELRetailStartupWidget::ShowSplashPhase()
{
	if (BodyText)
	{
		BodyText->SetText(NSLOCTEXT(
			"FEL",
			"RetailSplash",
			"FINAL EVOLUTION LAB\n\nNeuro-mechanic sports arena"));
	}
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().SetTimer(
			PhaseTimerHandle,
			this,
			&UFELRetailStartupWidget::ShowMenuPhase,
			2.5f,
			false);
	}
}

void UFELRetailStartupWidget::ShowMenuPhase()
{
	if (BodyText)
	{
		BodyText->SetText(NSLOCTEXT("FEL", "RetailMenuTitle", "Main Menu"));
	}
	if (MenuBox)
	{
		MenuBox->SetVisibility(ESlateVisibility::Visible);
	}
	if (APlayerController* PC = GetOwningPlayer())
	{
		FInputModeGameAndUI Mode;
		if (PlayButton)
		{
			Mode.SetWidgetToFocus(PlayButton->TakeWidget());
		}
		Mode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
		PC->SetInputMode(Mode);
		PC->SetShowMouseCursor(false);
	}
}

void UFELRetailStartupWidget::OnPlayClicked()
{
	RemoveFromParent();
	if (OwnerGI)
	{
		OwnerGI->OnRetailStartupPlaySelected();
	}
}

void UFELRetailStartupWidget::OnQuitClicked()
{
	if (OwnerGI)
	{
		OwnerGI->OnRetailStartupQuitSelected();
	}
}
