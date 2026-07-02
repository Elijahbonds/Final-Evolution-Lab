// FELHudRelaySubsystem.h — minimal WebSocket client for /ws/hud overlay relay
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELHudRelaySubsystem.generated.h"

class IWebSocket;

/**
 * Sends HUD overlay frames to the Phase 1 backend relay at /ws/hud.
 * Configure via DefaultGame.ini [FELBackend] HudWebSocketUrl / HudUserId or FEL_HUD_WS_URL env.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELHudRelaySubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	UFUNCTION(BlueprintCallable, Category = "FEL|HUD")
	void BroadcastMessage(const FString& MessageType, const FString& PayloadJson);

	UFUNCTION(BlueprintPure, Category = "FEL|HUD")
	bool IsConnected() const;

private:
	void EnsureConnected();
	void BindHandlers();
	void ScheduleReconnect();
	void AttemptReconnect();
	void FlushPending();
	void SendRawJson(const FString& Json);

	FString CachedWsUrl;
	TSharedPtr<IWebSocket> Socket;
	FTimerHandle ReconnectTimer;
	bool bDeinitializing = false;
	int32 ReconnectAttemptCount = 0;

	static constexpr int32 MaxPendingOutbound = 64;
	TArray<FString> PendingOutboundMessages;

	static constexpr int32 MaxReconnectAttempts = 5;
	static constexpr float ReconnectDelaySeconds = 3.f;
};
