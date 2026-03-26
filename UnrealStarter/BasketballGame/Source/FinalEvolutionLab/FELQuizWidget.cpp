// Copyright (c) Final Evolution Lab.

#include "FELQuizWidget.h"
#include "FELBasketballGameMode.h"
#include "FELReadinessTypes.h"
#include "FELNeuroMechanicBridgeSubsystem.h"
#include "FELTwelvePillarArenaGameplay.h"
#include "Blueprint/WidgetTree.h"
#include "Components/Button.h"
#include "Components/TextBlock.h"
#include "Components/VerticalBox.h"
#include "Components/VerticalBoxSlot.h"
#include "Engine/GameInstance.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"

namespace
{
	static void BuildNeuroQuestionBank(TArray<FFELNeuroQuizItem>& Out)
	{
		Out.Reset();
		{
			FFELNeuroQuizItem Q;
			Q.Question = TEXT("Which structure is most associated with procedural motor learning for repeated jump timing?");
			Q.Answers = {TEXT("Cerebellum"), TEXT("Occipital lobe"), TEXT("Broca's area"), TEXT("Medulla only")};
			Q.CorrectIndex = 0;
			Q.Domain = EFELBrainBrawlCurriculumDomain::Analyze;
			Q.PathIds = {TEXT("core")};
			Q.SourcePathId = TEXT("core");
			Out.Add(Q);
		}
		{
			FFELNeuroQuizItem Q;
			Q.Question = TEXT("In sprint biomechanics, increased anterior pelvic tilt during acceleration often couples with:");
			Q.Answers = {TEXT("Lumbar hyperextension strategy"), TEXT("Ankle dorsiflexion only"), TEXT("Pure knee flexion dominance"), TEXT("Shoulder abduction drive")};
			Q.CorrectIndex = 0;
			Q.Domain = EFELBrainBrawlCurriculumDomain::Analyze;
			Q.PathIds = {TEXT("core")};
			Q.SourcePathId = TEXT("core");
			Out.Add(Q);
		}
		{
			FFELNeuroQuizItem Q;
			Q.Question = TEXT("Rate of force development (RFD) is most sensitive to training that emphasizes:");
			Q.Answers = {TEXT("High-velocity intent and short ground contact"), TEXT("Only long-duration aerobic volume"), TEXT("Static stretching only"), TEXT("Passive ice immersion")};
			Q.CorrectIndex = 0;
			Q.Domain = EFELBrainBrawlCurriculumDomain::Compute;
			Q.PathIds = {TEXT("core")};
			Q.SourcePathId = TEXT("core");
			Out.Add(Q);
		}
		{
			FFELNeuroQuizItem Q;
			Q.Question = TEXT("The stretch-shortening cycle (SSC) primarily exploits:");
			Q.Answers = {TEXT("Elastic energy storage and reflex potentiation"), TEXT("Pure isometric hold"), TEXT("Frictionless sliding only"), TEXT("Visual tracking alone")};
			Q.CorrectIndex = 0;
			Q.Domain = EFELBrainBrawlCurriculumDomain::Identify;
			Q.PathIds = {TEXT("core")};
			Q.SourcePathId = TEXT("core");
			Out.Add(Q);
		}
	}
}

void UFELQuizWidget::NativeConstruct()
{
	Super::NativeConstruct();
	BuildProgrammaticLayoutIfNeeded();
}

