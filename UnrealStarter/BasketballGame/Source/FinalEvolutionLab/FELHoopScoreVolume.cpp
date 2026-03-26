// Copyright (c) Final Evolution Lab.

#include "FELHoopScoreVolume.h"
#include "FELBasketballActor.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "UFELStreetJamSessionSubsystem.h"
#include "FinalEvolutionLab.h"
#include "Engine/GameInstance.h"
#include "Components/BoxComponent.h"
#include "Engine/World.h"
#include "GameFramework/GameStateBase.h"

AFELHoopScoreVolume::AFELHoopScoreVolume()
{
	PrimaryActorTick.bCanEverTick = false;

	TriggerBox = CreateDefaultSubobject<UBoxComponent>(TEXT("TriggerBox"));
	SetRootComponent(TriggerBox);
	TriggerBox->InitBoxExtent(FVector(100.f, 100.f, 140.f));
	TriggerBox->SetCollisionProfileName(TEXT("OverlapAllDynamic"));
	TriggerBox->SetGenerateOverlapEvents(true);
}

void AFELHoopScoreVolume::BeginPlay()
{
	Super::BeginPlay();
	TriggerBox->OnComponentBeginOverlap.AddDynamic(this, &AFELHoopScoreVolume::OnTriggerOverlap);
}

void AFELHoopScoreVolume::OnTriggerOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
	UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult)
{
	if (!OtherActor || !GetWorld())
	{
		return;
	}

	if (!Cast<AFELBasketballActor>(OtherActor))
	{
		return;
	}

	const float Now = GetWorld()->GetTimeSeconds();
	if (Now - LastScoreWorldTime < ScoreCooldownSeconds)
	{
		return;
	}
	LastScoreWorldTime = Now;

	if (AFELBasketballGameState* GS = GetWorld()->GetGameState<AFELBasketballGameState>())
	{
		if (GS->IsScoringEnabled() && !GS->HasMatchEnded())
		{
			int32 Pts = PointsPerBucket;
			if (GS->IsDunkContestArcadeActive())
			{
				Pts = FMath::Max(1, FMath::RoundToInt(static_cast<float>(PointsPerBucket) * GS->GetDunkContestScoreMultiplier()));
			}
			else if (GS->IsStreetJamArcadeActive())
			{
				Pts = FMath::Max(1, FMath::RoundToInt(static_cast<float>(PointsPerBucket) * GS->GetStreetJamScoreMultiplier()));
			}
			GS->AddScore(Pts);
			if (GS->IsStreetJamArcadeActive())
			{
				if (UGameInstance* GI = GetWorld()->GetGameInstance())
				{
					if (UFELStreetJamSessionSubsystem* Jam = GI->GetSubsystem<UFELStreetJamSessionSubsystem>())
					{
						if (AFELBasketballGameMode* GM = GetWorld()->GetAuthGameMode<AFELBasketballGameMode>())
						{
							const int32 Bonus = Jam->NotifyBucketScored(GM, GS);
							if (Bonus > 0)
							{
								GS->AddScore(Bonus);
							}
						}
					}
				}
			}
		}
	}
}
