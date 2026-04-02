// Copyright Final Evolution Lab. All Rights Reserved.
// FELCreatorCardWidget.cpp

#include "FELCreatorCardWidget.h"
#include "Components/Image.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/Border.h"
#include "Components/Overlay.h"
#include "Animation/WidgetAnimation.h"
#include "FELCreatorManager.h"
#include "Kismet/GameplayStatics.h"

void UFELCreatorCardWidget::NativeConstruct()
{
    Super::NativeConstruct();

    if (ViewProfileButton)
    {
        ViewProfileButton->OnClicked.AddDynamic(this, &UFELCreatorCardWidget::HandleViewProfileClicked);
    }
}

void UFELCreatorCardWidget::SetupCard(const FCreatorProfile& Profile)
{
    CurrentCreatorID = Profile.CreatorID;
    CurrentStyle = Profile.CardStyle;

    // Set text fields
    if (CreatorNameText)
    {
        CreatorNameText->SetText(FText::FromString(Profile.DisplayName));
    }

    if (TaglineText)
    {
        TaglineText->SetText(FText::FromString(Profile.Tagline));
    }

    if (LocationText)
    {
        LocationText->SetText(FText::FromString(Profile.Location));
    }

    if (SportText)
    {
        SportText->SetText(FText::FromString(Profile.PrimarySport + TEXT(" | ") + Profile.Position));
    }

    // Show primary stat (first stat in array)
    if (PrimaryStatText && Profile.Stats.Num() > 0)
    {
        PrimaryStatText->SetText(FText::FromString(
            Profile.Stats[0].StatName + TEXT(": ") + Profile.Stats[0].StatValue));
    }

    // Show/hide 3D model icon
    if (Has3DModelIcon)
    {
        Has3DModelIcon->SetVisibility(Profile.bHas3DModel ? ESlateVisibility::Visible : ESlateVisibility::Collapsed);
    }

    // Apply card style via Blueprint event
    OnApplyCardStyle(Profile.CardStyle, Profile.Tier);
}

void UFELCreatorCardWidget::PlayEntranceAnimation()
{
    if (EntranceAnim)
    {
        PlayAnimation(EntranceAnim);
    }
}

void UFELCreatorCardWidget::SetHovered(bool bIsHovered)
{
    if (HoverAnim)
    {
        if (bIsHovered)
        {
            PlayAnimation(HoverAnim);
        }
        else
        {
            PlayAnimation(HoverAnim, 0.f, 1, EUMGSequencePlayMode::Reverse);
        }
    }
}

void UFELCreatorCardWidget::NativeOnMouseEnter(const FGeometry& InGeometry, const FPointerEvent& InMouseEvent)
{
    Super::NativeOnMouseEnter(InGeometry, InMouseEvent);
    SetHovered(true);
}

void UFELCreatorCardWidget::NativeOnMouseLeave(const FPointerEvent& InMouseEvent)
{
    Super::NativeOnMouseLeave(InMouseEvent);
    SetHovered(false);
}

FReply UFELCreatorCardWidget::NativeOnMouseButtonUp(const FGeometry& InGeometry, const FPointerEvent& InMouseEvent)
{
    if (InMouseEvent.GetEffectingButton() == EKeys::LeftMouseButton)
    {
        HandleViewProfileClicked();
        return FReply::Handled();
    }
    return Super::NativeOnMouseButtonUp(InGeometry, InMouseEvent);
}

void UFELCreatorCardWidget::HandleViewProfileClicked()
{
    // Notify the CreatorManager
    if (UGameInstance* GI = UGameplayStatics::GetGameInstance(this))
    {
        if (UFELCreatorManager* CM = GI->GetSubsystem<UFELCreatorManager>())
        {
            CM->SelectCreator(CurrentCreatorID);
        }
    }

    // Fire Blueprint event
    OnCardClicked(CurrentCreatorID);
}
