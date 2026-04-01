// Copyright (c) Final Evolution Lab.
// Pixel Streaming data channel bridge — receives JSON commands from the web frontend
// and dispatches to ModeLauncherSubsystem, ExerciseDemo pipeline, etc.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELPixelStreamingBridge.generated.h"

class UFELModeLauncherSubsystem;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnFELStreamingCommand, const FString&, Command, const FString&, Payload);

UCLASS()
class FINALEVOLUTIONLAB_API UFELPixelStreamingBridge : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** Process raw JSON message from Pixel Streaming data channel. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Streaming")
	void HandleDataChannelMessage(const FString& RawJSON);

	/** Send a JSON response back to the connected frontend. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Streaming")
	void SendResponseToFrontend(const FString& ResponseJSON);

	/** Broadcast for Blueprint listeners. */
	UPROPERTY(BlueprintAssignable, Category = "FEL|Streaming")
	FOnFELStreamingCommand OnStreamingCommand;

private:
	void ProcessCommand(const FString& Command, const TSharedPtr<class FJsonObject>& Payload);
	void HandleLaunchMode(const TSharedPtr<class FJsonObject>& Payload);
	void HandleExitMode();
	void HandleGetModes();
	void HandleExerciseDemo(const TSharedPtr<class FJsonObject>& Payload);
	void HandleGetStatus();
};
