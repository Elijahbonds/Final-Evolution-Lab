// Copyright (c) Final Evolution Lab.

#include "FELBasketballGameMode.h"
#include "FELArenaBridge.h"
#include "FELArenaModeCatalog.h"
#include "FELArenaRulesRegistry.h"
#include "IFELBiometricReceiver.h"
#include "FELBasketballActor.h"
#include "FELBasketballCharacter.h"
#include "FELBasketballGameState.h"
#include "FELBasketballHUD.h"
#include "FELBasketballPlayerController.h"
#include "FELArenaModeDefinitions.h"
#include "FELNeuroMechanicBridgeSubsystem.h"
#include "FELPlatformPaths.h"
#include "FELProgressionSubsystem.h"
#include "FELQuizWidget.h"
#include "FELSessionExport.h"
#include "UFELAcademySubsystem.h"
#include "FELSportMastery.h"
#include "FELOnboardingWidget.h"
#include "FELNativeBridge.h"
#include "FELMatchResultsWidget.h"
#include "UFELArenaModeData.h"
#include "UFELAssetRegistrySubsystem.h"
#include "FinalEvolutionLab.h"
#include "Blueprint/UserWidget.h"
#include "Engine/World.h"
#include "FELVenueShopFlyByDirector.h"
#include "GameFramework/Actor.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/PlayerStart.h"
#include "GameFramework/SpectatorPawn.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"

namespace
{
	static double ComputeNeuroPerformanceScore(const double PRQ, const int32 ScoreBuckets, const int32 BrainBoosts)
	{
		const double P = FMath::Clamp(PRQ, 0.0, 100.0);
		const double S = FMath::Clamp(static_cast<double>(ScoreBuckets) * 4.0, 0.0, 40.0);
		const double B = FMath::Clamp(static_cast<double>(BrainBoosts) * 7.0, 0.0, 35.0);
		return FMath::Clamp(0.55 * P + 0.35 * S + B, 0.0, 100.0);
	}

	static double ComputeMentalSharpnessScore(const double PRQ, const int32 BrainBoosts)
	{
		const double P = FMath::Clamp(PRQ, 0.0, 100.0);
		const double B = FMath::Clamp(static_cast<double>(BrainBoosts) * 12.0, 0.0, 48.0);
		return FMath::Clamp(0.45 * P + B, 0.0, 100.0);
	}
}

AFELBasketballGameMode::AFELBasketballGameMode()
{
	PrimaryActorTick.bCanEverTick = true;

	// 3D Digital Twin: skeletal mesh pawn (`AFELBasketballCharacter`), not a 2D spectator sprite.
	DefaultPawnClass = AFELBasketballCharacter::StaticClass();
	PlayerControllerClass = AFELBasketballPlayerController::StaticClass();
	BallClass = AFELBasketballActor::StaticClass();
	GameStateClass = AFELBasketballGameState::StaticClass();
	HUDClass = AFELBasketballHUD::StaticClass();
	DemoManager = CreateDefaultSubobject<UFELDemoManager>(TEXT("FELDemoManager"));
}

void AFELBasketballGameMode::PostInitializeComponents()
{
	Super::PostInitializeComponents();

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Bridge = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			FString Err;
			if (Bridge->TryLoadSnapshotIntoCacheOnly(Err))
			{
				FFELReadinessSnapshot Snap;
				Bridge->GetCachedSnapshot(Snap);
				ConfigureArenaFromReadinessSnapshot(Snap);
			}
			else
			{
				ConfigureArenaFromReadinessSnapshot(FFELReadinessSnapshot());
			}
		}
	}
}

