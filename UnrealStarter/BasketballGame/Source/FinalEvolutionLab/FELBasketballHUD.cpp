// Copyright (c) Final Evolution Lab.

#include "FELBasketballHUD.h"
#include "UFELAthleteHubWidget.h"
#include "FELArenaModeDefinitions.h"
#include "FELArenaModeUX.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "UFELKickReturnSessionSubsystem.h"
#include "UFELBaseballBattingSubsystem.h"
#include "Engine/GameInstance.h"
#include "FinalEvolutionLab.h"
#include "Blueprint/UserWidget.h"
#include "Engine/Canvas.h"
#include "Engine/Engine.h"
#include "GameFramework/PlayerController.h"

void AFELBasketballHUD::BeginPlay()
{
	Super::BeginPlay();
	APlayerController* PC = GetOwningPlayerController();
	if (!PC)
	{
		return;
	}
	const TSubclassOf<UFELAthleteHubWidget> Cls = AthleteHubWidgetClass
		? AthleteHubWidgetClass
		: TSubclassOf<UFELAthleteHubWidget>(UFELAthleteHubWidget::StaticClass());
	if (UFELAthleteHubWidget* W = CreateWidget<UFELAthleteHubWidget>(PC, Cls))
	{
		W->AddToViewport(50);
		AthleteHubWidget = W;
	}
}

static FString FormatTime(float Seconds)
{
	const int32 Total = FMath::Max(0, FMath::CeilToInt(Seconds));
	const int32 M = Total / 60;
	const int32 S = Total % 60;
	return FString::Printf(TEXT("%d:%02d"), M, S);
}

