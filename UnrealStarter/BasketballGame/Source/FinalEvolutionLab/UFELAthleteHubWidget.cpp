// Copyright (c) Final Evolution Lab.

#include "UFELAthleteHubWidget.h"
#include "Engine/GameInstance.h"
#include "FELBasketballCharacter.h"
#include "FELNeuroMechanicBridgeSubsystem.h"
#include "FELReadinessTypes.h"
#include "Components/ProgressBar.h"
#include "Components/TextBlock.h"
#include "Components/Widget.h"
#include "Fonts/CompositeFont.h"
#include "GameFramework/PlayerController.h"
#include "Engine/Engine.h"
#include "Engine/World.h"
#include "Misc/Paths.h"
#include "Styling/SlateTypes.h"
#include "TimerManager.h"

void UFELAthleteHubWidget::ApplyNeuroMechanicProBroadcastStyle()
{
	const FString MonoPath = FPaths::EngineContentDir() / TEXT("Slate/Fonts/RobotoMono-Regular.ttf");
	const FString FallbackPath = FPaths::EngineContentDir() / TEXT("Slate/Fonts/Roboto-Regular.ttf");
	const FString UsePath = FPaths::FileExists(MonoPath) ? MonoPath : FallbackPath;
	const TSharedRef<const FCompositeFont> HubComposite = MakeShared<FCompositeFont>(
		FName(TEXT("FELAthleteHub")),
		UsePath,
		EFontHinting::Default,
		EFontLoadingPolicy::Stream);
	const FSlateFontInfo MonoFont(HubComposite, 13.f);

	auto StyleText = [&MonoFont](UTextBlock* TB)
	{
		if (!TB)
		{
			return;
		}
		TB->SetFont(MonoFont);
		TB->SetColorAndOpacity(FLinearColor(0.78f, 0.93f, 1.f, 0.96f));
	};
	StyleText(PRQValueText);
	StyleText(PrimedStatusText);
	StyleText(CreatorIdentityText);
	StyleText(DecoderAnkleWhy);
	StyleText(DecoderKneeWhy);
	StyleText(DecoderHipWhy);
	StyleText(DecoderAnkleFix);
	StyleText(DecoderKneeFix);
	StyleText(DecoderHipFix);

	auto StyleBar = [](UProgressBar* Bar)
	{
		if (!Bar)
		{
			return;
		}
		Bar->SetFillColorAndOpacity(FLinearColor(0.15f, 0.88f, 1.f, 0.9f));
	};
	auto StyleGlassGauge = [](UProgressBar* Bar)
	{
		if (!Bar)
		{
			return;
		}
		FProgressBarStyle S = Bar->GetWidgetStyle();
		S.BackgroundImage.TintColor = FSlateColor(FLinearColor(0.06f, 0.14f, 0.22f, 0.42f));
		Bar->SetWidgetStyle(S);
		Bar->SetFillColorAndOpacity(FLinearColor(0.2f, 0.95f, 1.f, 0.88f));
		Bar->SetRenderOpacity(0.94f);
	};
	StyleBar(PRQGaugeBar);
	StyleBar(HeatAnkleBar);
	StyleBar(HeatKneeBar);
	StyleBar(HeatHipBar);
	StyleGlassGauge(SprintBar);
	StyleGlassGauge(GatherBar);

	SetColorAndOpacity(FLinearColor(1.f, 1.f, 1.f, 0.94f));
}

void UFELAthleteHubWidget::NativeConstruct()
{
	Super::NativeConstruct();
	ApplyNeuroMechanicProBroadcastStyle();
#if UE_BUILD_SHIPPING
	{
		const auto Collapse = [](UWidget* W)
		{
			if (W)
			{
				W->SetVisibility(ESlateVisibility::Collapsed);
			}
		};
		Collapse(PRQValueText);
		Collapse(PRQGaugeBar);
		Collapse(HeatAnkleBar);
		Collapse(HeatKneeBar);
		Collapse(HeatHipBar);
		Collapse(SprintBar);
		Collapse(GatherBar);
		Collapse(DecoderAnkleWhy);
		Collapse(DecoderKneeWhy);
		Collapse(DecoderHipWhy);
		Collapse(DecoderAnkleFix);
		Collapse(DecoderKneeFix);
		Collapse(DecoderHipFix);
	}
#endif
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			Br->OnReadinessApplied.AddDynamic(this, &UFELAthleteHubWidget::HandleReadinessApplied);
			if (Br->HasCachedSnapshot())
			{
				FFELReadinessSnapshot S;
				Br->GetCachedSnapshot(S);
				const double PRQ = FMath::Clamp(S.PRQScore, 0.0, 100.0);
				const bool bPrimed = S.bAthletePrimed || PRQ >= 85.0;
				SetHubFromReadiness(PRQ, bPrimed, S.KineticHeatAnkle, S.KineticHeatKnee, S.KineticHeatHip);
				SetMovementDecoderFromHeat(S.KineticHeatAnkle, S.KineticHeatKnee, S.KineticHeatHip);
				ApplyIdentityHandshakeFromSnapshot(S);
			}
		}
	}
#if !UE_BUILD_SHIPPING
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().SetTimer(
			PawnPollTimer,
			FTimerDelegate::CreateUObject(this, &UFELAthleteHubWidget::PollEngineMovementForHub),
			0.033f,
			true);
	}
#endif
}

void UFELAthleteHubWidget::NativeDestruct()
{
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			Br->OnReadinessApplied.RemoveDynamic(this, &UFELAthleteHubWidget::HandleReadinessApplied);
		}
	}
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(PawnPollTimer);
	}
	Super::NativeDestruct();
}

