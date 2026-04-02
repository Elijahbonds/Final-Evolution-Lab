// Copyright (c) Final Evolution Lab.
// UMG Widget: Persistent trial countdown banner (WBP_TrialBanner).
// Phase 3: Subscription Model

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELTrialBannerWidget.generated.h"

class UTextBlock;
class UButton;
class UBorder;

UCLASS()
class FINALEVOLUTIONLAB_API UFELTrialBannerWidget : public UUserWidget
{
	GENERATED_BODY()

protected:
	virtual void NativeConstruct() override;
	virtual void NativeTick(const FGeometry& MyGeometry, float InDeltaTime) override;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UBorder* BannerBorder;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* TrialMessageText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UTextBlock* SubscribeInfoText;

	UPROPERTY(meta = (BindWidget), BlueprintReadOnly)
	UButton* SubscribeNowButton;

private:
	UFUNCTION()
	void OnSubscribeNowClicked();

	void UpdateBanner();

	float TickAccum = 0.f;
};
