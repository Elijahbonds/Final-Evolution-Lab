// Copyright (c) Final Evolution Lab. Unreal Starter — drop into Source/YourProject/Player/

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "FELPlayerController.generated.h"

class UInputMappingContext;
class UInputAction;

/**
 * Starter Player Controller for UE5.
 * Use as base for game-specific input and HUD; extend in Blueprint or C++.
 * Follows Unreal Coding Standard and .cursorrules (PascalCase, CreateDefaultSubobject, UPROPERTY specifiers).
 */
UCLASS()
class AFELPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	AFELPlayerController(const FObjectInitializer& ObjectInitializer = FObjectInitializer::Get());

	// Optional: Enhanced Input (uncomment if project uses Enhanced Input)
	// UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Input")
	// TObjectPtr<UInputMappingContext> DefaultMappingContext;
	//
	// UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Input")
	// TObjectPtr<UInputAction> MoveAction;
	//
	// UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Input")
	// TObjectPtr<UInputAction> JumpAction;

	/** Designer-facing: sprint multiplier applied to movement. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Movement", meta = (ClampMin = "1.0", ClampMax = "3.0"))
	float SprintMultiplier = 1.5f;

	/** Exposed to Blueprint for HUD or gameplay. */
	UFUNCTION(BlueprintCallable, Category = "Player")
	bool IsSprinting() const { return bIsSprinting; }

protected:
	virtual void BeginPlay() override;
	virtual void SetupInputComponent() override;

	UFUNCTION(BlueprintCallable, Category = "Input")
	void InputSprintPressed();

	UFUNCTION(BlueprintCallable, Category = "Input")
	void InputSprintReleased();

private:
	UPROPERTY()
	bool bIsSprinting = false;
};
