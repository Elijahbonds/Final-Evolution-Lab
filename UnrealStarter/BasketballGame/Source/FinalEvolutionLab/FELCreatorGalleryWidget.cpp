// Copyright Final Evolution Lab. All Rights Reserved.
// FELCreatorGalleryWidget.cpp

#include "FELCreatorGalleryWidget.h"
#include "FELCreatorCardWidget.h"
#include "FELCreatorManager.h"
#include "Components/ScrollBox.h"
#include "Components/UniformGridPanel.h"
#include "Components/EditableTextBox.h"
#include "Components/ComboBoxString.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Kismet/GameplayStatics.h"

void UFELCreatorGalleryWidget::NativeConstruct()
{
    Super::NativeConstruct();

    if (SearchBox)
    {
        SearchBox->OnTextChanged.AddDynamic(this, &UFELCreatorGalleryWidget::HandleSearchChanged);
    }
    if (SportFilter)
    {
        SportFilter->OnSelectionChanged.AddDynamic(this, &UFELCreatorGalleryWidget::HandleSportFilterChanged);
        SportFilter->AddOption(TEXT("All Sports"));
        SportFilter->AddOption(TEXT("Basketball"));
        SportFilter->AddOption(TEXT("Soccer"));
        SportFilter->AddOption(TEXT("Boxing"));
        SportFilter->AddOption(TEXT("Mixed"));
        SportFilter->SetSelectedOption(TEXT("All Sports"));
    }
    if (CloseGalleryButton)
    {
        CloseGalleryButton->OnClicked.AddDynamic(this, &UFELCreatorGalleryWidget::HandleCloseClicked);
    }
}

void UFELCreatorGalleryWidget::InitializeGallery()
{
    UGameInstance* GI = UGameplayStatics::GetGameInstance(this);
    if (!GI) return;

    UFELCreatorManager* CM = GI->GetSubsystem<UFELCreatorManager>();
    if (!CM) return;

    // Get all creators sorted by sort_order
    DisplayedCreators = CM->GetAllCreators();

    // Populate featured carousel
    PopulateFeaturedCarousel();

    // Populate main grid
    PopulateGrid(DisplayedCreators);

    // Add "Coming Soon" placeholders
    AddComingSoonCards();

    // Update count
    if (CreatorCountText)
    {
        CreatorCountText->SetText(FText::FromString(
            FString::Printf(TEXT("%d Creators"), DisplayedCreators.Num())));
    }

    OnGalleryPopulated(DisplayedCreators.Num());

    if (GalleryEntranceAnim)
    {
        PlayAnimation(GalleryEntranceAnim);
    }
}

void UFELCreatorGalleryWidget::FilterBySearch(const FString& SearchText)
{
    if (SearchText.IsEmpty())
    {
        ClearFilters();
        return;
    }

    UGameInstance* GI = UGameplayStatics::GetGameInstance(this);
    if (!GI) return;
    UFELCreatorManager* CM = GI->GetSubsystem<UFELCreatorManager>();
    if (!CM) return;

    TArray<FCreatorProfile> AllCreators = CM->GetAllCreators();
    DisplayedCreators.Empty();

    for (const FCreatorProfile& C : AllCreators)
    {
        if (C.DisplayName.Contains(SearchText, ESearchCase::IgnoreCase) ||
            C.Location.Contains(SearchText, ESearchCase::IgnoreCase) ||
            C.PrimarySport.Contains(SearchText, ESearchCase::IgnoreCase) ||
            C.Tagline.Contains(SearchText, ESearchCase::IgnoreCase))
        {
            DisplayedCreators.Add(C);
        }
    }

    PopulateGrid(DisplayedCreators);
}

void UFELCreatorGalleryWidget::FilterBySport(const FString& Sport)
{
    if (Sport == TEXT("All Sports") || Sport.IsEmpty())
    {
        ClearFilters();
        return;
    }

    UGameInstance* GI = UGameplayStatics::GetGameInstance(this);
    if (!GI) return;
    UFELCreatorManager* CM = GI->GetSubsystem<UFELCreatorManager>();
    if (!CM) return;

    DisplayedCreators = CM->GetCreatorsBySport(Sport);
    PopulateGrid(DisplayedCreators);
}