void UFELQuizWidget::NativeDestruct()
{
	StopAcademyHudPump();
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(AnswerLockoutTimerHandle);
	}
	Super::NativeDestruct();
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

	ProgrammaticDuelStatusText = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	ProgrammaticDuelStatusText->SetJustification(ETextJustify::Center);
	ProgrammaticDuelStatusText->SetAutoWrapText(true);
	ProgrammaticDuelStatusText->SetColorAndOpacity(FSlateColor(FLinearColor(0.75f, 0.9f, 1.f)));

	ProgrammaticDuelTimerText = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	ProgrammaticDuelTimerText->SetJustification(ETextJustify::Center);
	ProgrammaticDuelTimerText->SetAutoWrapText(false);
	ProgrammaticDuelTimerText->SetColorAndOpacity(FSlateColor(FLinearColor(1.f, 0.92f, 0.35f)));

	QuestionTextBlock = WidgetTree->ConstructWidget<UTextBlock>(UTextBlock::StaticClass());
	QuestionTextBlock->SetJustification(ETextJustify::Center);
	QuestionTextBlock->SetAutoWrapText(true);
	QuestionTextBlock->SetColorAndOpacity(FSlateColor(FLinearColor::White));

	AnswerVerticalBox = WidgetTree->ConstructWidget<UVerticalBox>(UVerticalBox::StaticClass());

	UVerticalBox* RootVBox = WidgetTree->ConstructWidget<UVerticalBox>(UVerticalBox::StaticClass());
	WidgetTree->RootWidget = RootVBox;

	auto PadSlot = [](UVerticalBoxSlot* Slot, const FMargin& M)
	{
		if (Slot)
		{
			Slot->SetPadding(M);
		}
	};

	if (UVerticalBoxSlot* S0 = RootVBox->AddChildToVerticalBox(ProgrammaticDuelStatusText))
	{
		PadSlot(S0, FMargin(24.f, 16.f, 24.f, 4.f));
	}
	if (UVerticalBoxSlot* S1 = RootVBox->AddChildToVerticalBox(ProgrammaticDuelTimerText))
	{
		PadSlot(S1, FMargin(24.f, 0.f, 24.f, 8.f));
	}
	if (UVerticalBoxSlot* QS = RootVBox->AddChildToVerticalBox(QuestionTextBlock))
	{
		PadSlot(QS, FMargin(24.f, 8.f, 24.f, 12.f));
	}

	if (UVerticalBoxSlot* AS = RootVBox->AddChildToVerticalBox(AnswerVerticalBox))
	{
		PadSlot(AS, FMargin(24.f, 0.f, 24.f, 24.f));
	}
}

void UFELQuizWidget::InitializeQuiz(UGameInstance* GameInstance)
{
	bAcademyDuelMode = false;
	bAcademyCompletionDispatched = false;
	StopAcademyHudPump();
	CachedGameInstance = GameInstance;
	AcademySubsystem = nullptr;
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
	if (ProgrammaticDuelStatusText)
	{
		ProgrammaticDuelStatusText->SetVisibility(ESlateVisibility::Collapsed);
	}
	if (ProgrammaticDuelTimerText)
	{
		ProgrammaticDuelTimerText->SetVisibility(ESlateVisibility::Collapsed);
	}
	PresentCurrentQuestion();
}

void UFELQuizWidget::InitializeBrainBrawlFromSubsystem(UGameInstance* GameInstance)
{
	bAcademyDuelMode = true;
	bAcademyCompletionDispatched = false;
	bAnswerInputLocked = false;
	StopAcademyHudPump();
	CachedGameInstance = GameInstance;
	AcademySubsystem = GameInstance ? GameInstance->GetSubsystem<UFELBrainBrawlAcademySubsystem>() : nullptr;

	BuildProgrammaticLayoutIfNeeded();

	QuestionBank.Reset();
	if (AcademySubsystem)
	{
		AcademySubsystem->CopyLocalQuestionBank(QuestionBank);
	}
	if (QuestionBank.Num() == 0)
	{
		BuildNeuroQuestionBank(QuestionBank);
	}

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

	if (ProgrammaticDuelStatusText)
	{
		ProgrammaticDuelStatusText->SetVisibility(ESlateVisibility::Visible);
	}
	if (ProgrammaticDuelTimerText)
	{
		ProgrammaticDuelTimerText->SetVisibility(ESlateVisibility::Visible);
	}

	if (UWorld* W = GetWorld())
	{
		LastAcademyHudWorldSeconds = W->GetTimeSeconds();
	}
	RefreshAcademyHudTexts();
	StartAcademyHudPump();
	PresentCurrentQuestion();
}

void UFELQuizWidget::StartAcademyHudPump()
{
	if (!bAcademyDuelMode || !GetWorld())
	{
		return;
	}
	GetWorld()->GetTimerManager().SetTimer(AcademyHudTimerHandle, this, &UFELQuizWidget::PumpAcademyHud, 0.05f, true);
}