void AFELBasketballGameMode::RestartPlayer(AController* NewPlayer)
{
	Super::RestartPlayer(NewPlayer);
	if (!NewPlayer || NewPlayer->GetPawn() != nullptr)
	{
		return;
	}
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	AActor* Start = FindPlayerStart(NewPlayer);
	if (!Start)
	{
		return;
	}
	UClass* SpecClass = SpectatorClass ? *SpectatorClass : ASpectatorPawn::StaticClass();
	if (!SpecClass)
	{
		return;
	}
	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;
	if (APawn* Sp = W->SpawnActor<APawn>(SpecClass, Start->GetActorLocation(), Start->GetActorRotation(), Params))
	{
		NewPlayer->Possess(Sp);
		UE_LOG(LogTemp, Warning, TEXT("FELGameMode: Default pawn missing after RestartPlayer — spectator fallback at %s"), *Start->GetActorLocation().ToString());
	}
}

void AFELBasketballGameMode::ConfigureArenaFromReadinessSnapshot(const FFELReadinessSnapshot& Snap)
{
	CurrentMode = FELArenaModeFromSwiftId(Snap.ActiveArenaMode);
	if (CurrentMode == EFELArenaMode::Unknown)
	{
		CurrentMode = EFELArenaMode::BasketballHeadToHead;
	}

	ApplyArenaRulesFromFactorySync();
	RequestArenaModeDataAsync();
}

void AFELBasketballGameMode::ApplyArenaRulesFromFactorySync()
{
	CurrentArenaRules = FELArenaRulesRegistry::GetMergedRules(CurrentMode);
	PlayMode = CurrentArenaRules.UnrealBasketballSlice;
	TimedBlitzSeconds = FMath::Max(5.f, CurrentArenaRules.TimeLimitSeconds);

	if (PlayMode == EFELBasketballPlayMode::HalfCourtShootout)
	{
		ShootoutTargetBuckets = FMath::Max(1, CurrentArenaRules.TargetScore);
	}
	else if (PlayMode == EFELBasketballPlayMode::FirstToTwentyOne)
	{
		FirstToNTargetBuckets = FMath::Max(1, CurrentArenaRules.TargetScore);
	}
}

void AFELBasketballGameMode::RequestArenaModeDataAsync()
{
	if (ArenaModeLoadHandle.IsValid())
	{
		ArenaModeLoadHandle->CancelHandle();
		ArenaModeLoadHandle.Reset();
	}

	const FSoftObjectPath Path = FELArenaModeCatalog::GetDefaultSoftPathForMode(CurrentMode);
	TArray<FSoftObjectPath> Paths;
	Paths.Add(Path);

	ArenaModeLoadHandle = ArenaModeStreamableManager.RequestAsyncLoad(
		Paths,
		FStreamableDelegate::CreateUObject(this, &AFELBasketballGameMode::OnArenaModeDataLoaded));
}

void AFELBasketballGameMode::OnArenaModeDataLoaded()
{
	UFELArenaModeData* DA = nullptr;
	if (ArenaModeLoadHandle.IsValid())
	{
		DA = Cast<UFELArenaModeData>(ArenaModeLoadHandle->GetLoadedAsset());
	}

	if (DA && DA->GetArenaMode() == CurrentMode)
	{
		LoadedArenaModeData = DA;
		CurrentArenaRules = DA->ArenaRules;
		FELArenaRulesRegistry::ApplyJsonOverridesToRules(CurrentMode, CurrentArenaRules);
		FELArenaRulesRegistry::SanitizeRulesInPlace(CurrentArenaRules, CurrentMode);
	}
	else
	{
		if (DA && DA->GetArenaMode() != CurrentMode)
		{
#if !UE_BUILD_SHIPPING
			UE_LOG(LogTemp, Warning,
				TEXT("FEL: UFELArenaModeData ArenaMode mismatch (expected %d, asset %d). Using factory merge."),
				static_cast<int32>(CurrentMode),
				static_cast<int32>(DA->GetArenaMode()));
#endif
		}
		LoadedArenaModeData = nullptr;
		ApplyArenaRulesFromFactorySync();
	}

	PlayMode = CurrentArenaRules.UnrealBasketballSlice;
	TimedBlitzSeconds = FMath::Max(5.f, CurrentArenaRules.TimeLimitSeconds);
	if (PlayMode == EFELBasketballPlayMode::HalfCourtShootout)
	{
		ShootoutTargetBuckets = FMath::Max(1, CurrentArenaRules.TargetScore);
	}
	else if (PlayMode == EFELBasketballPlayMode::FirstToTwentyOne)
	{
		FirstToNTargetBuckets = FMath::Max(1, CurrentArenaRules.TargetScore);
	}

	if (GetWorld() && GetWorld()->HasBegunPlay())
	{
		ApplyModeToGameState();
		BroadcastBiometricToWorld();
		if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
		{
			if (AFELBasketballPlayerController* BPC = Cast<AFELBasketballPlayerController>(PC))
			{
				BPC->ApplyArenaInputForMode(CurrentMode);
			}
		}
	}
}

