// Copyright Final Evolution Lab. All Rights Reserved.
// FELCreatorProfileWidget.h - Full Creator Profile Page Widget

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELCreatorProfile.h"
#include "FELCreatorProfileWidget.generated.h"

class UImage;
class UTextBlock;
class UButton;
class UScrollBox;
class UHorizontalBox;
class UVerticalBox;
class UUniformGridPanel;
class UMediaPlayer;

/**
 * UFELCreatorProfileWidget - Full-page creator profile view.
 * 
 * Displays:
 *  - Large banner image
 *  - Profile photo + name + bio
 *  - Detailed stats grid
 *  - Highlight reel video carousel
 *  - Signature moves showcase
 *  - 3D model viewer (for creators with models)
 *  - Social media links
 *  - Challenges list
 *  - "Play as Creator" button
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELCreatorProfileWidget : public UUserWidget
{
    GENERATED_BODY()

public:
    /** Load and display a creator profile */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|CreatorProfile")
    void LoadProfile(const FString& CreatorID);

    /** Refresh the display with current data */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|CreatorProfile")
    void RefreshDisplay();

    /** Navigate to the next/previous highlight */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|CreatorProfile")
    void NextHighlight();

    UFUNCTION(BlueprintCallable, Category = "FEL|UI|CreatorProfile")
    void PreviousHighlight();

    /** Play the current highlight video */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|CreatorProfile")
    void PlayCurrentHighlight();

    /** Close the profile and return to gallery */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|CreatorProfile")
    void CloseProfile();

protected:
    virtual void NativeConstruct() override;

    // ── Bound Widgets ──

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UImage* BannerImage;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UImage* ProfileImage;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* NameText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* TaglineText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* BioText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* LocationText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* HeightWeightText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UVerticalBox* StatsContainer;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UScrollBox* HighlightsScrollBox;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* HighlightTitleText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UImage* HighlightThumbnail;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UVerticalBox* SignatureMovesContainer;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UVerticalBox* ChallengesContainer;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UHorizontalBox* SocialLinksContainer;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UButton* PlayAsCreatorButton;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UButton* CloseButton;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UButton* NextHighlightButton;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UButton* PrevHighlightButton;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UImage* ModelViewer3D;

    // ── Animations ──

    UPROPERTY(BlueprintReadOnly, Transient, meta = (BindWidgetAnimOptional), Category = "Animations")
    UWidgetAnimation* ProfileEntranceAnim;

    // ── Blueprint Events ──

    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|UI|CreatorProfile")
    void OnProfileLoaded(const FCreatorProfile& Profile);

    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|UI|CreatorProfile")
    void OnPlayAsCreatorRequested(const FString& CreatorID);

    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|UI|CreatorProfile")
    void OnHighlightChanged(int32 Index, const FCreatorHighlight& Highlight);

    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|UI|CreatorProfile")
    void OnSetup3DModelViewer(const FString& ModelPath);

    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|UI|CreatorProfile")
    void OnProfileClosed();

private:
    UFUNCTION()
    void HandlePlayAsCreator();

    UFUNCTION()
    void HandleClose();

    void PopulateStats(const FCreatorProfile& Profile);
    void PopulateHighlights(const FCreatorProfile& Profile);
    void PopulateSignatureMoves(const FCreatorProfile& Profile);
    void PopulateChallenges(const FCreatorProfile& Profile);
    void PopulateSocialLinks(const FCreatorProfile& Profile);
    void UpdateHighlightDisplay();

    FCreatorProfile CurrentProfile;
    int32 CurrentHighlightIndex = 0;
};