void UFELQuizWidget::StopAcademyHudPump()
{
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(AcademyHudTimerHandle);
	}
}

void UFELQuizWidget::PumpAcademyHud()
{
	if (!bAcademyDuelMode || !AcademySubsystem || !GetWorld())
	{
		return;
	}
	UWorld* W = GetWorld();
	const double Now = W->GetTimeSeconds();
	const float Dt = static_cast<float>(FMath::Clamp(Now - LastAcademyHudWorldSeconds, 0.001, 0.25));
	LastAcademyHudWorldSeconds = Now;
	AcademySubsystem->TickDuel(Dt);
	RefreshAcademyHudTexts();

	if (!bAcademyCompletionDispatched && AcademySubsystem->GetRemainingDuelSeconds() <= 0.f)
	{
		bAcademyCompletionDispatched = true;
		CompleteAcademyDuelAndClose();
	}
}

void UFELQuizWidget::RefreshAcademyHudTexts()
{
	if (!bAcademyDuelMode || !AcademySubsystem)
	{
		return;
	}
	const FString Status = FString::Printf(
		TEXT("Your path: %s  ·  Their path: %s\nYou: %d correct  ·  Friend: %d correct"),
		*AcademySubsystem->GetLocalPathTitle(),
		*AcademySubsystem->GetOpponentPathTitle(),
		AcademySubsystem->GetLocalCorrectCount(),
		AcademySubsystem->GetOpponentCorrectCount());
	const FString Tim = FString::Printf(TEXT("Time remaining: %.0f s"), AcademySubsystem->GetRemainingDuelSeconds());

	if (ProgrammaticDuelStatusText)
	{
		ProgrammaticDuelStatusText->SetText(FText::FromString(Status));
	}
	if (ProgrammaticDuelTimerText)
	{
		ProgrammaticDuelTimerText->SetText(FText::FromString(Tim));
	}
}

void UFELQuizWidget::CompleteAcademyDuelAndClose()
{
	StopAcademyHudPump();
	if (AcademySubsystem)
	{
		AcademySubsystem->FinalizeDuelAndPersistProgress();
	}
	if (UWorld* W = GetWorld())
	{
		if (AFELBasketballGameMode* GM = Cast<AFELBasketballGameMode>(UGameplayStatics::GetGameMode(W)))
		{
			GM->NotifyBrainBrawlAcademyDuelComplete();
		}
	}
	FinishQuiz();
}

void UFELQuizWidget::SetAnswerInputLocked(const bool bLocked)
{
	bAnswerInputLocked = bLocked;
	UpdateAnswerButtonsInteractable();
}

void UFELQuizWidget::UpdateAnswerButtonsInteractable()
{
	const bool bEnable = !bAnswerInputLocked;
	for (TObjectPtr<UButton> Btn : SpawnedAnswerButtons)
	{
		if (Btn)
		{
			Btn->SetIsEnabled(bEnable);
		}
	}
}

void UFELQuizWidget::OnAnswerLockoutExpired()
{
	SetAnswerInputLocked(false);
	++CurrentOrdinal;
	PresentCurrentQuestion();
}

void UFELQuizWidget::FinishQuiz()
{
	StopAcademyHudPump();
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(AnswerLockoutTimerHandle);
	}
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
		QuestionTextBlock->SetText(NSLOCTEXT("FEL", "QuizEmpty", "No academy items loaded."));
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
					if (bAcademyDuelMode)
					{
						if (!bAcademyCompletionDispatched)
						{
							bAcademyCompletionDispatched = true;
							CompleteAcademyDuelAndClose();
						}
					}
					else
					{
						FinishQuiz();
					}
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

		BindAnswerButton(Btn, a);

		if (UVerticalBoxSlot* VS = AnswerVerticalBox->AddChildToVerticalBox(Btn))
		{
			VS->SetPadding(FMargin(0.f, 6.f, 0.f, 0.f));
		}
		SpawnedAnswerButtons.Add(Btn);
	}
	UpdateAnswerButtonsInteractable();
}