void UFELCreatorGalleryWidget::FilterByTier(ECreatorTier Tier)
{
    UGameInstance* GI = UGameplayStatics::GetGameInstance(this);
    if (!GI) return;
    UFELCreatorManager* CM = GI->GetSubsystem<UFELCreatorManager>();
    if (!CM) return;

    DisplayedCreators = CM->GetCreatorsByTier(Tier);
    PopulateGrid(DisplayedCreators);
}

void UFELCreatorGalleryWidget::ClearFilters()
{
    UGameInstance* GI = UGameplayStatics::GetGameInstance(this);
    if (!GI) return;
    UFELCreatorManager* CM = GI->GetSubsystem<UFELCreatorManager>();
    if (!CM) return;

    DisplayedCreators = CM->GetAllCreators();
    PopulateGrid(DisplayedCreators);

    if (SearchBox) SearchBox->SetText(FText::GetEmpty());
    if (SportFilter) SportFilter->SetSelectedOption(TEXT("All Sports"));
}

void UFELCreatorGalleryWidget::OpenCreatorProfile(const FString& CreatorID)
{
    OnCreatorProfileOpened(CreatorID);
}

void UFELCreatorGalleryWidget::CloseGallery()
{
    OnGalleryClosed();
    RemoveFromParent();
}

void UFELCreatorGalleryWidget::PopulateGrid(const TArray<FCreatorProfile>& Creators)
{
    if (!CreatorGrid) return;

    // Clear existing
    CreatorGrid->ClearChildren();
    CardWidgets.Empty();

    if (!CreatorCardClass) return;

    int32 Index = 0;
    for (const FCreatorProfile& Creator : Creators)
    {
        UFELCreatorCardWidget* Card = CreateWidget<UFELCreatorCardWidget>(this, CreatorCardClass);
        if (Card)
        {
            Card->SetupCard(Creator);
            int32 Row = Index / GridColumns;
            int32 Col = Index % GridColumns;
            CreatorGrid->AddChildToUniformGrid(Card, Row, Col);
            CardWidgets.Add(Card);

            // Stagger entrance animations
            FTimerHandle TimerHandle;
            FTimerDelegate TimerDelegate;
            TimerDelegate.BindLambda([Card]() { Card->PlayEntranceAnimation(); });
            GetWorld()->GetTimerManager().SetTimer(TimerHandle, TimerDelegate, Index * 0.1f, false);

            Index++;
        }
    }

    if (CreatorCountText)
    {
        CreatorCountText->SetText(FText::FromString(
            FString::Printf(TEXT("%d Creators"), Creators.Num())));
    }
}

void UFELCreatorGalleryWidget::PopulateFeaturedCarousel()
{
    if (!FeaturedCarousel) return;
    FeaturedCarousel->ClearChildren();

    UGameInstance* GI = UGameplayStatics::GetGameInstance(this);
    if (!GI) return;
    UFELCreatorManager* CM = GI->GetSubsystem<UFELCreatorManager>();
    if (!CM) return;

    TArray<FCreatorProfile> Featured = CM->GetFeaturedCreators();
    if (!CreatorCardClass) return;

    for (const FCreatorProfile& Creator : Featured)
    {
        UFELCreatorCardWidget* Card = CreateWidget<UFELCreatorCardWidget>(this, CreatorCardClass);
        if (Card)
        {
            Card->SetupCard(Creator);
            FeaturedCarousel->AddChild(Card);
        }
    }
}

void UFELCreatorGalleryWidget::AddComingSoonCards()
{
    if (!CreatorGrid || !ComingSoonCardClass) return;

    int32 CurrentCount = CardWidgets.Num();
    for (int32 i = 0; i < 2; i++) // Add 2 "Coming Soon" placeholders
    {
        UUserWidget* Placeholder = CreateWidget<UUserWidget>(this, ComingSoonCardClass);
        if (Placeholder)
        {
            int32 Index = CurrentCount + i;
            int32 Row = Index / GridColumns;
            int32 Col = Index % GridColumns;
            CreatorGrid->AddChildToUniformGrid(Placeholder, Row, Col);
        }
    }
}

void UFELCreatorGalleryWidget::HandleSearchChanged(const FText& Text)
{
    FilterBySearch(Text.ToString());
}

void UFELCreatorGalleryWidget::HandleSportFilterChanged(FString SelectedItem, ESelectInfo::Type SelectionType)
{
    FilterBySport(SelectedItem);
}

void UFELCreatorGalleryWidget::HandleCloseClicked()
{
    CloseGallery();
}