FFELBiometricContext AFELBasketballGameMode::BuildBiometricContext() const
{
	FFELBiometricContext C;
	C.PRQScore = NeuroPRQScore;
	C.NeuralDrive = LoadedReadiness.NeuralDrive;
	C.PopForce = LoadedReadiness.PopForce;
	C.VerticalEstimateInches = NeuroVerticalEstimateInches;
	C.HangTimeScale = NeuroHangTimeScale;
	C.KineticLeakageMultiplier = NeuroKineticLeakageMultiplier;
	C.EfficiencyScore = LoadedReadiness.EfficiencyScore;
	C.bSFMASpiralRotationScreenPass = NeuroSFMA_SpiralRotationPass;
	return C;
}

void AFELBasketballGameMode::BroadcastBiometricToWorld()
{
	if (!GetWorld())
	{
		return;
	}
	const FFELBiometricContext Ctx = BuildBiometricContext();
	TArray<AActor*> Actors;
	UGameplayStatics::GetAllActorsWithInterface(GetWorld(), UFELBiometricReceiver::StaticClass(), Actors);
	for (AActor* A : Actors)
	{
		IFELBiometricReceiver::Execute_ApplyBiometricContext(A, Ctx);
	}
}

void AFELBasketballGameMode::ApplyModeSpecificBehaviors(const EFELArenaMode PreviousMode)
{
	if (PreviousMode == CurrentMode)
	{
		return;
	}
	switch (CurrentMode)
	{
	case EFELArenaMode::BrainBrawl:
		OnBrainBrawlModeActivated();
		break;
	case EFELArenaMode::BasketballDunkContest:
		OnDunkContestModeActivated();
		break;
	default:
		break;
	}
}

void AFELBasketballGameMode::OnBrainBrawlModeActivated_Implementation()
{
	if (!GetWorld())
	{
		return;
	}
	APlayerController* PC = GetWorld()->GetFirstPlayerController();
	if (!PC)
	{
		return;
	}
	const TSubclassOf<UFELQuizWidget> Cls = BrainBrawlQuizWidgetClass ? BrainBrawlQuizWidgetClass : UFELQuizWidget::StaticClass();
	UFELQuizWidget* Quiz = CreateWidget<UFELQuizWidget>(PC, Cls);
	if (!Quiz)
	{
		return;
	}
	Quiz->InitializeQuiz(GetGameInstance());
	Quiz->AddToViewport(120);
	PC->SetShowMouseCursor(true);
	FInputModeGameAndUI Mode;
	Mode.SetWidgetToFocus(Quiz->TakeWidget());
	Mode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
	PC->SetInputMode(Mode);
}

void AFELBasketballGameMode::OnDunkContestModeActivated_Implementation()
{
	// Dunk contest physics + rules come from snapshot + FFELArenaRules::bIsDunkContest (ApplyNeuroArenaGameplay on the pawn).
}

void AFELBasketballGameMode::RefreshArenaConfigurationFromSnapshot(const FFELReadinessSnapshot& Snap)
{
	const EFELArenaMode PreviousMode = CurrentMode;
	EFELArenaMode NewMode = FELArenaModeFromSwiftId(Snap.ActiveArenaMode);
	if (NewMode == EFELArenaMode::Unknown)
	{
		NewMode = EFELArenaMode::BasketballHeadToHead;
	}
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELAssetRegistrySubsystem* R = GI->GetSubsystem<UFELAssetRegistrySubsystem>())
		{
			if (PreviousMode != NewMode && PreviousMode != EFELArenaMode::Unknown)
			{
				R->PurgeVenueForMode(PreviousMode);
			}
		}
	}
	ConfigureArenaFromReadinessSnapshot(Snap);
	ApplyModeToGameState();
	ApplyModeSpecificBehaviors(PreviousMode);
}

