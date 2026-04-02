// Copyright Final Evolution Lab. All Rights Reserved.
// FELMainMenuCreatorIntegration.cpp

#include "FELMainMenuCreatorIntegration.h"
#include "FELCreatorGalleryWidget.h"
#include "FELCreatorProfileWidget.h"
#include "FELCreatorManager.h"
#include "Components/Button.h"
#include "Components/HorizontalBox.h"
#include "Components/Image.h"
#include "Components/TextBlock.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"

void UFELMainMenuCreatorIntegration::NativeConstruct()
{
    Super::NativeConstruct();

    if (CreatorsButton)
    {
        CreatorsButton->OnClicked.AddDynamic(this, &UFELMainMenuCreatorIntegration::HandleCreatorsButtonClicked);
    }
    if (NextFeaturedButton)
    {
        NextFeaturedButton->OnClicked.AddDynamic(this, &UFELMainMenuCreatorIntegration::HandleNextFeatured);
    }
    if (PrevFeaturedButton)
    {
        PrevFeaturedButton->OnClicked.AddDynamic(this, &UFELMainMenuCreatorIntegration::HandlePrevFeatured);
    }
}

void UFELMainMenuCreatorIntegration::InitializeCreatorSection()
{
    UGameInstance* GI = UGameplayStatics::GetGameInstance(this);
    if (!GI) return;

    UFELCreatorManager* CM = GI->GetSubsystem<UFELCreatorManager>();
    if (!CM) return;

    // Load featured creators
    FeaturedCreators = CM->GetFeaturedCreators();
    CurrentFeaturedIndex = 0;

    // Update creator count label
    if (CreatorCountLabel)
    {
        CreatorCountLabel->SetText(FText::FromString(
            FString::Printf(TEXT("%d Creators"), CM->GetCreatorCount())));
    }

    // Display first featured creator
    UpdateFeaturedDisplay();

    // Start auto-rotation
    StartAutoRotation();
}

void UFELMainMenuCreatorIntegration::OpenCreatorGallery()
{
    if (!GalleryWidgetClass) return;

    if (!ActiveGallery || !ActiveGallery->IsInViewport())
    {
        ActiveGallery = CreateWidget<UFELCreatorGalleryWidget>(this, GalleryWidgetClass);
        if (ActiveGallery)
        {
            ActiveGallery->AddToViewport(100);
            ActiveGallery->InitializeGallery();
            OnGalleryOpened();
        }
    }
}

void UFELMainMenuCreatorIntegration::OpenCreatorProfile(const FString& CreatorID)
{
    if (!ProfileWidgetClass) return;

    ActiveProfile = CreateWidget<UFELCreatorProfileWidget>(this, ProfileWidgetClass);
    if (ActiveProfile)
    {
        ActiveProfile->AddToViewport(110);
        ActiveProfile->LoadProfile(CreatorID);
    }
}

void UFELMainMenuCreatorIntegration::NextFeaturedCreator()
{
    if (FeaturedCreators.Num() > 0)
    {
        CurrentFeaturedIndex = (CurrentFeaturedIndex + 1) % FeaturedCreators.Num();
        UpdateFeaturedDisplay();
    }
}

void UFELMainMenuCreatorIntegration::PreviousFeaturedCreator()
{
    if (FeaturedCreators.Num() > 0)
    {
        CurrentFeaturedIndex = (CurrentFeaturedIndex - 1 + FeaturedCreators.Num()) % FeaturedCreators.Num();
        UpdateFeaturedDisplay();
    }
}

void UFELMainMenuCreatorIntegration::HandleCreatorsButtonClicked()
{
    OpenCreatorGallery();
}

void UFELMainMenuCreatorIntegration::HandleNextFeatured()
{
    NextFeaturedCreator();
}

void UFELMainMenuCreatorIntegration::HandlePrevFeatured()
{
    PreviousFeaturedCreator();
}

void UFELMainMenuCreatorIntegration::UpdateFeaturedDisplay()
{
    if (!FeaturedCreators.IsValidIndex(CurrentFeaturedIndex)) return;

    const FCreatorProfile& Featured = FeaturedCreators[CurrentFeaturedIndex];

    if (FeaturedCreatorName)
    {
        FeaturedCreatorName->SetText(FText::FromString(Featured.DisplayName));
    }
    if (FeaturedCreatorTagline)
    {
        FeaturedCreatorTagline->SetText(FText::FromString(Featured.Tagline));
    }

    OnFeaturedCreatorChanged(Featured);
}

void UFELMainMenuCreatorIntegration::StartAutoRotation()
{
    if (FeaturedCreators.Num() <= 1) return;
    if (!GetWorld()) return;

    GetWorld()->GetTimerManager().SetTimer(
        AutoRotateTimer,
        this,
        &UFELMainMenuCreatorIntegration::HandleNextFeatured,
        FeaturedRotationInterval,
        true  // Looping
    );
}
