// Copyright Final Evolution Lab. All Rights Reserved.
// FELCreatorManager.cpp - Creator Card System Manager Implementation

#include "FELCreatorManager.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Dom/JsonObject.h"
#include "Dom/JsonValue.h"
#include "Engine/SkeletalMesh.h"
#include "UObject/ConstructorHelpers.h"

// ════════════════════════════════════════════════════════════════════════
// Lifecycle
// ════════════════════════════════════════════════════════════════════════

void UFELCreatorManager::Initialize(FSubsystemCollectionBase& Collection)
{
    Super::Initialize(Collection);

    // Try multiple paths for the creator profiles JSON
    TArray<FString> SearchPaths = {
        FPaths::ProjectContentDir() / TEXT("FEL/Data/CreatorProfiles.json"),
        FPaths::ProjectDir() / TEXT("Content/FEL/Data/CreatorProfiles.json"),
        FPaths::EngineContentDir() / TEXT("FEL/Data/CreatorProfiles.json")
    };

    bool bLoaded = false;
    for (const FString& Path : SearchPaths)
    {
        if (FPaths::FileExists(Path))
        {
            bLoaded = LoadProfilesFromJSON(Path);
            if (bLoaded)
            {
                UE_LOG(LogTemp, Log, TEXT("[FEL CreatorManager] Loaded %d creator profiles from: %s"),
                    CreatorProfiles.Num(), *Path);
                break;
            }
        }
    }

    if (!bLoaded)
    {
        UE_LOG(LogTemp, Warning, TEXT("[FEL CreatorManager] No CreatorProfiles.json found. Creator system inactive."));
    }

    // Auto-select first featured creator if available
    if (FeaturedOrder.Num() > 0)
    {
        SelectedCreatorID = FeaturedOrder[0];
    }
}

void UFELCreatorManager::Deinitialize()
{
    CreatorProfiles.Empty();
    CachedModels.Empty();
    CompletedChallenges.Empty();
    Super::Deinitialize();
}

// ════════════════════════════════════════════════════════════════════════
// Profile Access
// ════════════════════════════════════════════════════════════════════════

bool UFELCreatorManager::GetCreatorProfile(const FString& CreatorID, FCreatorProfile& OutProfile) const
{
    if (const FCreatorProfile* Found = CreatorProfiles.Find(CreatorID))
    {
        OutProfile = *Found;
        return true;
    }
    return false;
}

TArray<FCreatorProfile> UFELCreatorManager::GetAllCreators() const
{
    TArray<FCreatorProfile> Result;
    CreatorProfiles.GenerateValueArray(Result);
    Result.Sort([](const FCreatorProfile& A, const FCreatorProfile& B)
    {
        return A.SortOrder < B.SortOrder;
    });
    return Result;
}

TArray<FCreatorProfile> UFELCreatorManager::GetFeaturedCreators() const
{
    TArray<FCreatorProfile> Result;
    for (const FString& ID : FeaturedOrder)
    {
        if (const FCreatorProfile* Found = CreatorProfiles.Find(ID))
        {
            if (Found->bIsFeatured)
            {
                Result.Add(*Found);
            }
        }
    }
    return Result;
}

TArray<FCreatorProfile> UFELCreatorManager::GetCreatorsBySport(const FString& Sport) const
{
    TArray<FCreatorProfile> Result;
    for (const auto& Pair : CreatorProfiles)
    {
        if (Pair.Value.PrimarySport.Equals(Sport, ESearchCase::IgnoreCase))
        {
            Result.Add(Pair.Value);
        }
    }
    return Result;
}

TArray<FCreatorProfile> UFELCreatorManager::GetCreatorsByTier(ECreatorTier Tier) const
{
    TArray<FCreatorProfile> Result;
    for (const auto& Pair : CreatorProfiles)
    {
        if (Pair.Value.Tier == Tier)
        {
            Result.Add(Pair.Value);
        }
    }
    return Result;
}

int32 UFELCreatorManager::GetCreatorCount() const
{
    return CreatorProfiles.Num();
}

bool UFELCreatorManager::HasCreator(const FString& CreatorID) const
{
    return CreatorProfiles.Contains(CreatorID);
}