void AFELBasketballGameMode::BeginPlay()
{
	Super::BeginPlay();
	UE_LOG(LogTemp, Warning, TEXT("GOLD MASTER: Level Tick Started"));
	if (UWorld* const W = GetWorld())
	{
		FELNativeBridge::NotifyLevelLoaded(W->GetMapName());

		const FString ShortMap = UGameplayStatics::GetCurrentLevelName(W, true);
		if (ShortMap.Contains(TEXT("Luma_Venice_Shop")) || ShortMap.Contains(TEXT("Luma_Venice")))
		{
			FActorSpawnParameters FlyParams;
			FlyParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
			W->SpawnActor<AFELVenueShopFlyByDirector>(AFELVenueShopFlyByDirector::StaticClass(), FVector::ZeroVector, FRotator::ZeroRotator, FlyParams);
		}
	}
}

void AFELBasketballGameMode::StartPlay()
{
	bLockedInputOnMatchEnd = false;
	bMatchCompletionHandled = false;
	MatchPhase = EFELMatchPhase::WaitingToStart;

	Super::StartPlay();

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELProgressionSubsystem* Prog = GI->GetSubsystem<UFELProgressionSubsystem>())
		{
			Prog->ResetSessionCounters();
		}
	}

	LoadedReadiness = FFELReadinessSnapshot();
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Bridge = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			FString Err;
			if (!Bridge->HasCachedSnapshot())
			{
				Bridge->TryLoadSnapshotIntoCacheOnly(Err);
			}
			if (Bridge->HasCachedSnapshot())
			{
				Bridge->GetCachedSnapshot(LoadedReadiness);
			}
		}
	}

	ConfigureArenaFromReadinessSnapshot(LoadedReadiness);

	ApplyModeToGameState();

	switch (CurrentArenaRules.BallSpawnType)
	{
	case EFELArenaBallSpawnType::None:
		break;
	case EFELArenaBallSpawnType::SingleAtPrimary:
		if (CurrentArenaRules.BallCount > 0)
		{
			SpawnMatchBallAtOffset(BallSpawnOffset);
		}
		break;
	case EFELArenaBallSpawnType::DualHalfCourt:
		SpawnMatchBallAtOffset(BallSpawnOffset);
		SpawnMatchBallAtOffset(SecondBallSpawnOffset);
		break;
	}

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Bridge = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			Bridge->ApplyReadiness(LoadedReadiness);
		}
	}

	SyncNeuroFieldsFromSnapshot(LoadedReadiness);

	if (AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>())
	{
		GS->SetReadinessContext(LoadedReadiness, GetArenaGameModeId());
	}

	BindGameStateMatchDelegate();
	if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
	{
		if (AFELBasketballPlayerController* BPC = Cast<AFELBasketballPlayerController>(PC))
		{
			BPC->ApplyArenaInputForMode(CurrentMode);
		}
	}
	MaybeStartMatchFlow();
}

void AFELBasketballGameMode::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (ArenaModeLoadHandle.IsValid())
	{
		ArenaModeLoadHandle->CancelHandle();
		ArenaModeLoadHandle.Reset();
	}
	EndExerciseDemoIfActive();
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(MatchStartCountdownTimer);
	}
	if (AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>())
	{
		GS->OnMatchEnded.RemoveDynamic(this, &AFELBasketballGameMode::HandleGameStateMatchEnded);
	}
	Super::EndPlay(EndPlayReason);
}

