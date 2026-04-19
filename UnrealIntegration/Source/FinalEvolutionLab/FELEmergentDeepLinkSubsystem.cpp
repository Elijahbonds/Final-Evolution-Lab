// Copy into your game's Source/FinalEvolutionLab/ module.

#include "FELEmergentDeepLinkSubsystem.h"

#include "FELEmergentBridgeSubsystem.h"

#include "Engine/Engine.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"
#include "Misc/CommandLine.h"
#include "Misc/CoreDelegates.h"
#include "TimerManager.h"
#include "UObject/UObjectGlobals.h"

namespace
{
const TMap<FString, FString>& GetModeToVenueMap()
{
	static TMap<FString, FString> M = [] {
		TMap<FString, FString> T;
		T.Add(TEXT("basketball_h2h"), TEXT("Venice_Beach_Court"));
		T.Add(TEXT("basketball_dunk"), TEXT("Venice_Beach_Court"));
		T.Add(TEXT("basketball_3v3"), TEXT("Venice_Beach_Court"));
		T.Add(TEXT("karate_h2h"), TEXT("Zen_Dojo"));
		T.Add(TEXT("karate_endless"), TEXT("Zen_Dojo"));
		T.Add(TEXT("karate"), TEXT("Zen_Dojo"));
		T.Add(TEXT("baseball"), TEXT("Baseball_Park"));
		T.Add(TEXT("football"), TEXT("Gridiron_Stadium"));
		T.Add(TEXT("soccer"), TEXT("Soccer_Stadium"));
		T.Add(TEXT("golf"), TEXT("Links_Course"));
		T.Add(TEXT("tennis"), TEXT("Tennis_Court"));
		T.Add(TEXT("volleyball"), TEXT("Sand_Court"));
		T.Add(TEXT("gymnastics"), TEXT("Training_Floor"));
		T.Add(TEXT("surfing"), TEXT("Venice_Beach_Surf"));
		T.Add(TEXT("skateboarding"), TEXT("Skate_Park"));
		T.Add(TEXT("snowboarding"), TEXT("Mountain_Slope"));
		T.Add(TEXT("brain_brawl"), TEXT("Neuro_Arena"));
		return T;
	}();
	return M;
}
} // namespace

void UFELEmergentDeepLinkSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	BindDelegates();
	TryConsumeLaunchURL();

	if (UGameInstance* GI = GetGameInstance())
	{
		// Launch URL sometimes arrives after subsystems init (iOS).
		GI->GetTimerManager().SetTimer(
			RetryLaunchUrlTimer,
			this,
			&UFELEmergentDeepLinkSubsystem::TryConsumeLaunchURL,
			0.75f,
			false);
	}
}

void UFELEmergentDeepLinkSubsystem::Deinitialize()
{
	UnbindDelegates();
	if (UGameInstance* GI = GetGameInstance())
	{
		GI->GetTimerManager().ClearTimer(DeferredOpenTimer);
		GI->GetTimerManager().ClearTimer(RetryLaunchUrlTimer);
	}
	Super::Deinitialize();
}

void UFELEmergentDeepLinkSubsystem::BindDelegates()
{
	StartupArgumentsHandle = FCoreDelegates::ApplicationReceivedStartupArgumentsDelegate.AddUObject(
		this, &UFELEmergentDeepLinkSubsystem::OnStartupArguments);

	PostLoadMapHandle = FCoreUObjectDelegates::PostLoadMapWithWorld.AddUObject(
		this, &UFELEmergentDeepLinkSubsystem::OnPostLoadMapWithWorld);
}

void UFELEmergentDeepLinkSubsystem::UnbindDelegates()
{
	if (StartupArgumentsHandle.IsValid())
	{
		FCoreDelegates::ApplicationReceivedStartupArgumentsDelegate.Remove(StartupArgumentsHandle);
		StartupArgumentsHandle.Reset();
	}
	if (PostLoadMapHandle.IsValid())
	{
		FCoreUObjectDelegates::PostLoadMapWithWorld.Remove(PostLoadMapHandle);
		PostLoadMapHandle.Reset();
	}
}