// ════════════════════════════════════════════════════════════════════════
// Creator Selection
// ════════════════════════════════════════════════════════════════════════

void UFELCreatorManager::SelectCreator(const FString& CreatorID)
{
    if (CreatorProfiles.Contains(CreatorID))
    {
        SelectedCreatorID = CreatorID;
        OnCreatorSelected.Broadcast(CreatorID);

        FCreatorProfile Profile;
        if (GetCreatorProfile(CreatorID, Profile))
        {
            OnCreatorProfileLoaded.Broadcast(Profile);
        }
    }
}

FString UFELCreatorManager::GetSelectedCreatorID() const
{
    return SelectedCreatorID;
}

bool UFELCreatorManager::GetSelectedCreatorProfile(FCreatorProfile& OutProfile) const
{
    return GetCreatorProfile(SelectedCreatorID, OutProfile);
}

// ════════════════════════════════════════════════════════════════════════
// Highlights & Content
// ════════════════════════════════════════════════════════════════════════

TArray<FCreatorHighlight> UFELCreatorManager::GetCreatorHighlights(const FString& CreatorID) const
{
    if (const FCreatorProfile* Found = CreatorProfiles.Find(CreatorID))
    {
        return Found->Highlights;
    }
    return {};
}

TArray<FCreatorHighlight> UFELCreatorManager::GetCreatorHighlightsByType(const FString& CreatorID, const FString& HighlightType) const
{
    TArray<FCreatorHighlight> Result;
    if (const FCreatorProfile* Found = CreatorProfiles.Find(CreatorID))
    {
        for (const FCreatorHighlight& H : Found->Highlights)
        {
            if (H.HighlightType.Equals(HighlightType, ESearchCase::IgnoreCase))
            {
                Result.Add(H);
            }
        }
    }
    return Result;
}

TArray<FCreatorSignatureMove> UFELCreatorManager::GetCreatorSignatureMoves(const FString& CreatorID) const
{
    if (const FCreatorProfile* Found = CreatorProfiles.Find(CreatorID))
    {
        return Found->SignatureMoves;
    }
    return {};
}

// ════════════════════════════════════════════════════════════════════════
// Challenges
// ════════════════════════════════════════════════════════════════════════

TArray<FCreatorChallenge> UFELCreatorManager::GetCreatorChallenges(const FString& CreatorID) const
{
    if (const FCreatorProfile* Found = CreatorProfiles.Find(CreatorID))
    {
        return Found->Challenges;
    }
    return {};
}

void UFELCreatorManager::CompleteChallenge(const FString& CreatorID, const FString& ChallengeID)
{
    FString Key = CreatorID + TEXT("::") + ChallengeID;
    if (!CompletedChallenges.Contains(Key))
    {
        CompletedChallenges.Add(Key);
        OnCreatorChallengeCompleted.Broadcast(CreatorID, ChallengeID);
        UE_LOG(LogTemp, Log, TEXT("[FEL CreatorManager] Challenge completed: %s"), *Key);
    }
}

bool UFELCreatorManager::IsChallengeCompleted(const FString& CreatorID, const FString& ChallengeID) const
{
    return CompletedChallenges.Contains(CreatorID + TEXT("::") + ChallengeID);
}

int32 UFELCreatorManager::GetCompletedChallengeCount(const FString& CreatorID) const
{
    int32 Count = 0;
    for (const FString& Key : CompletedChallenges)
    {
        if (Key.StartsWith(CreatorID + TEXT("::")))
        {
            Count++;
        }
    }
    return Count;
}

// ════════════════════════════════════════════════════════════════════════
// 3D Model
// ════════════════════════════════════════════════════════════════════════

bool UFELCreatorManager::CreatorHas3DModel(const FString& CreatorID) const
{
    if (const FCreatorProfile* Found = CreatorProfiles.Find(CreatorID))
    {
        return Found->bHas3DModel;
    }
    return false;
}

FString UFELCreatorManager::GetCreatorModelPath(const FString& CreatorID) const
{
    if (const FCreatorProfile* Found = CreatorProfiles.Find(CreatorID))
    {
        return Found->PlayerModelPath;
    }
    return FString();
}

