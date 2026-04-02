// Copyright Final Evolution Lab. All Rights Reserved.
// FELMainMenuCreatorIntegration.h - Main Menu Creator Showcase Integration
// Handles the "Creators" button and featured creator carousel on the home screen.

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELCreatorProfile.h"
#include "FELMainMenuCreatorIntegration.generated.h"

class UFELCreatorGalleryWidget;
class UFELCreatorProfileWidget;
class UButton;
class UWidgetSwitcher;
class UHorizontalBox;
class UImage;
class UTextBlock;

/**
 * UFELMainMenuCreatorIntegration
 * 
 * Widget component for the main menu that provides:
 *  - "Creators" button to open the gallery
 *  - Featured creator carousel on the home screen
 *  - Quick-access creator cards
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELMainMenuCreatorIntegration : public UUserWidget
{
    GENERATED_BODY()

public:
    /** Initialize the main menu creator section */
    UFUNCTION(BlueprintCallable, Category = "FEL|MainMenu")
    void InitializeCreatorSection();

    /** Open the full creator gallery */
    UFUNCTION(BlueprintCallable, Category = "FEL|MainMenu")
    void OpenCreatorGallery();

    /** Open a specific creator's profile */
    UFUNCTION(BlueprintCallable, Category = "FEL|MainMenu")
    void OpenCreatorProfile(const FString& CreatorID);

    /** Cycle to next featured creator */
    UFUNCTION(BlueprintCallable, Category = "FEL|MainMenu")
    void NextFeaturedCreator();

    /** Cycle to previous featured creator */
    UFUNCTION(BlueprintCallable, Category = "FEL|MainMenu")
    void PreviousFeaturedCreator();

protected:
    virtual void NativeConstruct() override;

    // ── Bound Widgets ──

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UButton* CreatorsButton;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UHorizontalBox* FeaturedCreatorBar;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UImage* FeaturedCreatorImage;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* FeaturedCreatorName;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* FeaturedCreatorTagline;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UButton* NextFeaturedButton;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UButton* PrevFeaturedButton;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidgetOptional), Category = "Widgets")
    UTextBlock* CreatorCountLabel;

    // ── Configuration ──

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "FEL|MainMenu")
    TSubclassOf<UFELCreatorGalleryWidget> GalleryWidgetClass;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "FEL|MainMenu")
    TSubclassOf<UFELCreatorProfileWidget> ProfileWidgetClass;

    /** Auto-rotate featured creators (seconds) */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "FEL|MainMenu")
    float FeaturedRotationInterval = 5.0f;

    // ── Blueprint Events ──

    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|MainMenu")
    void OnGalleryOpened();

    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|MainMenu")
    void OnGalleryClosed();

    UFUNCTION(BlueprintImplementableEvent, Category = "FEL|MainMenu")
    void OnFeaturedCreatorChanged(const FCreatorProfile& Profile);

private:
    UFUNCTION()
    void HandleCreatorsButtonClicked();

    UFUNCTION()
    void HandleNextFeatured();

    UFUNCTION()
    void HandlePrevFeatured();

    void UpdateFeaturedDisplay();
    void StartAutoRotation();

    TArray<FCreatorProfile> FeaturedCreators;
    int32 CurrentFeaturedIndex = 0;

    UPROPERTY()
    UFELCreatorGalleryWidget* ActiveGallery;

    UPROPERTY()
    UFELCreatorProfileWidget* ActiveProfile;

    FTimerHandle AutoRotateTimer;
};
