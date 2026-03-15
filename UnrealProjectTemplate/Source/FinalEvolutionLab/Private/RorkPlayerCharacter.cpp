#include "RorkPlayerCharacter.h"

#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "EngineUtils.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "InputAction.h"
#include "InputMappingContext.h"
#include "PlayerScoreManager.h"
#include "RorkNativeBridgeComponent.h"

ARorkPlayerCharacter::ARorkPlayerCharacter()
{
    PrimaryActorTick.bCanEverTick = false;
}

void ARorkPlayerCharacter::BeginPlay()
{
    Super::BeginPlay();

    GetCharacterMovement()->MaxWalkSpeed = MoveSpeed;
    CacheBridgeAndScoreManager();

    if (APlayerController* PC = Cast<APlayerController>(GetController()))
    {
        if (ULocalPlayer* LocalPlayer = PC->GetLocalPlayer())
        {
            if (UEnhancedInputLocalPlayerSubsystem* Subsystem = LocalPlayer->GetSubsystem<UEnhancedInputLocalPlayerSubsystem>())
            {
                if (GameplayMappingContext != nullptr)
                {
                    Subsystem->AddMappingContext(GameplayMappingContext, 0);
                }
            }
        }
    }
}

void ARorkPlayerCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
    Super::SetupPlayerInputComponent(PlayerInputComponent);

    UEnhancedInputComponent* EnhancedInput = Cast<UEnhancedInputComponent>(PlayerInputComponent);
    if (EnhancedInput == nullptr)
    {
        UE_LOG(LogTemp, Error, TEXT("[RorkPlayerCharacter] Missing EnhancedInputComponent."));
        return;
    }

    if (MoveAction != nullptr)
    {
        EnhancedInput->BindAction(MoveAction, ETriggerEvent::Triggered, this, &ARorkPlayerCharacter::Move);
    }

    if (DunkAction != nullptr)
    {
        EnhancedInput->BindAction(DunkAction, ETriggerEvent::Started, this, &ARorkPlayerCharacter::Dunk);
    }
}

void ARorkPlayerCharacter::Move(const FInputActionValue& Value)
{
    const FVector2D MoveInput = Value.Get<FVector2D>();
    if (Controller == nullptr)
    {
        return;
    }

    const FRotator ControlRotation = Controller->GetControlRotation();
    const FRotator YawRotation(0.f, ControlRotation.Yaw, 0.f);

    const FVector ForwardDirection = FRotationMatrix(YawRotation).GetUnitAxis(EAxis::X);
    const FVector RightDirection = FRotationMatrix(YawRotation).GetUnitAxis(EAxis::Y);

    AddMovementInput(ForwardDirection, MoveInput.Y);
    AddMovementInput(RightDirection, MoveInput.X);
}

void ARorkPlayerCharacter::Dunk(const FInputActionValue& Value)
{
    UE_UNUSED(Value);

    UE_LOG(LogTemp, Log, TEXT("[RorkPlayerCharacter] Dunk action performed."));
    LaunchCharacter(FVector(0.f, 0.f, DunkImpulse), false, true);

    CacheBridgeAndScoreManager();
    if (PlayerScoreManager == nullptr)
    {
        UE_LOG(LogTemp, Error, TEXT("[RorkPlayerCharacter] PlayerScoreManager not found."));
        return;
    }

    const int32 CurrentScore = PlayerScoreManager->GetPlayerScore();
    const int32 NewScore = CurrentScore + DunkScoreIncrement;
    PlayerScoreManager->UpdatePlayerScore(NewScore);

    if (RorkBridge != nullptr)
    {
        RorkBridge->PostRorkScoreToNative(NewScore);
        UE_LOG(LogTemp, Log, TEXT("[RorkPlayerCharacter] Posted score %d to native."), NewScore);
    }
    else
    {
        UE_LOG(LogTemp, Error, TEXT("[RorkPlayerCharacter] RorkNativeBridgeComponent not found."));
    }
}

void ARorkPlayerCharacter::CacheBridgeAndScoreManager()
{
    if (RorkBridge == nullptr)
    {
        RorkBridge = FindComponentByClass<URorkNativeBridgeComponent>();
    }

    if (PlayerScoreManager == nullptr)
    {
        PlayerScoreManager = APlayerScoreManager::Get(this);
    }
}