USkeletalMesh* UFELCreatorManager::LoadCreatorModel(const FString& CreatorID)
{
    // Check cache first
    if (USkeletalMesh** Cached = CachedModels.Find(CreatorID))
    {
        if (*Cached != nullptr)
        {
            return *Cached;
        }
    }

    const FCreatorProfile* Found = CreatorProfiles.Find(CreatorID);
    if (!Found || !Found->bHas3DModel || Found->PlayerModelPath.IsEmpty())
    {
        return nullptr;
    }

    USkeletalMesh* Mesh = Cast<USkeletalMesh>(
        StaticLoadObject(USkeletalMesh::StaticClass(), nullptr, *Found->PlayerModelPath));

    if (Mesh)
    {
        CachedModels.Add(CreatorID, Mesh);
        UE_LOG(LogTemp, Log, TEXT("[FEL CreatorManager] Loaded 3D model for: %s"), *CreatorID);
    }
    else
    {
        UE_LOG(LogTemp, Warning, TEXT("[FEL CreatorManager] Failed to load 3D model for: %s at path: %s"),
            *CreatorID, *Found->PlayerModelPath);
    }

    return Mesh;
}

// ════════════════════════════════════════════════════════════════════════
// Dynamic Creator Addition
// ════════════════════════════════════════════════════════════════════════

bool UFELCreatorManager::AddCreatorFromJSON(const FString& JSONString)
{
    TSharedPtr<FJsonObject> JsonObj;
    TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JSONString);
    if (!FJsonSerializer::Deserialize(Reader, JsonObj) || !JsonObj.IsValid())
    {
        UE_LOG(LogTemp, Error, TEXT("[FEL CreatorManager] Failed to parse creator JSON"));
        return false;
    }

    FCreatorProfile Profile;
    if (ParseCreatorProfile(JsonObj, Profile))
    {
        CreatorProfiles.Add(Profile.CreatorID, Profile);
        OnCreatorGalleryUpdated.Broadcast();
        UE_LOG(LogTemp, Log, TEXT("[FEL CreatorManager] Added creator: %s"), *Profile.DisplayName);
        return true;
    }
    return false;
}

bool UFELCreatorManager::RemoveCreator(const FString& CreatorID)
{
    if (CreatorProfiles.Remove(CreatorID) > 0)
    {
        if (SelectedCreatorID == CreatorID)
        {
            SelectedCreatorID.Empty();
        }
        CachedModels.Remove(CreatorID);
        OnCreatorGalleryUpdated.Broadcast();
        return true;
    }
    return false;
}

void UFELCreatorManager::ReloadCreatorProfiles()
{
    CreatorProfiles.Empty();
    CachedModels.Empty();
    FeaturedOrder.Empty();
    Initialize(*static_cast<FSubsystemCollectionBase*>(nullptr)); // Re-trigger load
    OnCreatorGalleryUpdated.Broadcast();
}

// ════════════════════════════════════════════════════════════════════════
// Serialization
// ════════════════════════════════════════════════════════════════════════

FString UFELCreatorManager::ExportCreatorsAsJSON() const
{
    TSharedPtr<FJsonObject> Root = MakeShared<FJsonObject>();
    TArray<TSharedPtr<FJsonValue>> CreatorArray;

    for (const auto& Pair : CreatorProfiles)
    {
        const FCreatorProfile& P = Pair.Value;
        TSharedPtr<FJsonObject> Obj = MakeShared<FJsonObject>();
        Obj->SetStringField(TEXT("id"), P.CreatorID);
        Obj->SetStringField(TEXT("display_name"), P.DisplayName);
        Obj->SetStringField(TEXT("tagline"), P.Tagline);
        Obj->SetStringField(TEXT("bio"), P.Bio);
        Obj->SetStringField(TEXT("location"), P.Location);
        Obj->SetStringField(TEXT("primary_sport"), P.PrimarySport);
        Obj->SetBoolField(TEXT("has_3d_model"), P.bHas3DModel);
        Obj->SetBoolField(TEXT("is_featured"), P.bIsFeatured);
        Obj->SetBoolField(TEXT("is_playable"), P.bIsPlayable);
        Obj->SetNumberField(TEXT("sort_order"), P.SortOrder);
        CreatorArray.Add(MakeShared<FJsonValueObject>(Obj));
    }

    Root->SetArrayField(TEXT("creators"), CreatorArray);

    FString Output;
    TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&Output);
    FJsonSerializer::Serialize(Root.ToSharedRef(), Writer);
    return Output;
}