void AFELBasketballGameMode::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	if (MatchPhase == EFELMatchPhase::InProgress)
	{
		if (AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>())
		{
			GS->TickMatchTime(DeltaSeconds);
		}
	}

	if (AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>())
	{
		LockPlayerInputIfMatchEnded();
	}
}

void AFELBasketballGameMode::BindGameStateMatchDelegate()
{
	if (AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>())
	{
		GS->OnMatchEnded.AddDynamic(this, &AFELBasketballGameMode::HandleGameStateMatchEnded);
	}
}

void AFELBasketballGameMode::MaybeStartMatchFlow()
{
	if (!GetWorld())
	{
		return;
	}
	if (!FELPlatformPaths::HasCompletedLabOnboarding())
	{
		const TSubclassOf<UFELOnboardingWidget> Cls = LabOnboardingWidgetClass ? LabOnboardingWidgetClass : UFELOnboardingWidget::StaticClass();
		if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
		{
			UFELOnboardingWidget* W = CreateWidget<UFELOnboardingWidget>(PC, Cls);
			if (W)
			{
				W->InitializeLabOnboarding();
				W->OnDismissed.AddDynamic(this, &AFELBasketballGameMode::OnLabOnboardingDismissed);
				W->AddToViewport(200);
				PC->SetShowMouseCursor(true);
				FInputModeGameAndUI Mode;
				Mode.SetWidgetToFocus(W->TakeWidget());
				Mode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
				PC->SetInputMode(Mode);
				return;
			}
		}
	}
	StartMatchCountdown();
}

void AFELBasketballGameMode::OnLabOnboardingDismissed()
{
	EndExerciseDemoIfActive();
	StartMatchCountdown();
}

void AFELBasketballGameMode::StartMatchCountdown()
{
	MatchPhase = EFELMatchPhase::WaitingToStart;
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* B = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			B->SetBrainBrawlBoostCountingEnabled(false);
		}
	}
	if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
	{
		PC->SetIgnoreMoveInput(true);
	}
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().SetTimer(
			MatchStartCountdownTimer,
			this,
			&AFELBasketballGameMode::EnterMatchInProgressPhase,
			FMath::Max(0.1f, CountdownToStartSeconds),
			false);
	}
}

void AFELBasketballGameMode::EnterMatchInProgressPhase()
{
	MatchPhase = EFELMatchPhase::InProgress;
	ApplyModeSpecificBehaviors(EFELArenaMode::Unknown);
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* B = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			B->ResetBrainBrawlBoostCountForActivePhase();
			B->SetBrainBrawlBoostCountingEnabled(true);
		}
	}
	if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
	{
		PC->SetIgnoreMoveInput(false);
	}
}

void AFELBasketballGameMode::HandleGameStateMatchEnded()
{
	if (bMatchCompletionHandled || !GetWorld())
	{
		return;
	}
	bMatchCompletionHandled = true;
	MatchPhase = EFELMatchPhase::MatchComplete;

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* B = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			B->SetBrainBrawlBoostCountingEnabled(false);
		}
	}

	const FFELMatchResultSummary Summary = BuildMatchResultSummary();
	OnMatchComplete.Broadcast(Summary);
	FELNativeBridge::NotifyMatchCompleteIOSFeedback(Summary);

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELProgressionSubsystem* P = GI->GetSubsystem<UFELProgressionSubsystem>())
		{
			P->ApplyMatchRewards(Summary);
		}
	}

	FString Err;
	const bool bWroteSession = FELSessionExport::WriteSessionResults(Summary, GetArenaGameModeId(), &Err);
	if (AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>())
	{
		FELSessionExport::WriteLastSession(GS, GetWorld(), nullptr);
	}
	if (bWroteSession)
	{
		FELNativeBridge::NotifySessionResultsReady(FELPlatformPaths::GetSessionResultsJsonPath());
		if (UGameInstance* GIA = GetGameInstance())
		{
			if (UFELAcademySubsystem* Aca = GIA->GetSubsystem<UFELAcademySubsystem>())
			{
				Aca->ClearSessionAcademyProgressAfterExport();
			}
		}
	}
	ShowMatchResultsWidget(Summary);
}

