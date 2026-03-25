// Copyright (c) Final Evolution Lab. Unreal Starter — drop into Source/YourProject/Player/

#include "FELPlayerController.h"
// Optional: Enhanced Input (uncomment if project uses it)
// #include "EnhancedInputComponent.h"
// #include "EnhancedInputSubsystems.h"
// #include "InputMappingContext.h"
// #include "InputAction.h"

AFELPlayerController::AFELPlayerController(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	// Initialize any default subobjects here, e.g.:
	// MyComponent = CreateDefaultSubobject<UMyComponent>(TEXT("MyComponent"));
}

void AFELPlayerController::BeginPlay()
{
	Super::BeginPlay();

	// Optional: Add DefaultMappingContext to Enhanced Input (uncomment if using Enhanced Input)
	// if (UEnhancedInputLocalPlayerSubsystem* Subsystem = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(GetLocalPlayer()))
	// {
	//     if (DefaultMappingContext)
	//     {
	//         Subsystem->AddMappingContext(DefaultMappingContext, 0);
	//     }
	// }
}

void AFELPlayerController::SetupInputComponent()
{
	Super::SetupInputComponent();

	// Bind legacy FKey input (works without Enhanced Input). Add "Sprint" in Project Settings → Input.
	InputComponent->BindAction("Sprint", IE_Pressed, this, &AFELPlayerController::InputSprintPressed);
	InputComponent->BindAction("Sprint", IE_Released, this, &AFELPlayerController::InputSprintReleased);

	// Optional: Bind Enhanced Input actions (uncomment if using Enhanced Input)
	// if (UEnhancedInputComponent* EIC = Cast<UEnhancedInputComponent>(InputComponent))
	// {
	//     if (MoveAction) EIC->BindAction(MoveAction, ETriggerEvent::Triggered, this, &AFELPlayerController::HandleMove);
	//     if (JumpAction) EIC->BindAction(JumpAction, ETriggerEvent::Started, this, &AFELPlayerController::HandleJump);
	// }
	// (Jump is typically implemented on the controlled Pawn/Character, not the controller.)
}

void AFELPlayerController::InputSprintPressed()
{
	bIsSprinting = true;
}

void AFELPlayerController::InputSprintReleased()
{
	bIsSprinting = false;
}
