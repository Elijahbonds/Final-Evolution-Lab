// Copyright (c) Final Evolution Lab.
// Splash → main menu (controller-first, no Blueprint asset required).

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "UFELRetailStartupWidget.generated.h"

class UButton;
class UTextBlock;
class UVerticalBox;
class UFELGameInstance;

UCLASS()
class FINALEVOLUTIONLAB_API UFELRetailStartupWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	void InitializeRetailFlow(UFELGameInstance* InOwner);

protected:
	virtual void NativeConstruct() override;

private:
	void BuildLayout();
	void ShowSplashPhase();
	void ShowMenuPhase();

	UFUNCTION()
	void OnPlayClicked();

	UFUNCTION()
	void OnQuitClicked();

	UPROPERTY(Transient)
	TObjectPtr<UFELGameInstance> OwnerGI = nullptr;

	UPROPERTY(Transient)
	TObjectPtr<UTextBlock> BodyText = nullptr;

	UPROPERTY(Transient)
	TObjectPtr<UVerticalBox> MenuBox = nullptr;

	UPROPERTY(Transient)
	TObjectPtr<UButton> PlayButton = nullptr;

	UPROPERTY(Transient)
	TObjectPtr<UButton> QuitButton = nullptr;

	FTimerHandle PhaseTimerHandle;
};