void UFELQuizWidget::OnAnswerButtonClicked(const int32 AnswerIndex)
{
	if (bAnswerInputLocked)
	{
		return;
	}
	if (CurrentOrdinal >= ShuffledOrder.Num() || QuestionBank.Num() == 0)
	{
		return;
	}

	const int32 BankIdx = ShuffledOrder[CurrentOrdinal];
	const FFELNeuroQuizItem& Item = QuestionBank[BankIdx];

	const bool bCorrect = (AnswerIndex == Item.CorrectIndex);

	if (bAcademyDuelMode && AcademySubsystem)
	{
		AcademySubsystem->RecordLocalAnswer(Item, bCorrect);
	}

	if (bCorrect)
	{
		ApplyCorrectAnswerBoost();
		++CurrentOrdinal;
		PresentCurrentQuestion();
		return;
	}

	if (bAcademyDuelMode && CachedGameInstance)
	{
		float PRQ = 75.f;
		if (UFELNeuroMechanicBridgeSubsystem* Br = CachedGameInstance->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			FFELReadinessSnapshot S;
			Br->GetCachedSnapshot(S);
			PRQ = static_cast<float>(S.PRQScore);
		}
		const float LockSec = FELTwelvePillarArenaGameplay::BrainBrawlWrongAnswerLockoutSec(PRQ, 2.2f);
		SetAnswerInputLocked(true);
		if (UWorld* W = GetWorld())
		{
			W->GetTimerManager().SetTimer(AnswerLockoutTimerHandle, this, &UFELQuizWidget::OnAnswerLockoutExpired, LockSec, false);
		}
		return;
	}

	++CurrentOrdinal;
	PresentCurrentQuestion();
}

void UFELQuizWidget::ApplyCorrectAnswerBoost() const
{
	if (!CachedGameInstance)
	{
		return;
	}
	UFELNeuroMechanicBridgeSubsystem* Bridge = CachedGameInstance->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>();
	if (!Bridge)
	{
		return;
	}
	Bridge->ApplyTemporaryPRQBoost(4.0, 18.0f);
}

void UFELQuizWidget::BindAnswerButton(UButton* Btn, int32 AnswerIndex)
{
	if (!Btn)
	{
		return;
	}
	switch (AnswerIndex)
	{
	case 0:
		Btn->OnClicked.AddDynamic(this, &UFELQuizWidget::OnAnswerClicked0);
		break;
	case 1:
		Btn->OnClicked.AddDynamic(this, &UFELQuizWidget::OnAnswerClicked1);
		break;
	case 2:
		Btn->OnClicked.AddDynamic(this, &UFELQuizWidget::OnAnswerClicked2);
		break;
	case 3:
		Btn->OnClicked.AddDynamic(this, &UFELQuizWidget::OnAnswerClicked3);
		break;
	case 4:
		Btn->OnClicked.AddDynamic(this, &UFELQuizWidget::OnAnswerClicked4);
		break;
	case 5:
		Btn->OnClicked.AddDynamic(this, &UFELQuizWidget::OnAnswerClicked5);
		break;
	case 6:
		Btn->OnClicked.AddDynamic(this, &UFELQuizWidget::OnAnswerClicked6);
		break;
	case 7:
		Btn->OnClicked.AddDynamic(this, &UFELQuizWidget::OnAnswerClicked7);
		break;
	default:
		break;
	}
}

void UFELQuizWidget::OnAnswerClicked0()
{
	OnAnswerButtonClicked(0);
}

void UFELQuizWidget::OnAnswerClicked1()
{
	OnAnswerButtonClicked(1);
}

void UFELQuizWidget::OnAnswerClicked2()
{
	OnAnswerButtonClicked(2);
}

void UFELQuizWidget::OnAnswerClicked3()
{
	OnAnswerButtonClicked(3);
}

void UFELQuizWidget::OnAnswerClicked4()
{
	OnAnswerButtonClicked(4);
}

void UFELQuizWidget::OnAnswerClicked5()
{
	OnAnswerButtonClicked(5);
}

void UFELQuizWidget::OnAnswerClicked6()
{
	OnAnswerButtonClicked(6);
}

void UFELQuizWidget::OnAnswerClicked7()
{
	OnAnswerButtonClicked(7);
}