void UFELAthleteHubWidget::PollEngineMovementForHub()
{
	APlayerController* PC = GetOwningPlayer();
	if (!PC)
	{
		return;
	}
	AFELBasketballCharacter* Ch = Cast<AFELBasketballCharacter>(PC->GetPawn());
	if (!Ch)
	{
		return;
	}
	if (SprintBar)
	{
		SprintBar->SetPercent(Ch->GetSprintGauge01());
	}
	if (GatherBar)
	{
		GatherBar->SetPercent(Ch->GetGatherNeuralDrive01());
	}
}

void UFELAthleteHubWidget::SetHubFromReadiness(double PRQ, bool bPrimed, double HeatAnkle, double HeatKnee, double HeatHip)
{
	const double ClampedPRQ = FMath::Clamp(PRQ, 0.0, 100.0);
	RefreshVisuals(ClampedPRQ, bPrimed, HeatAnkle, HeatKnee, HeatHip);
}

void UFELAthleteHubWidget::RefreshVisuals(double PRQ, bool bPrimed, double A, double K, double H)
{
	if (PrimedStatusText)
	{
		PrimedStatusText->SetText(FText::FromString(bPrimed ? TEXT("Peak readiness") : TEXT("Calibrating")));
	}
#if !UE_BUILD_SHIPPING
	if (PRQValueText)
	{
		PRQValueText->SetText(FText::FromString(FString::Printf(TEXT("%.0f"), PRQ)));
	}
	if (PRQGaugeBar)
	{
		PRQGaugeBar->SetPercent(static_cast<float>(PRQ / 100.0));
	}
	const float a = static_cast<float>(FMath::Clamp(A, 0.0, 1.0));
	const float k = static_cast<float>(FMath::Clamp(K, 0.0, 1.0));
	const float h = static_cast<float>(FMath::Clamp(H, 0.0, 1.0));
	if (HeatAnkleBar)
	{
		HeatAnkleBar->SetPercent(a);
	}
	if (HeatKneeBar)
	{
		HeatKneeBar->SetPercent(k);
	}
	if (HeatHipBar)
	{
		HeatHipBar->SetPercent(h);
	}
#endif
}

void UFELAthleteHubWidget::SetMovementDecoderFromHeat(double HeatAnkle, double HeatKnee, double HeatHip)
{
#if UE_BUILD_SHIPPING
	(void)HeatAnkle;
	(void)HeatKnee;
	(void)HeatHip;
	return;
#else
	using namespace FELMovementDecoderAcademy;

	auto SetWhy = [](UTextBlock* TB, EJointDecoder J, double H)
	{
		if (!TB)
		{
			return;
		}
		const FString T = WhyMattersText(J, H);
		TB->SetText(FText::FromString(T.IsEmpty() ? TEXT("—") : T));
	};
	auto SetFix = [](UTextBlock* TB, EJointDecoder J, double H)
	{
		if (!TB)
		{
			return;
		}
		const FString Id = PrimaryFixModuleId(J, H);
		TB->SetText(FText::FromString(Id.IsEmpty() ? TEXT("—") : Id));
	};

	SetWhy(DecoderAnkleWhy, EJointDecoder::Ankle, HeatAnkle);
	SetWhy(DecoderKneeWhy, EJointDecoder::Knee, HeatKnee);
	SetWhy(DecoderHipWhy, EJointDecoder::Hip, HeatHip);
	SetFix(DecoderAnkleFix, EJointDecoder::Ankle, HeatAnkle);
	SetFix(DecoderKneeFix, EJointDecoder::Knee, HeatKnee);
	SetFix(DecoderHipFix, EJointDecoder::Hip, HeatHip);
#endif
}

void UFELAthleteHubWidget::ApplyIdentityHandshakeFromSnapshot(const FFELReadinessSnapshot& S)
{
	if (!CreatorIdentityText)
	{
		return;
	}
	const double PRQ = FMath::Clamp(S.PRQScore, 0.0, 100.0);
	const FString Id = S.StoodCreatorCardId.TrimStartAndEnd();
	const FString Trait = S.StoodCreatorCardTraitLine.TrimStartAndEnd();
	const FString Tier = S.StoodCardTier.TrimStartAndEnd();
	FString Line;
	if (!Trait.IsEmpty())
	{
		Line = FString::Printf(TEXT("Athlete readiness %.0f · Creator Card · %s"), PRQ, *Trait);
	}
	else if (!Id.IsEmpty())
	{
		Line = FString::Printf(TEXT("Athlete readiness %.0f · Creator Card · %s"), PRQ, *Id);
	}
	else if (!Tier.IsEmpty() && Tier != TEXT("standard"))
	{
		Line = FString::Printf(TEXT("Athlete readiness %.0f · Creator Card · tier %s"), PRQ, *Tier);
	}
	else
	{
		Line = FString::Printf(TEXT("Athlete readiness %.0f · Awaiting profile / scan sync"), PRQ);
	}
	CreatorIdentityText->SetText(FText::FromString(Line));
	CreatorIdentityText->SetVisibility(ESlateVisibility::HitTestInvisible);
}

void UFELAthleteHubWidget::HandleReadinessApplied(const FFELReadinessSnapshot& Snapshot)
{
	const double PRQ = FMath::Clamp(Snapshot.PRQScore, 0.0, 100.0);
	const bool bPrimed = Snapshot.bAthletePrimed || PRQ >= 85.0;
	SetHubFromReadiness(PRQ, bPrimed, Snapshot.KineticHeatAnkle, Snapshot.KineticHeatKnee, Snapshot.KineticHeatHip);
	SetMovementDecoderFromHeat(Snapshot.KineticHeatAnkle, Snapshot.KineticHeatKnee, Snapshot.KineticHeatHip);
	ApplyIdentityHandshakeFromSnapshot(Snapshot);
}
