// Copyright Final Evolution Lab. All Rights Reserved.
// FELCreatorProfileWidget.cpp

#include "FELCreatorProfileWidget.h"
#include "Components/Image.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/ScrollBox.h"
#include "Components/VerticalBox.h"
#include "Components/HorizontalBox.h"
#include "FELCreatorManager.h"
#include "Kismet/GameplayStatics.h"

void UFELCreatorProfileWidget::NativeConstruct()
{
    Super::NativeConstruct();

    if (PlayAsCreatorButton)
    {
        PlayAsCreatorButton->OnClicked.AddDynamic(this, &UFELCreatorProfileWidget::HandlePlayAsCreator);
    }
    if (CloseButton)
    {
        CloseButton->OnClicked.AddDynamic(this, &UFELCreatorProfileWidget::HandleClose);
    }
    if (NextHighlightButton)
    {
        NextHighlightButton->OnClicked.AddDynamic(this, &UFELCreatorProfileWidget::NextHighlight);
    }
    if (PrevHighlightButton)
    {
        PrevHighlightButton->OnClicked.AddDynamic(this, &UFELCreatorProfileWidget::PreviousHighlight);
    }
}

void UFELCreatorProfileWidget::LoadProfile(const FString& CreatorID)
{
    if (UGameInstance* GI = UGameplayStatics::GetGameInstance(this))
    {
        if (UFELCreatorManager* CM = GI->GetSubsystem<UFELCreatorManager>())
        {
            if (CM->GetCreatorProfile(CreatorID, CurrentProfile))
            {
                RefreshDisplay();
                OnProfileLoaded(CurrentProfile);

                if (ProfileEntranceAnim)
                {
                    PlayAnimation(ProfileEntranceAnim);
                }
            }
        }
    }
}

void UFELCreatorProfileWidget::RefreshDisplay()
{
    // Basic info
    if (NameText) NameText->SetText(FText::FromString(CurrentProfile.DisplayName));
    if (TaglineText) TaglineText->SetText(FText::FromString(CurrentProfile.Tagline));
    if (BioText) BioText->SetText(FText::FromString(CurrentProfile.Bio));
    if (LocationText) LocationText->SetText(FText::FromString(CurrentProfile.Location));
    if (HeightWeightText)
    {
        HeightWeightText->SetText(FText::FromString(
            CurrentProfile.Height + TEXT(" | ") + CurrentProfile.Weight));
    }

    // Populate sections
    PopulateStats(CurrentProfile);
    PopulateHighlights(CurrentProfile);
    PopulateSignatureMoves(CurrentProfile);
    PopulateChallenges(CurrentProfile);
    PopulateSocialLinks(CurrentProfile);

    // Setup 3D model viewer if available
    if (CurrentProfile.bHas3DModel && !CurrentProfile.PlayerModelPath.IsEmpty())
    {
        if (ModelViewer3D)
        {
            ModelViewer3D->SetVisibility(ESlateVisibility::Visible);
        }
        OnSetup3DModelViewer(CurrentProfile.PlayerModelPath);
    }
    else if (ModelViewer3D)
    {
        ModelViewer3D->SetVisibility(ESlateVisibility::Collapsed);
    }

    // Show/hide Play As button
    if (PlayAsCreatorButton)
    {
        PlayAsCreatorButton->SetVisibility(
            CurrentProfile.bIsPlayable ? ESlateVisibility::Visible : ESlateVisibility::Collapsed);
    }

    // Reset highlight index
    CurrentHighlightIndex = 0;
    UpdateHighlightDisplay();
}

void UFELCreatorProfileWidget::NextHighlight()
{
    if (CurrentProfile.Highlights.Num() > 0)
    {
        CurrentHighlightIndex = (CurrentHighlightIndex + 1) % CurrentProfile.Highlights.Num();
        UpdateHighlightDisplay();
    }
}

void UFELCreatorProfileWidget::PreviousHighlight()
{
    if (CurrentProfile.Highlights.Num() > 0)
    {
        CurrentHighlightIndex = (CurrentHighlightIndex - 1 + CurrentProfile.Highlights.Num()) % CurrentProfile.Highlights.Num();
        UpdateHighlightDisplay();
    }
}

void UFELCreatorProfileWidget::PlayCurrentHighlight()
{
    // Playback handled via Blueprint event or MediaPlayer integration
    if (CurrentProfile.Highlights.IsValidIndex(CurrentHighlightIndex))
    {
        UE_LOG(LogTemp, Log, TEXT("[FEL] Playing highlight: %s"),
            *CurrentProfile.Highlights[CurrentHighlightIndex].Title);
    }
}

void UFELCreatorProfileWidget::CloseProfile()
{
    OnProfileClosed();
    RemoveFromParent();
}

void UFELCreatorProfileWidget::HandlePlayAsCreator()
{
    OnPlayAsCreatorRequested(CurrentProfile.CreatorID);
}

void UFELCreatorProfileWidget::HandleClose()
{
    CloseProfile();
}

void UFELCreatorProfileWidget::UpdateHighlightDisplay()
{
    if (!CurrentProfile.Highlights.IsValidIndex(CurrentHighlightIndex)) return;

    const FCreatorHighlight& H = CurrentProfile.Highlights[CurrentHighlightIndex];
    if (HighlightTitleText)
    {
        HighlightTitleText->SetText(FText::FromString(H.Title));
    }
    OnHighlightChanged(CurrentHighlightIndex, H);
}

void UFELCreatorProfileWidget::PopulateStats(const FCreatorProfile& Profile)
{
    // Stats are populated via Blueprint (UMG widget binding)
    // C++ provides the data, Blueprint handles visual layout
}

void UFELCreatorProfileWidget::PopulateHighlights(const FCreatorProfile& Profile)
{
    // Highlights populated via Blueprint widget binding
}

void UFELCreatorProfileWidget::PopulateSignatureMoves(const FCreatorProfile& Profile)
{
    // Signature moves populated via Blueprint widget binding
}

void UFELCreatorProfileWidget::PopulateChallenges(const FCreatorProfile& Profile)
{
    // Challenges populated via Blueprint widget binding
}

void UFELCreatorProfileWidget::PopulateSocialLinks(const FCreatorProfile& Profile)
{
    // Social links populated via Blueprint widget binding
}
