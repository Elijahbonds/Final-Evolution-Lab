// Copyright (c) Final Evolution Lab.

#include "UFELPixelStreamingBridge.h"
#include "UFELModeLauncherSubsystem.h"
#include "UFELExerciseDemoPipelineSubsystem.h"
#include "FELArenaModeDefinitions.h"
#include "FinalEvolutionLab.h"
#include "Dom/JsonObject.h"
#include "Dom/JsonValue.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

void UFELPixelStreamingBridge::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	UE_LOG(LogFinalEvolutionLab, Log, TEXT("PixelStreamingBridge initialized — listening for data channel commands."));
}

void UFELPixelStreamingBridge::Deinitialize()
{
	Super::Deinitialize();
}

void UFELPixelStreamingBridge::HandleDataChannelMessage(const FString& RawJSON)
{
	TSharedPtr<FJsonObject> Parsed;
	TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(RawJSON);
	if (!FJsonSerializer::Deserialize(Reader, Parsed) || !Parsed.IsValid())
	{
		UE_LOG(LogFinalEvolutionLab, Warning, TEXT("PixelStreamingBridge: invalid JSON: %s"), *RawJSON);
		return;
	}

	FString Command;
	if (!Parsed->TryGetStringField(TEXT("command"), Command))
	{
		UE_LOG(LogFinalEvolutionLab, Warning, TEXT("PixelStreamingBridge: missing 'command' field."));
		return;
	}

	UE_LOG(LogFinalEvolutionLab, Log, TEXT("PixelStreamingBridge: command='%s'"), *Command);

	TSharedPtr<FJsonObject> PayloadObj;
	const TSharedPtr<FJsonValue>* PayloadField = Parsed->Values.Find(TEXT("payload"));
	if (PayloadField && (*PayloadField)->Type == EJson::Object)
	{
		PayloadObj = (*PayloadField)->AsObject();
	}

	ProcessCommand(Command, PayloadObj);

	// Broadcast for Blueprint listeners
	FString PayloadStr;
	if (PayloadObj.IsValid())
	{
		TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&PayloadStr);
		FJsonSerializer::Serialize(PayloadObj.ToSharedRef(), Writer);
	}
	OnStreamingCommand.Broadcast(Command, PayloadStr);
}

void UFELPixelStreamingBridge::ProcessCommand(const FString& Command, const TSharedPtr<FJsonObject>& Payload)
{
	if (Command == TEXT("launch_mode"))
		HandleLaunchMode(Payload);
	else if (Command == TEXT("exit_mode"))
		HandleExitMode();
	else if (Command == TEXT("get_modes"))
		HandleGetModes();
	else if (Command == TEXT("exercise_demo"))
		HandleExerciseDemo(Payload);
	else if (Command == TEXT("get_status"))
		HandleGetStatus();
	else
		UE_LOG(LogFinalEvolutionLab, Warning, TEXT("PixelStreamingBridge: unhandled command '%s'"), *Command);
}

void UFELPixelStreamingBridge::HandleLaunchMode(const TSharedPtr<FJsonObject>& Payload)
{
	if (!Payload.IsValid()) return;

	FString ModeKey;
	if (!Payload->TryGetStringField(TEXT("mode_key"), ModeKey)) return;

	if (UFELModeLauncherSubsystem* Launcher = GetGameInstance()->GetSubsystem<UFELModeLauncherSubsystem>())
	{
		const bool bOk = Launcher->LaunchModeByKey(ModeKey);

		TSharedRef<FJsonObject> Resp = MakeShared<FJsonObject>();
		Resp->SetStringField(TEXT("response"), TEXT("launch_mode_result"));
		Resp->SetBoolField(TEXT("success"), bOk);
		Resp->SetStringField(TEXT("mode_key"), ModeKey);

		FString RespStr;
		TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&RespStr);
		FJsonSerializer::Serialize(Resp, Writer);
		SendResponseToFrontend(RespStr);
	}
}

void UFELPixelStreamingBridge::HandleExitMode()
{
	if (UFELModeLauncherSubsystem* Launcher = GetGameInstance()->GetSubsystem<UFELModeLauncherSubsystem>())
	{
		Launcher->ExitCurrentMode();
	}
}

void UFELPixelStreamingBridge::HandleGetModes()
{
	if (UFELModeLauncherSubsystem* Launcher = GetGameInstance()->GetSubsystem<UFELModeLauncherSubsystem>())
	{
		const FString Manifest = Launcher->GetModeManifestJSON();

		TSharedRef<FJsonObject> Resp = MakeShared<FJsonObject>();
		Resp->SetStringField(TEXT("response"), TEXT("modes_manifest"));
		Resp->SetStringField(TEXT("manifest"), Manifest);

		FString RespStr;
		TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&RespStr);
		FJsonSerializer::Serialize(Resp, Writer);
		SendResponseToFrontend(RespStr);
	}
}

void UFELPixelStreamingBridge::HandleExerciseDemo(const TSharedPtr<FJsonObject>& Payload)
{
	if (!Payload.IsValid()) return;

	FString ExerciseId;
	Payload->TryGetStringField(TEXT("exercise_id"), ExerciseId);

	UE_LOG(LogFinalEvolutionLab, Log, TEXT("PixelStreamingBridge: exercise_demo for '%s'"), *ExerciseId);

	// Trigger exercise demo through the pipeline subsystem
	// The ExerciseDemoPipelineSubsystem handles loading and playback
	// Integration point: UFELExerciseDemoPipelineSubsystem::PlayExerciseById(ExerciseId)
}

void UFELPixelStreamingBridge::HandleGetStatus()
{
	TSharedRef<FJsonObject> Resp = MakeShared<FJsonObject>();
	Resp->SetStringField(TEXT("response"), TEXT("status"));
	Resp->SetBoolField(TEXT("connected"), true);
	Resp->SetStringField(TEXT("version"), TEXT("1.0.0"));

	if (UFELModeLauncherSubsystem* Launcher = GetGameInstance()->GetSubsystem<UFELModeLauncherSubsystem>())
	{
		Resp->SetBoolField(TEXT("mode_active"), Launcher->IsModeActive());
		Resp->SetStringField(TEXT("current_mode"), FELArenaModeToIdString(Launcher->GetCurrentMode()));
	}

	FString RespStr;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&RespStr);
	FJsonSerializer::Serialize(Resp, Writer);
	SendResponseToFrontend(RespStr);
}

void UFELPixelStreamingBridge::SendResponseToFrontend(const FString& ResponseJSON)
{
	// In production this would use IPixelStreamingModule::SendResponse or the data channel API.
	// For now, log the response. The Blueprint binding can override for actual streaming.
	UE_LOG(LogFinalEvolutionLab, Log, TEXT("PixelStreamingBridge -> Frontend: %s"), *ResponseJSON);
}
