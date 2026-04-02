// Copyright (c) Final Evolution Lab.
// UMG Widget: Subscription status display (WBP_SubscriptionStatus).
// Phase 3: Subscription Model

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELSubscription.h"
#include "FELSubscriptionStatusWidget.generated.h"

class UTextBlock;
class UButton;
class UProgressBar;

UCLASS()
class FINALEVOLUTIONLAB_API UFELSubscriptionStatusWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintCallable, Category = "FEL|UI")
	void RefreshStatus();

protected:
	virtual void NativeConstruct() override;
	virtual void NativeTick(const FGeometry& MyGeometry, float InDeltaTime) override;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* StatusText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* TrialCountdownText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* NextBillingText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* PriceText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UProgressBar* TrialProgressBar;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* ManageButton;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* SubscribeButton;

private:
	UFUNCTION()
	void OnManageClicked();

	UFUNCTION()
	void OnSubscribeClicked();

	float TickAccum = 0.f;
};