void UFELEmergentDeepLinkSubsystem::OnStartupArguments(const TArray<FString>& Args)
{
	for (const FString& A : Args)
	{
		if (A.Contains(TEXT("://")))
		{
			ProcessDeepLinkUrl(A);
		}
	}
}

void UFELEmergentDeepLinkSubsystem::TryConsumeLaunchURL()
{
	// UE 5.7: FPlatformMisc::GetLaunchURL is not exposed on Mac/iOS here; cold-start URLs still arrive via
	// ApplicationReceivedStartupArgumentsDelegate. Scan command line for embedded finalevolution:// links.
	const FString Cmd = FCommandLine::Get();
	if (!Cmd.Contains(TEXT("finalevolution://"), ESearchCase::IgnoreCase))
	{
		return;
	}
	const int32 Idx = Cmd.Find(TEXT("finalevolution://"), ESearchCase::IgnoreCase);
	if (Idx == INDEX_NONE)
	{
		return;
	}
	FString Url = Cmd.Mid(Idx);
	for (int32 i = 0; i < Url.Len(); ++i)
	{
		const TCHAR C = Url[i];
		if (C == TCHAR(' ') || C == TCHAR('\t') || C == TCHAR('\r') || C == TCHAR('\n') || C == TCHAR('\"'))
		{
			Url.LeftInline(i);
			break;
		}
	}
	if (!Url.IsEmpty())
	{
		ProcessDeepLinkUrl(Url);
	}
}

FString UFELEmergentDeepLinkSubsystem::StripSchemeAndHost(const FString& Url)
{
	FString Rest = Url;
	Rest.ReplaceInline(TEXT("finalevolution://"), TEXT(""));
	Rest.ReplaceInline(TEXT("FINALEVOLUTION://"), TEXT(""));
	while (Rest.StartsWith(TEXT("/")))
	{
		Rest.RightChopInline(1);
	}
	return Rest;
}

void UFELEmergentDeepLinkSubsystem::ParseQueryString(const FString& Query, TMap<FString, FString>& OutParams)
{
	TArray<FString> Pairs;
	Query.ParseIntoArray(Pairs, TEXT("&"));
	for (FString Pair : Pairs)
	{
		FString K, V;
		if (Pair.Split(TEXT("="), &K, &V))
		{
			K.TrimStartAndEndInline();
			V.TrimStartAndEndInline();
			OutParams.Add(K, V);
		}
	}
}

FString UFELEmergentDeepLinkSubsystem::ResolveModeToMapToken(const FString& ModeId)
{
	if (ModeId.Equals(TEXT("brain_brawl"), ESearchCase::IgnoreCase))
	{
		return TEXT("Neuro_Arena");
	}
	if (const FString* Found = GetModeToVenueMap().Find(ModeId))
	{
		return *Found;
	}
	return FString();
}

FString UFELEmergentDeepLinkSubsystem::PackagePathFromMapToken(const FString& MapToken)
{
	if (MapToken.IsEmpty())
	{
		return FString();
	}
	if (MapToken.StartsWith(TEXT("/Game/")))
	{
		return MapToken;
	}
	return FString::Printf(TEXT("/Game/FEL/Maps/%s"), *MapToken);
}

void UFELEmergentDeepLinkSubsystem::ProcessDeepLinkUrl(const FString& Url)
{
	if (!Url.Contains(TEXT("finalevolution://"), ESearchCase::IgnoreCase) && !Url.Contains(TEXT("://")))
	{
		return;
	}

	FString Rest = StripSchemeAndHost(Url);
	FString PathPart;
	FString Query;
	if (!Rest.Split(TEXT("?"), &PathPart, &Query))
	{
		PathPart = Rest;
	}

	TMap<FString, FString> Params;
	if (!Query.IsEmpty())
	{
		ParseQueryString(Query, Params);
	}

	FString MapToken = Params.FindRef(TEXT("map"));
	FString ModeId = Params.FindRef(TEXT("mode"));

	if (!ModeId.IsEmpty() && ModeId.Equals(TEXT("brain_brawl"), ESearchCase::IgnoreCase))
	{
		MapToken = TEXT("Neuro_Arena");
	}
	else if (MapToken.IsEmpty() && !ModeId.IsEmpty())
	{
		MapToken = ResolveModeToMapToken(ModeId);
	}

	if (MapToken.IsEmpty())
	{
		UE_LOG(LogTemp, Warning, TEXT("FEL DeepLink: no map or resolvable mode in URL: %s"), *Url);
		return;
	}

	LastRequestedMapToken = MapToken;
	LastRequestedModeId = ModeId;

	OpenMapFromTokens(MapToken, ModeId);
}

