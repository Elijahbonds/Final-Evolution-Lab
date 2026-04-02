// Copyright Final Evolution Lab. All Rights Reserved.
// FELCreatorCardWidget.h - Creator Card UMG Widget
// Individual creator card for gallery display

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELCreatorProfile.h"
#include "FELCreatorCardWidget.generated.h"

class UImage;
class UTextBlock;
class UButton;
class UBorder;
class UOverlay;
class UHorizontalBox;

/**
 * UFELCreatorCardWidget - Individual creator card for gallery/showcase.
 * 
 * Displays:
 *  - Profile image (circular)
 *  - Creator name and tagline
 *  - Key stats
 *  - Tier badge
 *  - "View Profile" button
 *  - Card background with style effects
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELCreatorCardWidget : public UUserWidget
{
    GENERATED_BODY()

public:
    /** Initialize card with a creator profile */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|CreatorCard")
    void SetupCard(const FCreatorProfile& Profile);

    /** Get the creator ID this card represents */
    UFUNCTION(BlueprintPure, Category = "FEL|UI|CreatorCard")
    FString GetCreatorID() const { return CurrentCreatorID; }

    /** Play card entrance animation */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|CreatorCard")
    void PlayEntranceAnimation();

    /** Set hover state */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|CreatorCard")
    void SetHovered(bool bIsHovered);

protected:
    virtual void NativeConstruct() override;
    virtual void NativeOnMouseEnter(const FGeometry& InGeometry, const FPointerEvent& InMouseEvent) override;
    virtual void NativeOnMouseLeave(const FPointerEvent& InMouseEvent) override;
    virtual FReply NativeOnMouseButtonUp(const FGeometry& InGeometry, const FPointerEvent& InMouseEvent) override;

    // ── Bound Widgets (set in Blueprint child class) ──────────────

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UImage* ProfileImage;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* CreatorNameText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* TaglineText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* LocationText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* SportText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* PrimaryStatText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UButton* ViewProfileButton;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UImage* TierBadge;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UImage* CardBackground;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UBorder* CardBorder;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UImage* Has3DModelIcon;

    // ── Animations (set in Blueprint) ─────────────────────────────

    UPROPERTY(BlueprintReadOnly, Transient, meta = (BindWidgetAnimOptional), Category = "Animations")
    UWidgetAnimation* EntranceAnim;

    UPROPERTY(BlueprintReadOnly, Transient, meta = (BindWidgetAnimOptional), Category = "Animations")
    UWidgetAnimation* HoverAnim;

    // ── Blueprint Events ──────────────────────────────────────────

    /** Called when the card is clicked */
    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|UI|CreatorCard")
    void OnCardClicked(const FString& CreatorID);

    /** Called to update visual style based on tier */
    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|UI|CreatorCard")
    void OnApplyCardStyle(ECreatorCardStyle Style, ECreatorTier Tier);

private:
    UFUNCTION()
    void HandleViewProfileClicked();

    FString CurrentCreatorID;
    ECreatorCardStyle CurrentStyle = ECreatorCardStyle::Standard;
};
