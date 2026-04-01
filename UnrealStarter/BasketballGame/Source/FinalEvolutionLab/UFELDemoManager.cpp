// Copyright (c) Final Evolution Lab.

#include "UFELDemoManager.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballModes.h"
#include "FELPerfectFormChecklistWidget.h"
#include "FELArenaRulesTypes.h"
#include "UFELArenaModeData.h"
#include "FELMatchTypes.h"
#include "Animation/AnimInstance.h"
#include "Animation/AnimMontage.h"
#include "Engine/SkeletalMesh.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/PlayerStart.h"
#include "Kismet/GameplayStatics.h"

UFELDemoManager::UFELDemoManager()
{
	PrimaryComponentTick.bCanEverTick = false;
	DemonstratorClass = AFELExerciseDemonstrator::StaticClass();
}

AFELBasketballGameMode* UFELDemoManager::GetFELGameMode() const
{
	return Cast<AFELBasketballGameMode>(GetOwner());
}

bool UFELDemoManager::CanExerciseDemoRunThisPhase(const AFELBasketballGameMode* GM) const
{
	if (!GM)
	{
		return false;
	}
	switch (ExerciseDemoPhasePolicy)
	{
	case EFELExerciseDemoGameplayPolicy::PreMatchOnly:
		return GM->MatchPhase == EFELMatchPhase::WaitingToStart;
	case EFELExerciseDemoGameplayPolicy::PracticeOpenPlay:
		return GM->MatchPhase == EFELMatchPhase::WaitingToStart
			|| (GM->MatchPhase == EFELMatchPhase::InProgress && GM->PlayMode == EFELBasketballPlayMode::Practice);
	case EFELExerciseDemoGameplayPolicy::AnyExceptMatchComplete:
		return GM->MatchPhase != EFELMatchPhase::MatchComplete;
	default:
		return false;
	}
}

void UFELDemoManager::TriggerExerciseDemo(UAnimMontage* OptionalDemonstrationMontage, float PRQOverride0to100)
{
	AFELBasketballGameMode* GM = GetFELGameMode();
	if (!GM || !CanExerciseDemoRunThisPhase(GM))
	{
		return;
	}
	UWorld* World = GetWorld();
	if (!World)
	{
		return;
	}
	APlayerController* PC = World->GetFirstPlayerController();
	if (!PC)
	{
		return;
	}

	EndExerciseDemoIfActive();

	const FFELSportNeuroConstants& SN = GM->CurrentArenaRules.SportNeuro;
	USkeletalMesh* Mesh = nullptr;
	if (SN.DemonstratorSkeletalMesh.IsValid())
	{
		Mesh = SN.DemonstratorSkeletalMesh.LoadSynchronous();
	}
	TSubclassOf<UAnimInstance> AnimClass = nullptr;
	if (SN.DemonstratorAnimInstanceClass.IsValid())
	{
		AnimClass = SN.DemonstratorAnimInstanceClass.LoadSynchronous();
	}
	if (!Mesh)
	{
#if !UE_BUILD_SHIPPING
		UE_LOG(LogTemp, Warning,
			TEXT("FEL: TriggerExerciseDemo — no DemonstratorSkeletalMesh (assign in UFELArenaModeData / SportNeuro)."));
#endif
		return;
	}

	const TSubclassOf<AFELExerciseDemonstrator> DClass = DemonstratorClass
		? DemonstratorClass
		: TSubclassOf<AFELExerciseDemonstrator>(AFELExerciseDemonstrator::StaticClass());
	FVector Loc = FVector::ZeroVector;
	FRotator Rot = FRotator::ZeroRotator;
	if (APawn* Pawn = PC->GetPawn())
	{
		Loc = Pawn->GetActorLocation() + Pawn->GetActorForwardVector() * DemonstratorOffsetFromPlayerCM + FVector(0.f, 0.f, 8.f);
		Rot = Pawn->GetActorRotation();
	}
	else
	{
		TArray<AActor*> Starts;
		UGameplayStatics::GetAllActorsOfClass(World, APlayerStart::StaticClass(), Starts);
		if (Starts.Num() > 0 && Starts[0])
		{
			Loc = Starts[0]->GetActorLocation() + Starts[0]->GetActorForwardVector() * DemonstratorOffsetFromPlayerCM;
			Rot = Starts[0]->GetActorRotation();
		}
	}

	FActorSpawnParameters Sp;
	Sp.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
	AFELExerciseDemonstrator* Demo = World->SpawnActor<AFELExerciseDemonstrator>(DClass, Loc, Rot, Sp);
	if (!Demo)
	{
		return;
	}
	const float PRQ = (PRQOverride0to100 >= 0.f) ? PRQOverride0to100 : GM->GetNeuroPRQScoreFloat();
	const float Leak = GM->GetNeuroKineticLeakageMultiplierFloat();
	Demo->ConfigureDemonstrator(Mesh, AnimClass, 1.f);
	Demo->ApplyDemonstrationPlayRateFromNeuro(PRQ, Leak);
	if (OptionalDemonstrationMontage)
	{
		Demo->OnDemonstrationMontageEnded.AddDynamic(this, &UFELDemoManager::HandleDemonstrationMontageEnded);
		Demo->PlayDemonstrationMontage(OptionalDemonstrationMontage);
	}
	ActiveDemonstrator = Demo;
	PC->SetViewTargetWithBlend(Demo, ExerciseDemoCameraBlendInSeconds, EViewTargetBlendFunction::VTBlend_Cubic);

	FFELArenaHUDConfig Hud;
	if (GM->LoadedArenaModeData)
	{
		Hud = GM->LoadedArenaModeData->Hud;
	}
	ShowPerfectFormOverlay(Hud);
}

