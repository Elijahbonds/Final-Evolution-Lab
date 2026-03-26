// Copyright (c) Final Evolution Lab.
// First-time Lab entry: Get Ready–style copy per PROJECT_FLOWS.md (Arena/Lab sequencing).

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELOnboardingWidget.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnFELOnboardingDismissed);

/**
 * Shown once until lab_onboarding_completed.flag exists in Documents/FEL (iOS) or Saved/FEL (desktop).
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELOnboardingWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	/** Build UI + bind dismiss; call after CreateWidget. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Onboarding")
	void InitializeLabOnboarding();

	UPROPERTY(BlueprintAssignable, Category = "FEL|Onboarding")
	FOnFELOnboardingDismissed OnDismissed;

protected:
	virtual void NativeConstruct() override;

private:
	void BuildFallbackLayout();

	UFUNCTION()
	void OnDismissClicked();

	UPROPERTY(meta = (BindWidgetOptional))
	class UTextBlock* BodyTextBlock = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	class UButton* DismissButton = nullptr;

	UPROPERTY(meta = (BindWidgetOptional))
	class UButton* WatchDemoButton = nullptr;

	UFUNCTION()
	void OnWatchDemoClicked();
};
