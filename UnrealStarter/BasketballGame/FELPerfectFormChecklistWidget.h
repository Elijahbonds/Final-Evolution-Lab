// Copyright (c) Final Evolution Lab.
// Lightweight "Perfect Form" lines for UFELDemoManager (Blueprint subclass allowed).

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FELPerfectFormChecklistWidget.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFELPerfectFormChecklistWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	void InitializeChecklist(const TArray<FText>& Lines, float FontScale);

protected:
	virtual void NativeConstruct() override;

private:
	void RebuildFromPending();

	TArray<FText> PendingLines;
	float PendingFontScale = 1.f;
};
