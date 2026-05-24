// Copy into your game's Source/FinalEvolutionLab/ module.

#include "FELEmergentDeepLinkSubsystem.h"

#include "FELCardActivationSubsystem.h"
#include "FELPartySubsystem.h"
#include "FELEmergentBridgeSubsystem.h"
#include "FELReadinessArenaIni.h"

#include "Engine/Engine.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"
#include "Misc/CommandLine.h"
#include "Misc/CoreDelegates.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
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
		T.Add(TEXT("market_browse"), TEXT("Sovereign_Shop"));
		T.Add(TEXT("scene_it"), TEXT("Venice_Beach_Court"));
		T.Add(TEXT("who_scene_it"), TEXT("Neuro_Arena"));
		T.Add(TEXT("court_carnival"), TEXT("Venice_Beach_Court"));
		return T;
	}();
	return M;
}

/**
 * Source of truth for **server travel** package paths (matches `backend/FEL_ModeManager.production.json` `map` field).
 * Preferred over legacy `/Game/FEL/Venues/...` when resolving a **mode id** (e.g. iOS `arenaGameModeId`).
 */
const TMap<FString, FString>& GetProductionMapPathByModeId()
{
	static TMap<FString, FString> P = [] {
		TMap<FString, FString> M;
		M.Add(TEXT("basketball_h2h"), TEXT("/Game/FEL/Maps/Venice_Beach_Court"));
		M.Add(TEXT("basketball_dunk"), TEXT("/Game/FEL/Maps/Venice_Beach_Court"));
		M.Add(TEXT("basketball_3v3"), TEXT("/Game/FEL/Maps/Venice_Beach_Court"));
		M.Add(TEXT("karate_h2h"), TEXT("/Game/FEL/Maps/Zen_Dojo"));
		M.Add(TEXT("karate_endless"), TEXT("/Game/FEL/Maps/Zen_Dojo"));
		M.Add(TEXT("baseball"), TEXT("/Game/FEL/Maps/Baseball_Park"));
		M.Add(TEXT("football"), TEXT("/Game/FEL/Maps/Gridiron_Stadium"));
		M.Add(TEXT("soccer"), TEXT("/Game/FEL/Maps/Soccer_Stadium"));
		M.Add(TEXT("golf"), TEXT("/Game/FEL/Maps/Links_Course"));
		M.Add(TEXT("tennis"), TEXT("/Game/FEL/Maps/Tennis_Court"));
		M.Add(TEXT("volleyball"), TEXT("/Game/FEL/Maps/Sand_Court"));
		M.Add(TEXT("gymnastics"), TEXT("/Game/FEL/Maps/Training_Floor"));
		M.Add(TEXT("surfing"), TEXT("/Game/FEL/Maps/Venice_Beach_Surf"));
		M.Add(TEXT("skateboarding"), TEXT("/Game/FEL/Maps/Skate_Park"));
		M.Add(TEXT("snowboarding"), TEXT("/Game/FEL/Maps/Mountain_Slope"));
		M.Add(TEXT("brain_brawl"), TEXT("/Game/FEL/Maps/Neuro_Arena"));
		M.Add(TEXT("market_browse"), TEXT("/Game/FEL/Maps/Sovereign_Shop"));
		M.Add(TEXT("who_scene_it"), TEXT("/Game/FEL/Maps/Neuro_Arena"));
		M.Add(TEXT("court_carnival"), TEXT("/Game/FEL/Maps/Venice_Beach_Court"));
		return M;
	}();
	return P;
}