FFELMatchResultSummary AFELBasketballGameMode::BuildMatchResultSummary() const
{
	FFELMatchResultSummary R;
	const AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>();
	const FString ModeId = GetArenaGameModeId();
	if (!GS)
	{
		R.GameModeId = ModeId;
		return R;
	}

	const int32 Score = GS->GetScore();
	const bool bEconomy = GS->IsScoringEnabled();
	double PRQ = LoadedReadiness.PRQScore;
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			FFELReadinessSnapshot S;
			Br->GetCachedSnapshot(S);
			PRQ = S.PRQScore;
		}
	}

	int32 BrainBoosts = 0;
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			BrainBoosts = Br->GetBrainBrawlBoostCountThisSession();
		}
	}

	const int32 BaseShards = FELArenaBridge::ComputeShardsEarned(Score, PRQ, ModeId, bEconomy);
	const int32 ShardBonus = BrainBoosts * 8;
	R.ShardsEarned = FMath::Clamp(BaseShards + ShardBonus, 8, 80);
	R.XPEarned = 30 + Score * 6 + BrainBoosts * 15;
	R.PRQBonus = FELArenaBridge::ComputePRQBonus(Score, PRQ, bEconomy);
	R.FinalPRQ = PRQ;
	R.Score = Score;
	R.OpponentScore = 0;
	R.BrainBrawlBoostCount = BrainBoosts;
	R.NeuroPerformanceScore = ComputeNeuroPerformanceScore(PRQ, Score, BrainBoosts);
	R.MentalSharpnessScore = ComputeMentalSharpnessScore(PRQ, BrainBoosts);
	R.GameModeId = ModeId;
	R.bEconomyEnabled = bEconomy;
	R.MatchEndBanner = GS->GetMatchEndBanner();
	R.MatchEndDetail = GS->GetMatchEndDetail();

	if (UWorld* W = GetWorld())
	{
		const double Now = static_cast<double>(W->GetTimeSeconds());
		R.DurationSeconds = FMath::Max(0, FMath::RoundToInt(Now - GS->GetMatchStartWorldTimeSeconds()));
	}

	FFELReadinessSnapshot SnapForMastery = LoadedReadiness;
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			if (Br->HasCachedSnapshot())
			{
				Br->GetCachedSnapshot(SnapForMastery);
			}
		}
	}
	FELSportMastery::ComputeMasteryScoreAndMetric(ModeId, SnapForMastery, Score, R.MasteryScore, R.MasteryMetricId);

	if (UGameInstance* GIA = GetGameInstance())
	{
		if (UFELAcademySubsystem* Aca = GIA->GetSubsystem<UFELAcademySubsystem>())
		{
			Aca->GetSessionAcademyProgress(R.AcademyCompletedModuleKeys, R.AcademyEvolutionShardsEarned);
		}
	}

	R.ArenaResult.FinalScore = Score;
	R.ArenaResult.NewPRQEstimate = PRQ;
	R.ArenaResult.EvolutionShardsEarned = R.ShardsEarned;
	R.ArenaResult.PerfectTimingCount = GS->GetPerfectTimingHits();
	R.ArenaResult.bBestMomentReplayAvailable = R.ArenaResult.PerfectTimingCount > 0;

	return R;
}

void AFELBasketballGameMode::ShowMatchResultsWidget(const FFELMatchResultSummary& Summary)
{
	if (!GetWorld())
	{
		return;
	}
	APlayerController* PC = GetWorld()->GetFirstPlayerController();
	if (!PC)
	{
		return;
	}
	const TSubclassOf<UFELMatchResultsWidget> Cls = MatchResultsWidgetClass ? MatchResultsWidgetClass : UFELMatchResultsWidget::StaticClass();
	UFELMatchResultsWidget* W = CreateWidget<UFELMatchResultsWidget>(PC, Cls);
	if (!W)
	{
		return;
	}
	W->InitializeWithSummary(Summary);
	W->AddToViewport(250);
	PC->SetShowMouseCursor(true);
	FInputModeGameAndUI Mode;
	Mode.SetWidgetToFocus(W->TakeWidget());
	Mode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
	PC->SetInputMode(Mode);
}

