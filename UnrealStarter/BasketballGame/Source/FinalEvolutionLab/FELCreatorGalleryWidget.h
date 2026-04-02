// Copyright Final Evolution Lab. All Rights Reserved.
// FELCreatorGalleryWidget.h - Creator Gallery/Showcase Widget

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELCreatorProfile.h"
#include "FELCreatorGalleryWidget.generated.h"

class UScrollBox;
class UUniformGridPanel;
class UEditableTextBox;
class UComboBoxString;
class UTextBlock;
class UButton;
class UFELCreatorCardWidget;

/**
 * UFELCreatorGalleryWidget - Gallery/showcase view for all creators.
 * 
 * Features:
 *  - Grid layout of creator cards
 *  - Search/filter functionality
 *  - "Featured Creators" carousel
 *  - "Coming Soon" placeholders
 *  - Smooth scrolling
 *  - Click to view full profile
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELCreatorGalleryWidget : public UUserWidget
{
    GENERATED_BODY()

public:
    /** Initialize and populate the gallery */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|Gallery")
    void InitializeGallery();

    /** Filter creators by search text */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|Gallery")
    void FilterBySearch(const FString& SearchText);

    /** Filter creators by sport */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|Gallery")
    void FilterBySport(const FString& Sport);

    /** Filter creators by tier */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|Gallery")
    void FilterByTier(ECreatorTier Tier);

    /** Clear all filters */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|Gallery")
    void ClearFilters();

    /** Open a creator's full profile */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|Gallery")
    void OpenCreatorProfile(const FString& CreatorID);

    /** Close the gallery */
    UFUNCTION(BlueprintCallable, Category = "FEL|UI|Gallery")
    void CloseGallery();

protected:
    virtual void NativeConstruct() override;

    // ── Bound Widgets ──

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UScrollBox* FeaturedCarousel;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UUniformGridPanel* CreatorGrid;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UEditableTextBox* SearchBox;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UComboBoxString* SportFilter;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* CreatorCountText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* GalleryTitleText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UButton* CloseGalleryButton;

    // ── Configuration ──

    /** Widget class for individual creator cards (set in Blueprint) */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "FEL|UI|Gallery")
    TSubclassOf<UFELCreatorCardWidget> CreatorCardClass;

    /** Widget class for "Coming Soon" placeholder cards */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "FEL|UI|Gallery")
    TSubclassOf<UUserWidget> ComingSoonCardClass;

    /** Number of columns in the creator grid */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "FEL|UI|Gallery")
    int32 GridColumns = 3;

    // ── Animations ──

    UPROPERTY(BlueprintReadOnly, Transient, meta = (BindWidgetAnimOptional), Category = "Animations")
    UWidgetAnimation* GalleryEntranceAnim;

    // ── Blueprint Events ──

    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|UI|Gallery")
    void OnGalleryPopulated(int32 CreatorCount);

    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|UI|Gallery")
    void OnCreatorProfileOpened(const FString& CreatorID);

    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|UI|Gallery")
    void OnGalleryClosed();

private:
    UFUNCTION()
    void HandleSearchChanged(const FText& Text);

    UFUNCTION()
    void HandleSportFilterChanged(FString SelectedItem, ESelectInfo::Type SelectionType);

    UFUNCTION()
    void HandleCloseClicked();

    void PopulateGrid(const TArray<FCreatorProfile>& Creators);
    void PopulateFeaturedCarousel();
    void AddComingSoonCards();

    /** All creators currently displayed */
    TArray<FCreatorProfile> DisplayedCreators;

    /** Created card widget references */
    UPROPERTY()
    TArray<UFELCreatorCardWidget*> CardWidgets;
};