void UFELDemoManager::HandleDemonstrationMontageEnded(bool bInterrupted)
{
	(void)bInterrupted;
	if (!bEndDemoWhenDemonstrationMontageCompletes)
	{
		return;
	}
	EndExerciseDemoIfActive();
}

void UFELDemoManager::EndExerciseDemoIfActive()
{
	HidePerfectFormOverlay();
	if (ActiveDemonstrator.IsValid())
	{
		ActiveDemonstrator->OnDemonstrationMontageEnded.RemoveAll(this);
	}
	if (!ActiveDemonstrator.IsValid())
	{
		return;
	}
	UWorld* World = GetWorld();
	APlayerController* PC = World ? World->GetFirstPlayerController() : nullptr;
	if (PC && PC->GetPawn())
	{
		PC->SetViewTargetWithBlend(PC->GetPawn(), ExerciseDemoCameraBlendOutSeconds, EViewTargetBlendFunction::VTBlend_Cubic);
	}
	if (ActiveDemonstrator.IsValid())
	{
		ActiveDemonstrator->Destroy();
	}
	ActiveDemonstrator = nullptr;
}

void UFELDemoManager::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	EndExerciseDemoIfActive();
	Super::EndPlay(EndPlayReason);
}

void UFELDemoManager::ShowPerfectFormOverlay(const FFELArenaHUDConfig& Hud)
{
	if (!Hud.bShowPerfectFormPanel || Hud.PerfectFormChecklistLines.Num() == 0)
	{
		return;
	}
	APlayerController* PC = GetWorld() ? GetWorld()->GetFirstPlayerController() : nullptr;
	if (!PC)
	{
		return;
	}
	const TSubclassOf<UUserWidget> Cls = PerfectFormChecklistWidgetClass
		? PerfectFormChecklistWidgetClass
		: TSubclassOf<UUserWidget>(UFELPerfectFormChecklistWidget::StaticClass());
	UUserWidget* W = CreateWidget<UUserWidget>(PC, Cls);
	if (!W)
	{
		return;
	}
	if (UFELPerfectFormChecklistWidget* Check = Cast<UFELPerfectFormChecklistWidget>(W))
	{
		Check->InitializeChecklist(Hud.PerfectFormChecklistLines, Hud.PerfectFormChecklistFontScale);
	}
	W->AddToViewport(210);
	ActivePerfectFormWidget = W;
}

void UFELDemoManager::HidePerfectFormOverlay()
{
	if (ActivePerfectFormWidget.IsValid())
	{
		ActivePerfectFormWidget->RemoveFromParent();
	}
	ActivePerfectFormWidget = nullptr;
}