void UFELEmergentDeepLinkSubsystem::TryDeferredOpenLevel()
{
	UGameInstance* GI = GetGameInstance();
	if (!GI)
	{
		return;
	}
	UWorld* World = GI->GetWorld();
	if (!World || PendingOpenPackage.IsEmpty())
	{
		DeferredOpenAttempts++;
		if (DeferredOpenAttempts > 80)
		{
			GI->GetTimerManager().ClearTimer(DeferredOpenTimer);
			UE_LOG(LogTemp, Warning, TEXT("FEL DeepLink: gave up waiting for world to open %s"), *PendingOpenPackage);
			PendingOpenPackage.Reset();
			DeferredOpenAttempts = 0;
		}
		return;
	}

	UE_LOG(LogTemp, Log, TEXT("FEL DeepLink: OpenLevel %s"), *PendingOpenPackage);
	UGameplayStatics::OpenLevel(World, FName(*PendingOpenPackage));
	GI->GetTimerManager().ClearTimer(DeferredOpenTimer);
	PendingOpenPackage.Reset();
	DeferredOpenAttempts = 0;
}

void UFELEmergentDeepLinkSubsystem::OpenMapFromTokens(const FString& MapToken, const FString& ModeId)
{
	UGameInstance* GI = GetGameInstance();
	if (!GI)
	{
		return;
	}
	GI->GetTimerManager().ClearTimer(DeferredOpenTimer);

	const FString PackagePath = PackagePathFromMapToken(MapToken);
	if (PackagePath.IsEmpty())
	{
		return;
	}

	PendingOpenPackage = PackagePath;
	DeferredOpenAttempts = 0;

	if (UWorld* World = GI->GetWorld())
	{
		UE_LOG(LogTemp, Log, TEXT("FEL DeepLink: OpenLevel %s (mode=%s)"), *PackagePath, *ModeId);
		UGameplayStatics::OpenLevel(World, FName(*PackagePath));
		PendingOpenPackage.Reset();
		return;
	}

	GI->GetTimerManager().SetTimer(DeferredOpenTimer, this, &UFELEmergentDeepLinkSubsystem::TryDeferredOpenLevel, 0.1f, true);
}

void UFELEmergentDeepLinkSubsystem::OnPostLoadMapWithWorld(UWorld* World)
{
	if (!World || World->IsPreviewWorld())
	{
		return;
	}

	UGameInstance* GI = GetGameInstance();
	if (!GI)
	{
		return;
	}

	UFELEmergentBridgeSubsystem* Bridge = GI->GetSubsystem<UFELEmergentBridgeSubsystem>();
	if (!Bridge)
	{
		return;
	}

	FString MapName = World->GetMapName();
	MapName.RemoveFromStart(World->StreamingLevelsPrefix);

	const FString PayloadMap = LastRequestedMapToken.IsEmpty() ? MapName : LastRequestedMapToken;
	const FString PayloadMode = LastRequestedModeId.IsEmpty() ? TEXT("") : LastRequestedModeId;

	Bridge->BroadcastMapLoaded(PayloadMap, PayloadMode);

	Bridge->ScheduleSovereignSessionSnapshotDeferred(0.15f);

	UE_LOG(LogTemp, Log, TEXT("FEL DeepLink: map_loaded WS event map=%s mode=%s"), *PayloadMap, *PayloadMode);
}