void AFELBasketballHUD::DrawHUD()
{
	Super::DrawHUD();

	if (!Canvas || !GetWorld())
	{
		return;
	}

	const AFELBasketballGameState* GS = GetWorld()->GetGameState<AFELBasketballGameState>();
	if (!GS)
	{
		return;
	}

	AFELBasketballGameMode* AuthGM = GetWorld()->GetAuthGameMode<AFELBasketballGameMode>();
	const EFELArenaMode HudMode = AuthGM ? AuthGM->CurrentMode : EFELArenaMode::BasketballHeadToHead;

	UFont* Font = GEngine ? GEngine->GetSmallFont() : nullptr;
	float Y = 40.f;
	const float LineStep = 36.f;

	DrawText(FString::Printf(TEXT("Mode: %s"), *GS->GetModeDisplayName()), FLinearColor(0.7f, 0.9f, 1.f, 1.f), 48.f, Y, Font, 1.15f, false);
	Y += LineStep;

	DrawText(FELArenaModeUX::GetObjectiveSubtitle(HudMode), FLinearColor(0.58f, 0.68f, 0.8f, 1.f), 48.f, Y, Font, 0.9f, false);
	Y += 30.f;

	DrawText(GS->GetPRQHUDLine(), FLinearColor(0.55f, 1.f, 0.75f, 1.f), 48.f, Y, Font, 1.05f, false);
	Y += LineStep;

	const FString AttrLine = GS->GetArenaAttributeHUDLine();
	if (!AttrLine.IsEmpty())
	{
		DrawText(AttrLine, FLinearColor(0.85f, 0.85f, 1.f, 1.f), 48.f, Y, Font, 1.05f, false);
		Y += LineStep;
	}

	const FString DunkStyle = GS->GetDunkContestStyleHUDLine();
	if (!DunkStyle.IsEmpty())
	{
		DrawText(DunkStyle, FLinearColor(1.f, 0.55f, 0.2f, 1.f), 48.f, Y, Font, 1.08f, false);
		Y += LineStep;
	}

	const FString StreetJam = GS->GetStreetJamHUDLine();
	if (!StreetJam.IsEmpty())
	{
		DrawText(StreetJam, FLinearColor(0.35f, 1.f, 0.55f, 1.f), 48.f, Y, Font, 1.06f, false);
		Y += LineStep;
	}

	if (AuthGM)
	{
		if (AuthGM->CurrentMode == EFELArenaMode::Football)
		{
			if (UGameInstance* GI = GetWorld()->GetGameInstance())
			{
				if (const UFELKickReturnSessionSubsystem* Kr = GI->GetSubsystem<UFELKickReturnSessionSubsystem>())
				{
					const FString KrLine = Kr->BuildHudLine();
					if (!KrLine.IsEmpty())
					{
						DrawText(KrLine, FLinearColor(1.f, 0.92f, 0.35f, 1.f), 48.f, Y, Font, 1.02f, false);
						Y += LineStep;
					}
				}
			}
		}
		if (AuthGM->CurrentMode == EFELArenaMode::Baseball)
		{
			if (UGameInstance* GI = GetWorld()->GetGameInstance())
			{
				if (const UFELBaseballBattingSubsystem* Bb = GI->GetSubsystem<UFELBaseballBattingSubsystem>())
				{
					const FString BLine = Bb->BuildHudLine();
					if (!BLine.IsEmpty())
					{
						DrawText(BLine, FLinearColor(0.45f, 0.95f, 1.f, 1.f), 48.f, Y, Font, 1.04f, false);
						Y += LineStep;
					}
				}
			}
		}
	}

	const FString ScoreNoun = FELArenaModeUX::GetScoreTerm(HudMode);
	FString ScoreLine;
	if (!GS->IsScoringEnabled())
	{
		ScoreLine = (HudMode == EFELArenaMode::BrainBrawl)
			? TEXT("Quiz — basket scoring is off; finish the round using the prompts.")
			: TEXT("Practice — scoring is off for this session.");
	}
	else if (GS->GetTargetScore() > 0)
	{
		ScoreLine = FString::Printf(TEXT("%s: %d / %d"), *ScoreNoun, GS->GetScore(), GS->GetTargetScore());
	}
	else
	{
		ScoreLine = FString::Printf(TEXT("%s: %d"), *ScoreNoun, GS->GetScore());
	}

	DrawText(ScoreLine, FLinearColor::White, 48.f, Y, Font, 1.45f, false);
	Y += LineStep;

	if (GS->GetTimeRemaining() > 0.f && !GS->HasMatchEnded())
	{
		DrawText(FString::Printf(TEXT("Time: %s"), *FormatTime(GS->GetTimeRemaining())), FLinearColor(1.f, 0.85f, 0.4f, 1.f), 48.f, Y, Font, 1.2f, false);
		Y += LineStep;
	}

	if (GS->HasMatchEnded())
	{
		DrawText(
			TEXT("Session complete — movement is locked until you leave or restart."),
			FLinearColor(0.72f, 0.72f, 0.78f, 1.f),
			48.f,
			Y,
			Font,
			0.92f,
			false);
	}
	else
	{
		DrawText(FELArenaModeUX::GetControlFooterHint(HudMode), FLinearColor(0.75f, 0.75f, 0.75f, 1.f), 48.f, Y, Font, 0.95f, false);
	}

	if (GS->HasMatchEnded())
	{
		const float CX = Canvas->ClipX * 0.5f;
		const float CY = Canvas->ClipY * 0.42f;
		float XL = 0.f;
		float YL = 0.f;

		const FString& Banner = GS->GetMatchEndBanner();
		GetTextSize(Banner, XL, YL, Font, 2.4f);
		DrawText(Banner, FLinearColor(1.f, 1.f, 0.4f, 1.f), CX - XL * 0.5f, CY, Font, 2.4f, false);

		const FString& Detail = GS->GetMatchEndDetail();
		GetTextSize(Detail, XL, YL, Font, 1.35f);
		DrawText(Detail, FLinearColor::White, CX - XL * 0.5f, CY + 52.f, Font, 1.35f, false);

		const FString Hint = TEXT("Return to the menu or restart the session to play again.");
		GetTextSize(Hint, XL, YL, Font, 1.f);
		DrawText(Hint, FLinearColor(0.8f, 0.8f, 0.8f, 1.f), CX - XL * 0.5f, CY + 96.f, Font, 1.f, false);
	}
}
