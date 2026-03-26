// Copyright (c) Final Evolution Lab.

#include "FELPerfectFormChecklistWidget.h"
#include "Blueprint/WidgetTree.h"
#include "Components/TextBlock.h"
#include "Components/VerticalBox.h"
#include "Components/VerticalBoxSlot.h"

void UFELPerfectFormChecklistWidget::InitializeChecklist(const TArray<FText>& Lines, const float FontScale)
{
	PendingLines = Lines;
	PendingFontScale = FontScale;
}

void UFELPerfectFormChecklistWidget::NativeConstruct()
{
	Super::NativeConstruct();
	RebuildFromPending();
}

void UFELPerfectFormChecklistWidget::RebuildFromPending()
{
	if (!WidgetTree || PendingLines.Num() == 0)
	{
		return;
	}
	UVerticalBox* Root = WidgetTree->ConstructWidget<UVerticalBox>(UVerticalBox::StaticClass());
	WidgetTree->RootWidget = Root;
	for (const FText& Line : PendingLines)
	{
		UTextBlock* T = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
		T->SetText(FText::Format(NSLOCTEXT("FEL", "PerfectFormBullet", "☑ {0}"), Line));
		T->SetColorAndOpacity(FSlateColor(FLinearColor(0.92f, 0.98f, 1.f)));
		T->SetJustification(ETextJustify::Left);
		if (PendingFontScale > 0.01f)
		{
			FSlateFontInfo Font = T->GetFont();
			Font.Size = FMath::RoundToInt(14.f * PendingFontScale);
			T->SetFont(Font);
		}
		if (UVerticalBoxSlot* S = Root->AddChildToVerticalBox(T))
		{
			S->SetPadding(FMargin(4.f, 2.f));
		}
	}
}