/** Logical venue tokens -> production map packages (aligned with `backend/FEL_ModeManager.production.json` `map`). */
const TMap<FString, FString>& GetVenueTokenToPackagePath()
{
	static TMap<FString, FString> T = [] {
		TMap<FString, FString> M;
		M.Add(TEXT("Venice_Beach_Court"), TEXT("/Game/FEL/Maps/Venice_Beach_Court"));
		M.Add(TEXT("Zen_Dojo"), TEXT("/Game/FEL/Maps/Zen_Dojo"));
		M.Add(TEXT("Baseball_Park"), TEXT("/Game/FEL/Maps/Baseball_Park"));
		M.Add(TEXT("Gridiron_Stadium"), TEXT("/Game/FEL/Maps/Gridiron_Stadium"));
		M.Add(TEXT("Soccer_Stadium"), TEXT("/Game/FEL/Maps/Soccer_Stadium"));
		M.Add(TEXT("Links_Course"), TEXT("/Game/FEL/Maps/Links_Course"));
		M.Add(TEXT("Tennis_Court"), TEXT("/Game/FEL/Maps/Tennis_Court"));
		M.Add(TEXT("Sand_Court"), TEXT("/Game/FEL/Maps/Sand_Court"));
		M.Add(TEXT("Training_Floor"), TEXT("/Game/FEL/Maps/Training_Floor"));
		M.Add(TEXT("Venice_Beach_Surf"), TEXT("/Game/FEL/Maps/Venice_Beach_Surf"));
		M.Add(TEXT("Skate_Park"), TEXT("/Game/FEL/Maps/Skate_Park"));
		M.Add(TEXT("Mountain_Slope"), TEXT("/Game/FEL/Maps/Mountain_Slope"));
		M.Add(TEXT("Neuro_Arena"), TEXT("/Game/FEL/Maps/Neuro_Arena"));
		M.Add(TEXT("Sovereign_Shop"), TEXT("/Game/FEL/Maps/Sovereign_Shop"));
		return M;
	}();
	return T;
}

void MergeIniSectionIntoMap(const FString& IniPath, const TCHAR* SectionName, TMap<FString, FString>& OutMap)
{
	FString Content;
	if (!FFileHelper::LoadFileToString(Content, *IniPath))
	{
		return;
	}

	const FString SectionTag = FString::Printf(TEXT("[%s]"), SectionName);
	TArray<FString> Lines;
	Content.ParseIntoArrayLines(Lines, /*bCullEmpty=*/false);

	bool bInSection = false;
	for (FString Line : Lines)
	{
		Line.TrimStartAndEndInline();
		if (Line.IsEmpty() || Line.StartsWith(TEXT(";")))
		{
			continue;
		}
		if (Line.StartsWith(TEXT("[")))
		{
			bInSection = Line.Equals(SectionTag, ESearchCase::IgnoreCase);
			continue;
		}
		if (!bInSection || !Line.Contains(TEXT("=")))
		{
			continue;
		}

		FString K;
		FString V;
		if (!Line.Split(TEXT("="), &K, &V))
		{
			continue;
		}
		K.TrimStartAndEndInline();
		V.TrimStartAndEndInline();
		if (!K.IsEmpty() && !V.IsEmpty())
		{
			OutMap.Add(K, V);
		}
	}
}
} // namespace

void UFELEmergentDeepLinkSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	ReloadEmergentPlayMapsFromIni();
	ReloadEmergentButtonArenaModesFromIni();
	FELReadinessArenaIni::ReloadCacheFromIni();
	BindDelegates();
	TryConsumeLaunchURL();

	if (UGameInstance* GI = GetGameInstance())
	{
		GI->GetTimerManager().SetTimer(
			RetryLaunchUrlTimer,
			this,
			&UFELEmergentDeepLinkSubsystem::TryConsumeLaunchURL,
			0.75f,
			false);
	}
}

void UFELEmergentDeepLinkSubsystem::ReloadEmergentPlayMapsFromIni()
{
	EmergentPlayMapIni.Reset();
	const FString Path = FPaths::ProjectConfigDir() / TEXT("DefaultGame.ini");
	MergeIniSectionIntoMap(Path, TEXT("EmergentPlayMap"), EmergentPlayMapIni);
}