// ════════════════════════════════════════════════════════════════════════
// JSON Parsing
// ════════════════════════════════════════════════════════════════════════

bool UFELCreatorManager::LoadProfilesFromJSON(const FString& FilePath)
{
    FString JSONString;
    if (!FFileHelper::LoadFileToString(JSONString, *FilePath))
    {
        UE_LOG(LogTemp, Error, TEXT("[FEL CreatorManager] Failed to read file: %s"), *FilePath);
        return false;
    }

    TSharedPtr<FJsonObject> Root;
    TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JSONString);
    if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
    {
        UE_LOG(LogTemp, Error, TEXT("[FEL CreatorManager] Failed to parse JSON: %s"), *FilePath);
        return false;
    }

    // Parse creators array
    const TArray<TSharedPtr<FJsonValue>>* CreatorsArray;
    if (Root->TryGetArrayField(TEXT("creators"), CreatorsArray))
    {
        for (const TSharedPtr<FJsonValue>& Val : *CreatorsArray)
        {
            if (Val->Type == EJson::Object)
            {
                FCreatorProfile Profile;
                if (ParseCreatorProfile(Val->AsObject(), Profile))
                {
                    CreatorProfiles.Add(Profile.CreatorID, Profile);
                }
            }
        }
    }

    // Parse featured order
    const TArray<TSharedPtr<FJsonValue>>* FeaturedArray;
    if (Root->TryGetArrayField(TEXT("featured_order"), FeaturedArray))
    {
        for (const TSharedPtr<FJsonValue>& Val : *FeaturedArray)
        {
            FeaturedOrder.Add(Val->AsString());
        }
    }

    return CreatorProfiles.Num() > 0;
}

