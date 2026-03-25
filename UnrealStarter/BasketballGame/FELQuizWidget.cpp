// Copyright (c) Final Evolution Lab.

#include "FELQuizWidget.h"
#include "FELNeuroMechanicBridgeSubsystem.h"
#include "Blueprint/WidgetTree.h"
#include "Components/Button.h"
#include "Components/TextBlock.h"
#include "Components/VerticalBox.h"
#include "Components/VerticalBoxSlot.h"
#include "Engine/GameInstance.h"
#include "GameFramework/PlayerController.h"

namespace
{
	static void BuildNeuroQuestionBank(TArray<FFELNeuroQuizItem>& Out)
	{
		Out.Reset();
		{
			FFELNeuroQuizItem Q;
			Q.Question = TEXT("Which structure is most associated with procedural motor learning for repeated jump timing?");
			Q.Answers = { TEXT("Cerebellum"), TEXT("Occipital lobe"), TEXT("Broca's area"), TEXT("Medulla only") };
			Q.CorrectIndex = 0;
			Out.Add(Q);
		}
		{
			FFELNeuroQuizItem Q;
			Q.Question = TEXT("In sprint biomechanics, increased anterior pelvic tilt during acceleration often couples with:");
			Q.Answers = { TEXT("Lumbar hyperextension strategy"), TEXT("Ankle dorsiflexion only"), TEXT("Pure knee flexion dominance"), TEXT("Shoulder abduction drive") };
			Q.CorrectIndex = 0;
			Out.Add(Q);
		}
		{
			FFELNeuroQuizItem Q;
			Q.Question = TEXT("Rate of force development (RFD) is most sensitive to training that emphasizes:");
			Q.Answers = { TEXT("High-velocity intent and short ground contact"), TEXT("Only long-duration aerobic volume"), TEXT("Static stretching only"), TEXT("Passive ice immersion") };
			Q.CorrectIndex = 0;
			Out.Add(Q);
		}
		{
			FFELNeuroQuizItem Q;
			Q.Question = TEXT("The stretch-shortening cycle (SSC) primarily exploits:");
			Q.Answers = { TEXT("Elastic energy storage and reflex potentiation"), TEXT("Pure isometric hold"), TEXT("Frictionless sliding only"), TEXT("Visual tracking alone") };
			Q.CorrectIndex = 0;
			Out.Add(Q);
		}
	}
}

void UFELQuizWidget::NativeConstruct()
{
	Super::NativeConstruct();
	BuildProgrammaticLayoutIfNeeded();
}

void UFELQuizWidget::BuildProgrammaticLayoutIfNeeded()
{
	if (QuestionTextBlock && AnswerVerticalBox)
	{
		return;
	}

	if (!WidgetTree)
	{
		return;
	}

	bBuiltProgrammaticFallback = true;

	QuestionTextBlock = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	QuestionTextBlock->SetJustification(ETextJustify::Center);
	QuestionTextBlock->SetAutoWrapText(true);
	QuestionTextBlock->SetColorAndOpacity(FSlateColor(FLinearColor::White));

	AnswerVerticalBox = WidgetTree->ConstructWidget<UVerticalBox>(UVerticalBox::StaticClass());

	UVerticalBox* RootVBox = WidgetTree->ConstructWidget<UVerticalBox>(UVerticalBox::StaticClass());
	WidgetTree->RootWidget = RootVBox;

	if (UVerticalBoxSlot* QS = RootVBox->AddChildToVerticalBox(QuestionTextBlock))
	{
		QS->SetPadding(FMargin(24.f, 24.f, 24.f, 12.f));
	}

	if (UVerticalBoxSlot* AS = RootVBox->AddChildToVerticalBox(AnswerVerticalBox))
	{
		AS->SetPadding(FMargin(24.f, 0.f, 24.f, 24.f));
	}
}

