// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: Live Link Face Integration - Connection Manager

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "LiveLinkTypes.h"
#include "ILiveLinkClient.h"
#include "Roles/LiveLinkAnimationRole.h"
#include "FELLiveLinkManager.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogFELLiveLink, Log, All);

/**
 * Discovered iOS device info for Live Link Face connections.
 */
USTRUCT(BlueprintType)
struct FFELLiveLinkDevice
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category = "FEL|LiveLink")
    FString DeviceName;

    UPROPERTY(BlueprintReadOnly, Category = "FEL|LiveLink")
    FString DeviceIP;

    UPROPERTY(BlueprintReadOnly, Category = "FEL|LiveLink")
    int32 Port = 11111;

    UPROPERTY(BlueprintReadOnly, Category = "FEL|LiveLink")
    FString SubjectName;

    UPROPERTY(BlueprintReadOnly, Category = "FEL|LiveLink")
    bool bIsConnected = false;

    UPROPERTY(BlueprintReadOnly, Category = "FEL|LiveLink")
    float LastHeartbeat = 0.f;
};

/**
 * Live Link connection state.
 */
UENUM(BlueprintType)
enum class EFELLiveLinkState : uint8
{
    Disconnected    UMETA(DisplayName = "Disconnected"),
    Discovering     UMETA(DisplayName = "Discovering Devices"),
    Connecting      UMETA(DisplayName = "Connecting"),
    Connected       UMETA(DisplayName = "Connected"),
    Streaming       UMETA(DisplayName = "Streaming Data"),
    Error           UMETA(DisplayName = "Error")
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnLiveLinkStateChanged, EFELLiveLinkState, NewState, const FString&, Message);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnLiveLinkDeviceDiscovered, const FFELLiveLinkDevice&, Device);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnLiveLinkBlendShapesReceived, const FName&, SubjectName, const TMap<FName, float>&, BlendShapes);

/**
 * UFELLiveLinkManager
 * 
 * Manages Live Link Face connections to iOS devices running the FEL Face Capture app.
 * Handles device discovery, connection management, facial animation data routing,
 * and graceful fallback to preset expressions when no device is connected.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELLiveLinkManager : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    // USubsystem interface
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;
    virtual void Deinitialize() override;
    virtual bool ShouldCreateSubsystem(UObject* Outer) const override { return true; }

    // --- Device Discovery ---

    /** Start scanning for iOS devices running Live Link Face app. */
    UFUNCTION(BlueprintCallable, Category = "FEL|LiveLink")
    void StartDeviceDiscovery();

    /** Stop scanning for devices. */
    UFUNCTION(BlueprintCallable, Category = "FEL|LiveLink")
    void StopDeviceDiscovery();

    /** Get all discovered devices. */
    UFUNCTION(BlueprintCallable, Category = "FEL|LiveLink")
    TArray<FFELLiveLinkDevice> GetDiscoveredDevices() const;

    // --- Connection Management ---

    /** Connect to a specific iOS device by name or IP. */
    UFUNCTION(BlueprintCallable, Category = "FEL|LiveLink")
    bool ConnectToDevice(const FFELLiveLinkDevice& Device);

    /** Disconnect from a specific device. */
    UFUNCTION(BlueprintCallable, Category = "FEL|LiveLink")
    void DisconnectDevice(const FString& DeviceName);

    /** Disconnect all connected devices. */
    UFUNCTION(BlueprintCallable, Category = "FEL|LiveLink")
    void DisconnectAll();

    /** Get current connection state. */
    UFUNCTION(BlueprintPure, Category = "FEL|LiveLink")
    EFELLiveLinkState GetConnectionState() const { return ConnectionState; }

    /** Check if any device is actively streaming. */
    UFUNCTION(BlueprintPure, Category = "FEL|LiveLink")
    bool IsStreaming() const { return ConnectionState == EFELLiveLinkState::Streaming; }

    /** Get number of active connections. */
    UFUNCTION(BlueprintPure, Category = "FEL|LiveLink")
    int32 GetActiveConnectionCount() const;

    // --- Data Access ---

    /** Get latest blend shape values for a subject. */
    UFUNCTION(BlueprintCallable, Category = "FEL|LiveLink")
    TMap<FName, float> GetBlendShapeValues(const FName& SubjectName) const;

    /** Get a specific blend shape value. */
    UFUNCTION(BlueprintPure, Category = "FEL|LiveLink")
    float GetBlendShapeValue(const FName& SubjectName, const FName& BlendShapeName) const;

    // --- Configuration ---

    /** Set smoothing alpha for blend shape interpolation (0 = no smoothing, 1 = full). */
    UFUNCTION(BlueprintCallable, Category = "FEL|LiveLink")
    void SetSmoothingAlpha(float Alpha);

    /** Enable/disable face tracking globally. */
    UFUNCTION(BlueprintCallable, Category = "FEL|LiveLink")
    void SetFaceTrackingEnabled(bool bEnabled);

    /** Check if face tracking is enabled. */
    UFUNCTION(BlueprintPure, Category = "FEL|LiveLink")
    bool IsFaceTrackingEnabled() const { return bFaceTrackingEnabled; }

    // --- Calibration ---

    /** Capture neutral face pose for calibration. */
    UFUNCTION(BlueprintCallable, Category = "FEL|LiveLink")
    void CaptureNeutralPose(const FName& SubjectName);

    /** Reset calibration to defaults. */
    UFUNCTION(BlueprintCallable, Category = "FEL|LiveLink")
    void ResetCalibration(const FName& SubjectName);

    // --- Delegates ---

    UPROPERTY(BlueprintAssignable, Category = "FEL|LiveLink")
    FOnLiveLinkStateChanged OnStateChanged;

    UPROPERTY(BlueprintAssignable, Category = "FEL|LiveLink")
    FOnLiveLinkDeviceDiscovered OnDeviceDiscovered;

    UPROPERTY(BlueprintAssignable, Category = "FEL|LiveLink")
    FOnLiveLinkBlendShapesReceived OnBlendShapesReceived;

protected:
    void SetConnectionState(EFELLiveLinkState NewState, const FString& Message = TEXT(""));
    void OnLiveLinkSubjectAdded(FLiveLinkSubjectKey SubjectKey);
    void OnLiveLinkSubjectRemoved(FLiveLinkSubjectKey SubjectKey);
    void ProcessIncomingFrameData();
    void AttemptReconnect();
    void LoadSettings();

private:
    EFELLiveLinkState ConnectionState = EFELLiveLinkState::Disconnected;
    bool bFaceTrackingEnabled = true;
    bool bDiscoveryActive = false;
    float SmoothingAlpha = 0.15f;
    float MinConfidence = 0.6f;
    int32 MaxReconnectAttempts = 5;
    int32 CurrentReconnectAttempt = 0;
    float ReconnectDelay = 3.0f;

    TArray<FFELLiveLinkDevice> DiscoveredDevices;
    TArray<FFELLiveLinkDevice> ConnectedDevices;
    TMap<FName, TMap<FName, float>> CachedBlendShapes;
    TMap<FName, TMap<FName, float>> NeutralPoseOffsets;

    FTimerHandle DiscoveryTimerHandle;
    FTimerHandle ReconnectTimerHandle;
    FTimerHandle DataProcessTimerHandle;

    ILiveLinkClient* LiveLinkClient = nullptr;
};
