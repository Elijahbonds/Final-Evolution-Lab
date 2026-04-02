// Copyright (c) Final Evolution Lab.
// UMG Widget: Subscription prompt shown when trial expires (WBP_SubscriptionPrompt).
// Phase 3: Subscription Model

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELSubscriptionPromptWidget.generated.h"

class UTextBlock;
class UButton;
class URichTextBlock;

UCLASS()
class FINALEVOLUTIONLAB_API UFELSubscriptionPromptWidget : public UUserWidget
{
	GENERATED_BODY()

protected:
	virtual void NativeConstruct() override;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* HeadlineText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	URichTextBlock* BenefitsText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* PriceText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* SubscribeButton;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* MaybeLaterButton;

private:
	UFUNCTION()
	void OnSubscribeClicked();

	UFUNCTION()
	void OnMaybeLaterClicked();
};
