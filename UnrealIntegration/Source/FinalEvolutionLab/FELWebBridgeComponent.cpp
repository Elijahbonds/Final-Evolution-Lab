// Copyright (c) Final Evolution Lab. All Rights Reserved.

#include "FELWebBridgeComponent.h"
#include "FELOverlaySubsystem.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"
#include "WebBrowser.h"
#include "IWebBrowserWindow.h"
#include "SWebBrowser.h"

UFELWebBridgeComponent::UFELWebBridgeComponent()
{
	PrimaryComponentTick.bCanEverTick = false;
}

void UFELWebBridgeComponent::BeginPlay()
{
	Super::BeginPlay();

	if (UWorld* World = GetWorld())
	{
		if (UGameInstance* GI = World->GetGameInstance())
		{
			if (UFELOverlaySubsystem* OverlaySubsystem = GI->GetSubsystem<UFELOverlaySubsystem>())
			{
				OverlaySubsystem->OnOverlayMessageReceived.AddDynamic(this, &UFELWebBridgeComponent::HandleOverlayMessage);
			}
		}
	}
}

void UFELWebBridgeComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (UWorld* World = GetWorld())
	{
		if (UGameInstance* GI = World->GetGameInstance())
		{
			if (UFELOverlaySubsystem* OverlaySubsystem = GI->GetSubsystem<UFELOverlaySubsystem>())
			{
				OverlaySubsystem->OnOverlayMessageReceived.RemoveDynamic(this, &UFELWebBridgeComponent::HandleOverlayMessage);
			}
		}
	}

	Super::EndPlay(EndPlayReason);
}

void UFELWebBridgeComponent::sendTokenToUnreal(const FString& jsonPayload)
{
	TSharedPtr<FJsonObject> JsonObject;
	TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(jsonPayload);
	if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
	{
		FFELWebBridgeTokenPayload Payload;
		Payload.RawJson = jsonPayload;

		// 1. CreatorCardIds: handle camelCase or snake_case
		const TArray<TSharedPtr<FJsonValue>>* CreatorCardsArray = nullptr;
		if (JsonObject->TryGetArrayField(TEXT("creator_card_ids"), CreatorCardsArray) ||
			JsonObject->TryGetArrayField(TEXT("creatorCardIds"), CreatorCardsArray))
		{
			if (CreatorCardsArray)
			{
				for (const auto& Val : *CreatorCardsArray)
				{
					if (Val.IsValid())
					{
						Payload.CreatorCardIds.Add(Val->AsString());
					}
				}
			}
		}

		// 2. VerticalDisplacement: handle camelCase or snake_case
		double Disp = 0.0;
		if (JsonObject->TryGetNumberField(TEXT("vertical_displacement"), Disp) ||
			JsonObject->TryGetNumberField(TEXT("verticalDisplacement"), Disp))
		{
			Payload.VerticalDisplacement = static_cast<float>(Disp);
		}

		// 3. MovementCues: handle camelCase or snake_case
		const TArray<TSharedPtr<FJsonValue>>* MovementCuesArray = nullptr;
		if (JsonObject->TryGetArrayField(TEXT("movement_cues"), MovementCuesArray) ||
			JsonObject->TryGetArrayField(TEXT("movementCues"), MovementCuesArray))
		{
			if (MovementCuesArray)
			{
				for (const auto& Val : *MovementCuesArray)
				{
					if (Val.IsValid())
					{
						Payload.MovementCues.Add(Val->AsString());
					}
				}
			}
		}

		OnTokenReceived.Broadcast(Payload);
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("[FELWebBridge] Failed to deserialize jsonPayload in sendTokenToUnreal: %s"), *jsonPayload);
	}
}

void UFELWebBridgeComponent::BindToWebBrowserWidget(UWebBrowser* WebBrowserWidget)
{
	if (WebBrowserWidget)
	{
		BoundWebBrowserWidget = WebBrowserWidget;
		TSharedPtr<SWidget> SlateWidget = WebBrowserWidget->GetCachedWidget();
		if (SlateWidget.IsValid())
		{
			TSharedPtr<SWebBrowser> SlateBrowser = StaticCastSharedPtr<SWebBrowser>(SlateWidget);
			if (SlateBrowser.IsValid())
			{
				SlateBrowser->BindUObject(TEXT("felbridge"), this, true);
			}
		}
	}
}

void UFELWebBridgeComponent::HandleOverlayMessage(FString Payload)
{
	TSharedPtr<FJsonObject> Root;
	TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Payload);
	if (FJsonSerializer::Deserialize(Reader, Root) && Root.IsValid())
	{
		FString Action;
		if (Root->TryGetStringField(TEXT("action"), Action) && Action.Equals(TEXT("sendTokenToUnreal"), ESearchCase::IgnoreCase))
		{
			TSharedPtr<FJsonValue> PayloadValue = Root->TryGetField(TEXT("payload"));
			if (PayloadValue.IsValid())
			{
				if (PayloadValue->Type == EJson::String)
				{
					sendTokenToUnreal(PayloadValue->AsString());
				}
				else if (PayloadValue->Type == EJson::Object)
				{
					FString SerializedPayload;
					TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&SerializedPayload);
					FJsonSerializer::Serialize(PayloadValue->AsObject().ToSharedRef(), Writer);
					sendTokenToUnreal(SerializedPayload);
				}
			}
		}
	}
}