void UFELEmergentDeepLinkSubsystem::ReloadEmergentButtonArenaModesFromIni()
{
	EmergentButtonArenaModeIni.Reset();
	const FString Path = FPaths::ProjectConfigDir() / TEXT("DefaultGame.ini");
	MergeIniSectionIntoMap(Path, TEXT("EmergentButtonArenaMode"), EmergentButtonArenaModeIni);
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

FString UFELEmergentDeepLinkSubsystem::ResolvePackagePathForPlayKey(const FString& MapOrButtonKey) const
{
	FString K = MapOrButtonKey.TrimStartAndEnd();
	if (K.IsEmpty())
	{
		return FString();
	}

	if (K.StartsWith(TEXT("/Game/")))
	{
		return K;
	}

	// Mode id (e.g. `basketball_dunk`) -> production map from FEL_ModeManager JSON.
	if (const FString* Prod = GetProductionMapPathByModeId().Find(K))
	{
		return *Prod;
	}

	if (const FString* VenuePath = GetVenueTokenToPackagePath().Find(K))
	{
		return *VenuePath;
	}

	if (const FString* IniPath = EmergentPlayMapIni.Find(K))
	{
		return *IniPath;
	}
	for (const auto& Pair : EmergentPlayMapIni)
	{
		if (Pair.Key.Equals(K, ESearchCase::IgnoreCase))
		{
			return Pair.Value;
		}
	}

	FString Normalized = K;
	Normalized.ReplaceInline(TEXT("-"), TEXT(""));
	for (const auto& Pair : EmergentPlayMapIni)
	{
		FString KN = Pair.Key;
		KN.ReplaceInline(TEXT("-"), TEXT(""));
		if (KN.Equals(Normalized, ESearchCase::IgnoreCase))
		{
			return Pair.Value;
		}
	}

	if (const FString* Venue = GetModeToVenueMap().Find(K))
	{
		if (const FString* Pkg = GetVenueTokenToPackagePath().Find(*Venue))
		{
			return *Pkg;
		}
	}

	const FString ViaMode = ResolveModeToMapToken(K);
	if (!ViaMode.IsEmpty())
	{
		if (const FString* Pkg = GetVenueTokenToPackagePath().Find(ViaMode))
		{
			return *Pkg;
		}
	}

	return FString();
}

FString UFELEmergentDeepLinkSubsystem::ResolveArenaModeForButton(
	const FString& ButtonKey,
	const FString& FallbackModeHint) const
{
	if (!FallbackModeHint.IsEmpty())
	{
		return FallbackModeHint;
	}
	if (const FString* M = EmergentButtonArenaModeIni.Find(ButtonKey))
	{
		return *M;
	}
	for (const auto& Pair : EmergentButtonArenaModeIni)
	{
		if (Pair.Key.Equals(ButtonKey, ESearchCase::IgnoreCase))
		{
			return Pair.Value;
		}
	}
	if (GetModeToVenueMap().Contains(ButtonKey))
	{
		return ButtonKey;
	}
	return FString();
}

void UFELEmergentDeepLinkSubsystem::RequestPlayFromEmergent(
	const FString& ButtonOrModeKey,
	const FString& OptionalExplicitPackagePath,
	const FString& OptionalArenaGameMode)
{
	const FString Primary = ButtonOrModeKey.TrimStartAndEnd();
	if (Primary.IsEmpty())
	{
		UE_LOG(LogTemp, Warning, TEXT("FEL Emergent play: empty key."));
		return;
	}

	FString PackagePath = OptionalExplicitPackagePath.TrimStartAndEnd();
	if (PackagePath.IsEmpty())
	{
		PackagePath = ResolvePackagePathForPlayKey(Primary);
	}

	if (PackagePath.IsEmpty())
	{
		UE_LOG(LogTemp, Warning, TEXT("FEL Emergent play: could not resolve map for '%s' — add [EmergentPlayMap] in DefaultGame.ini."), *Primary);
		return;
	}

	FString ModeId = ResolveArenaModeForButton(Primary, OptionalArenaGameMode.TrimStartAndEnd());

	FString MapTokenOrShort = PackagePath;
	MapTokenOrShort.ReplaceInline(TEXT("/Game/FEL/Venues/"), TEXT(""));
	MapTokenOrShort.ReplaceInline(TEXT("/Game/FEL/Maps/"), TEXT(""));
	const int32 SlashIdx = MapTokenOrShort.Find(TEXT("/"));
	if (SlashIdx != INDEX_NONE)
	{
		MapTokenOrShort.LeftInline(SlashIdx);
	}

	LastRequestedMapToken = MapTokenOrShort;
	LastRequestedModeId = ModeId;

	OpenMapFromTokens(PackagePath, ModeId);
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

	if (PathPart.Equals(TEXT("activate"), ESearchCase::IgnoreCase))
	{
		if (UGameInstance* GI = GetGameInstance())
		{
			if (UFELCardActivationSubsystem* Draft = GI->GetSubsystem<UFELCardActivationSubsystem>())
			{
				Draft->ProcessQrActivationParams(Params);
			}
		}
		return;
	}

	if (PathPart.Equals(TEXT("party"), ESearchCase::IgnoreCase))
	{
		if (UGameInstance* GI = GetGameInstance())
		{
			if (UFELPartySubsystem* Party = GI->GetSubsystem<UFELPartySubsystem>())
			{
				const FString Open = Params.FindRef(TEXT("open"));
				const bool bOpen =
					Open.Equals(TEXT("1")) || Open.Equals(TEXT("true"), ESearchCase::IgnoreCase);
				Party->ApplyDeepLinkParams(Params, bOpen);
			}
		}
		return;
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

	const FString PackagePath = ResolvePackagePathForPlayKey(MapToken);
	if (PackagePath.IsEmpty())
	{
		UE_LOG(LogTemp, Warning, TEXT("FEL DeepLink: unresolved map token %s"), *MapToken);
		return;
	}

	OpenMapFromTokens(PackagePath, ModeId);
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

	FString CleanPackage = PendingOpenPackage;
	FString Options = PendingOpenOptions;
	PendingOpenPackage.Reset();
	PendingOpenOptions.Reset();

	UE_LOG(LogTemp, Log, TEXT("FEL DeepLink: OpenLevel %s"), *CleanPackage);
	UGameplayStatics::OpenLevel(World, FName(*CleanPackage), true, Options);
	GI->GetTimerManager().ClearTimer(DeferredOpenTimer);
	DeferredOpenAttempts = 0;
}

void UFELEmergentDeepLinkSubsystem::OpenMapFromTokens(const FString& MapPackagePathIn, const FString& ModeId)
{
	UGameInstance* GI = GetGameInstance();
	if (!GI)
	{
		return;
	}
	GI->GetTimerManager().ClearTimer(DeferredOpenTimer);

	FString MapPath = MapPackagePathIn.TrimStartAndEnd();
	FString ExtraOptions;
	if (MapPath.Split(TEXT("?"), &MapPath, &ExtraOptions))
	{
		MapPath.TrimStartAndEndInline();
		ExtraOptions.TrimStartAndEndInline();
	}

	FString Options;
	if (!ModeId.IsEmpty())
	{
		Options.Append(FString::Printf(TEXT("ArenaGameMode=%s"), *ModeId));
	}
	FString CreatorId;
	if (!ModeId.IsEmpty() && FELReadinessArenaIni::TryGetCreatorForArena(ModeId, CreatorId))
	{
		if (!Options.IsEmpty())
		{
			Options.AppendChar(TEXT('&'));
		}
		Options.Append(FString::Printf(TEXT("CreatorId=%s"), *CreatorId));
	}
	if (!ExtraOptions.IsEmpty())
	{
		if (!Options.IsEmpty())
		{
			Options.AppendChar(TEXT('&'));
		}
		Options.Append(ExtraOptions);
	}

	if (ModeId.Equals(TEXT("scene_it"), ESearchCase::IgnoreCase))
	{
		if (!Options.IsEmpty())
		{
			Options.AppendChar(TEXT('&'));
		}
		Options.Append(TEXT("game=/Script/FinalEvolutionLab.FELSceneItGameMode"));
	}

	PendingOpenPackage = MapPath;
	PendingOpenOptions = Options;
	DeferredOpenAttempts = 0;

	if (UWorld* World = GI->GetWorld())
	{
		UE_LOG(LogTemp, Log, TEXT("FEL DeepLink: OpenLevel %s (mode=%s)"), *MapPath, *ModeId);
		UGameplayStatics::OpenLevel(World, FName(*MapPath), true, Options);
		PendingOpenPackage.Reset();
		PendingOpenOptions.Reset();
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

	OnFELMapLoaded.Broadcast(PayloadMap, PayloadMode);

	Bridge->ScheduleSovereignSessionSnapshotDeferred(0.15f);

	UE_LOG(LogTemp, Log, TEXT("FEL DeepLink: map_loaded WS event map=%s mode=%s"), *PayloadMap, *PayloadMode);
}