bool UFELCreatorManager::ParseCreatorProfile(const TSharedPtr<FJsonObject>& J, FCreatorProfile& P)
{
    if (!J.IsValid()) return false;

    P.CreatorID       = J->GetStringField(TEXT("id"));
    P.DisplayName     = J->GetStringField(TEXT("display_name"));
    P.Tagline         = J->GetStringField(TEXT("tagline"));
    P.Bio             = J->GetStringField(TEXT("bio"));
    P.Location        = J->GetStringField(TEXT("location"));
    P.PrimarySport    = J->GetStringField(TEXT("primary_sport"));
    P.Position        = J->GetStringField(TEXT("position"));
    P.Height          = J->GetStringField(TEXT("height"));
    P.Weight          = J->GetStringField(TEXT("weight"));
    P.ProfileImagePath = J->GetStringField(TEXT("profile_image"));
    P.BannerImagePath  = J->GetStringField(TEXT("banner_image"));
    P.CardBackgroundPath = J->GetStringField(TEXT("card_background"));
    P.PlayerModelPath  = J->GetStringField(TEXT("player_model"));
    P.bHas3DModel      = J->GetBoolField(TEXT("has_3d_model"));
    P.bIsFeatured      = J->GetBoolField(TEXT("is_featured"));
    P.bIsPlayable      = J->GetBoolField(TEXT("is_playable"));
    P.SortOrder        = J->GetIntegerField(TEXT("sort_order"));
    P.DateAdded        = J->GetStringField(TEXT("date_added"));

    // Parse tier
    FString TierStr = J->GetStringField(TEXT("tier"));
    if (TierStr == TEXT("Featured"))     P.Tier = ECreatorTier::Featured;
    else if (TierStr == TEXT("Verified")) P.Tier = ECreatorTier::Verified;
    else if (TierStr == TEXT("ComingSoon")) P.Tier = ECreatorTier::ComingSoon;
    else P.Tier = ECreatorTier::Community;

    // Parse card style
    FString StyleStr = J->GetStringField(TEXT("card_style"));
    if (StyleStr == TEXT("Premium"))        P.CardStyle = ECreatorCardStyle::Premium;
    else if (StyleStr == TEXT("Legendary")) P.CardStyle = ECreatorCardStyle::Legendary;
    else if (StyleStr == TEXT("Holographic")) P.CardStyle = ECreatorCardStyle::Holographic;
    else P.CardStyle = ECreatorCardStyle::Standard;

    // Parse highlights
    const TArray<TSharedPtr<FJsonValue>>* HighlightsArray;
    if (J->TryGetArrayField(TEXT("highlights"), HighlightsArray))
    {
        for (const auto& HVal : *HighlightsArray)
        {
            auto HObj = HVal->AsObject();
            FCreatorHighlight H;
            H.HighlightID     = HObj->GetStringField(TEXT("id"));
            H.Title            = HObj->GetStringField(TEXT("title"));
            H.VideoPath        = HObj->GetStringField(TEXT("video_path"));
            H.ThumbnailPath    = HObj->GetStringField(TEXT("thumbnail"));
            H.DurationSeconds  = HObj->GetNumberField(TEXT("duration_seconds"));
            H.Location         = HObj->GetStringField(TEXT("location"));
            H.HighlightType    = HObj->GetStringField(TEXT("type"));
            P.Highlights.Add(H);
        }
    }

    // Parse signature moves
    const TArray<TSharedPtr<FJsonValue>>* MovesArray;
    if (J->TryGetArrayField(TEXT("signature_moves"), MovesArray))
    {
        for (const auto& MVal : *MovesArray)
        {
            auto MObj = MVal->AsObject();
            FCreatorSignatureMove M;
            M.MoveID           = MObj->GetStringField(TEXT("id"));
            M.DisplayName      = MObj->GetStringField(TEXT("name"));
            M.Description      = MObj->GetStringField(TEXT("description"));
            M.AnimMontage      = MObj->GetStringField(TEXT("anim_montage"));
            M.DifficultyRating = MObj->GetIntegerField(TEXT("difficulty"));
            M.Category         = MObj->GetStringField(TEXT("category"));
            P.SignatureMoves.Add(M);
        }
    }

    // Parse stats
    const TArray<TSharedPtr<FJsonValue>>* StatsArray;
    if (J->TryGetArrayField(TEXT("stats"), StatsArray))
    {
        for (const auto& SVal : *StatsArray)
        {
            auto SObj = SVal->AsObject();
            FCreatorStat S;
            S.StatName  = SObj->GetStringField(TEXT("name"));
            S.StatValue = SObj->GetStringField(TEXT("value"));
            S.IconPath  = SObj->GetStringField(TEXT("icon"));
            P.Stats.Add(S);
        }
    }

    // Parse social links
    const TArray<TSharedPtr<FJsonValue>>* SocialArray;
    if (J->TryGetArrayField(TEXT("social_links"), SocialArray))
    {
        for (const auto& LVal : *SocialArray)
        {
            auto LObj = LVal->AsObject();
            FCreatorSocialLink L;
            L.Platform      = LObj->GetStringField(TEXT("platform"));
            L.Handle        = LObj->GetStringField(TEXT("handle"));
            L.URL           = LObj->GetStringField(TEXT("url"));
            L.FollowerCount = LObj->GetIntegerField(TEXT("followers"));
            P.SocialLinks.Add(L);
        }
    }

    // Parse challenges
    const TArray<TSharedPtr<FJsonValue>>* ChallengesArray;
    if (J->TryGetArrayField(TEXT("challenges"), ChallengesArray))
    {
        for (const auto& CVal : *ChallengesArray)
        {
            auto CObj = CVal->AsObject();
            FCreatorChallenge C;
            C.ChallengeID   = CObj->GetStringField(TEXT("id"));
            C.DisplayName   = CObj->GetStringField(TEXT("name"));
            C.Description   = CObj->GetStringField(TEXT("description"));
            C.GameMode      = CObj->GetStringField(TEXT("game_mode"));
            C.Difficulty    = CObj->GetStringField(TEXT("difficulty"));
            C.Reward        = CObj->GetStringField(TEXT("reward"));
            C.RequiredScore = CObj->GetIntegerField(TEXT("required_score"));
            P.Challenges.Add(C);
        }
    }

    return !P.CreatorID.IsEmpty();
}