void UFELQuizWidget::InitializeQuiz(UGameInstance* GameInstance)
{
	CachedGameInstance = GameInstance;
	BuildNeuroQuestionBank(QuestionBank);

	ShuffledOrder.Reset();
	for (int32 i = 0; i < QuestionBank.Num(); ++i)
	{
		ShuffledOrder.Add(i);
	}
	for (int32 i = ShuffledOrder.Num() - 1; i > 0; --i)
	{
		const int32 j = FMath::RandRange(0, i);
		ShuffledOrder.Swap(i, j);
	}

	CurrentOrdinal = 0;
	PresentCurrentQuestion();
}

void UFELQuizWidget::FinishQuiz()
{
	if (APlayerController* PC = GetOwningPlayer())
	{
		PC->SetShowMouseCursor(false);
		FInputModeGameOnly Mode;
		PC->SetInputMode(Mode);
	}
	RemoveFromParent();
}

void UFELQuizWidget::PresentCurrentQuestion()
{
	if (!QuestionTextBlock || !AnswerVerticalBox)
	{
		return;
	}

	if (QuestionBank.Num() == 0 || ShuffledOrder.Num() == 0)
	{
		QuestionTextBlock->SetText(NSLOCTEXT("FEL", "QuizEmpty", "No neuro questions loaded."));
		return;
	}

	if (CurrentOrdinal >= ShuffledOrder.Num())
	{
		QuestionTextBlock->SetText(NSLOCTEXT("FEL", "QuizDone", "Brain Brawl round complete."));
		AnswerVerticalBox->ClearChildren();
		SpawnedAnswerButtons.Reset();

		FTimerHandle H;
		if (UWorld* W = GetWorld())
		{
			W->GetTimerManager().SetTimer(
				H,
				[this]()
				{
					FinishQuiz();
				},
				1.2f,
				false);
		}
		return;
	}

	const int32 BankIdx = ShuffledOrder[CurrentOrdinal];
	const FFELNeuroQuizItem& Item = QuestionBank[BankIdx];

	QuestionTextBlock->SetText(FText::FromString(Item.Question));
	AnswerVerticalBox->ClearChildren();
	SpawnedAnswerButtons.Reset();

	for (int32 a = 0; a < Item.Answers.Num(); ++a)
	{
		UButton* Btn = WidgetTree->ConstructWidget<UButton>(UButton::StaticClass());
		UTextBlock* Label = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
		Label->SetText(FText::FromString(Item.Answers[a]));
		Label->SetJustification(ETextJustify::Center);
		Btn->AddChild(Label);

		const int32 Captured = a;
		Btn->OnClicked.AddLambda(
			[this, Captured]()
			{
				OnAnswerButtonClicked(Captured);
			});

		if (UVerticalBoxSlot* VS = AnswerVerticalBox->AddChildToVerticalBox(Btn))
		{
			VS->SetPadding(FMargin(0.f, 6.f, 0.f, 0.f));
		}
		SpawnedAnswerButtons.Add(Btn);
	}
}

void UFELQuizWidget::OnAnswerButtonClicked(const int32 AnswerIndex)
{
	if (CurrentOrdinal >= ShuffledOrder.Num() || QuestionBank.Num() == 0)
	{
		return;
	}

	const int32 BankIdx = ShuffledOrder[CurrentOrdinal];
	const FFELNeuroQuizItem& Item = QuestionBank[BankIdx];

	if (AnswerIndex == Item.CorrectIndex)
	{
		ApplyCorrectAnswerBoost();
	}

	++CurrentOrdinal;
	PresentCurrentQuestion();
}

void UFELQuizWidget::ApplyCorrectAnswerBoost() const
{
	if (!CachedGameInstance.IsValid())
	{
		return;
	}
	UFELNeuroMechanicBridgeSubsystem* Bridge = CachedGameInstance->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>();
	if (!Bridge)
	{
		return;
	}
	// Mental–physical link: short PRQ bump re-applied through readiness pipeline.
	Bridge->ApplyTemporaryPRQBoost(4.0, 18.0f);
}