void AFELBasketballGameMode::ApplyModeToGameState()
{
	AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>();
	if (!GS)
	{
		return;
	}

	const FFELArenaRules& R = CurrentArenaRules;
	switch (PlayMode)
	{
	case EFELBasketballPlayMode::StreetBall:
		GS->ApplyRules(R.ModeDisplayName, R.bScoringEnabled, R.TargetScore, 0.f);
		break;
	case EFELBasketballPlayMode::HalfCourtShootout:
		GS->ApplyRules(R.ModeDisplayName, R.bScoringEnabled, ShootoutTargetBuckets, 0.f);
		break;
	case EFELBasketballPlayMode::TimedBlitz:
		GS->ApplyRules(R.ModeDisplayName, R.bScoringEnabled, R.TargetScore, TimedBlitzSeconds);
		break;
	case EFELBasketballPlayMode::Practice:
		GS->ApplyRules(R.ModeDisplayName, R.bScoringEnabled, 0, 0.f);
		break;
	case EFELBasketballPlayMode::FirstToTwentyOne:
		GS->ApplyRules(R.ModeDisplayName, R.bScoringEnabled, FirstToNTargetBuckets, 0.f);
		break;
	default:
		GS->ApplyRules(R.ModeDisplayName, R.bScoringEnabled, R.TargetScore, 0.f);
		break;
	}
}

void AFELBasketballGameMode::LockPlayerInputIfMatchEnded()
{
	if (bLockedInputOnMatchEnd || !GetWorld())
	{
		return;
	}

	const AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>();
	if (!GS || !GS->HasMatchEnded())
	{
		return;
	}

	bLockedInputOnMatchEnd = true;
	if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
	{
		PC->SetIgnoreMoveInput(true);
		PC->SetIgnoreLookInput(true);
	}
}

void AFELBasketballGameMode::SyncNeuroFieldsFromSnapshot(const FFELReadinessSnapshot& Snap)
{
	NeuroVerticalEstimateInches = Snap.VerticalEstimateInches;
	NeuroHangTimeScale = Snap.HangTimeScale;
	NeuroKineticLeakageMultiplier = Snap.KineticLeakageMultiplier;
	NeuroPRQScore = Snap.PRQScore;
	NeuroSFMA_SpiralRotationPass = Snap.bSFMASpiralRotationScreenPass;
	if (GetWorld() && GetWorld()->HasBegunPlay())
	{
		BroadcastBiometricToWorld();
	}
}

FString AFELBasketballGameMode::GetArenaGameModeId() const
{
	return FELArenaModeToSwiftId(CurrentMode);
}

void AFELBasketballGameMode::TriggerExerciseDemo()
{
	if (DemoManager)
	{
		DemoManager->TriggerExerciseDemo();
	}
}

void AFELBasketballGameMode::EndExerciseDemoIfActive()
{
	if (DemoManager)
	{
		DemoManager->EndExerciseDemoIfActive();
	}
}

void AFELBasketballGameMode::SpawnMatchBallAtOffset(const FVector& OffsetFromPlayerStart)
{
	if (!BallClass || !GetWorld())
	{
		return;
	}

	AActor* ChosenStart = nullptr;
	TArray<AActor*> Starts;
	UGameplayStatics::GetAllActorsOfClass(GetWorld(), APlayerStart::StaticClass(), Starts);
	if (Starts.Num() > 0)
	{
		ChosenStart = Starts[0];
	}

	FVector Loc = ChosenStart ? ChosenStart->GetActorLocation() : FVector::ZeroVector;
	Loc += OffsetFromPlayerStart;
	const FRotator Rot = ChosenStart ? ChosenStart->GetActorRotation() : FRotator::ZeroRotator;

	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;
	GetWorld()->SpawnActor<AFELBasketballActor>(BallClass, Loc, Rot, Params);
}
