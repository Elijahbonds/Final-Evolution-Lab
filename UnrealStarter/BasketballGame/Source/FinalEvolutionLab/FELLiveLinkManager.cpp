// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: Live Link Face Integration - Connection Manager Implementation

#include "FELLiveLinkManager.h"
#include "ILiveLinkClient.h"
#include "LiveLinkClient.h"
#include "Engine/Engine.h"
#include "TimerManager.h"
#include "Misc/ConfigCacheIni.h"

DEFINE_LOG_CATEGORY(LogFELLiveLink);

void UFELLiveLinkManager::Initialize(FSubsystemCollectionBase& Collection)
{
    Super::Initialize(Collection);
    
    LoadSettings();
    
    // Get Live Link client
    IModularFeatures& ModularFeatures = IModularFeatures::Get();
    if (ModularFeatures.IsModularFeatureAvailable(ILiveLinkClient::ModularFeatureName))
    {
        LiveLinkClient = &ModularFeatures.GetModularFeature<ILiveLinkClient>(ILiveLinkClient::ModularFeatureName);
        UE_LOG(LogFELLiveLink, Log, TEXT("Live Link client acquired successfully."));
    }
    else
    {
        UE_LOG(LogFELLiveLink, Warning, TEXT("Live Link client not available. Face tracking will use fallback expressions."));
    }
    
    UE_LOG(LogFELLiveLink, Log, TEXT("FEL Live Link Manager initialized. FaceTracking=%s, Smoothing=%.2f"),
        bFaceTrackingEnabled ? TEXT("ON") : TEXT("OFF"), SmoothingAlpha);
}

void UFELLiveLinkManager::Deinitialize()
{
    DisconnectAll();
    StopDeviceDiscovery();
    
    if (UWorld* World = GetWorld())
    {
        World->GetTimerManager().ClearTimer(DiscoveryTimerHandle);
        World->GetTimerManager().ClearTimer(ReconnectTimerHandle);
        World->GetTimerManager().ClearTimer(DataProcessTimerHandle);
    }
    
    LiveLinkClient = nullptr;
    UE_LOG(LogFELLiveLink, Log, TEXT("FEL Live Link Manager deinitialized."));
    
    Super::Deinitialize();
}

void UFELLiveLinkManager::LoadSettings()
{
    // Load settings from DefaultLiveLink.ini
    const FString SectionName = TEXT("/Script/FinalEvolutionLab.FELLiveLinkSettings");
    
    GConfig->GetBool(*SectionName, TEXT("FaceTrackingEnabled"), bFaceTrackingEnabled, GGameIni);
    GConfig->GetFloat(*SectionName, TEXT("DefaultSmoothingAlpha"), SmoothingAlpha, GGameIni);
    GConfig->GetFloat(*SectionName, TEXT("MinConfidenceThreshold"), MinConfidence, GGameIni);
    GConfig->GetInt(*SectionName, TEXT("MaxReconnectAttempts"), MaxReconnectAttempts, GGameIni);
    GConfig->GetFloat(*SectionName, TEXT("ReconnectDelaySeconds"), ReconnectDelay, GGameIni);
}

// --- Device Discovery ---

void UFELLiveLinkManager::StartDeviceDiscovery()
{
    if (bDiscoveryActive) return;
    
    bDiscoveryActive = true;
    SetConnectionState(EFELLiveLinkState::Discovering, TEXT("Scanning for iOS devices..."));
    
    // Check Live Link subjects periodically for new face tracking sources
    if (UWorld* World = GetWorld())
    {
        float DiscoveryInterval = 2.0f;
        GConfig->GetFloat(TEXT("/Script/FinalEvolutionLab.FELLiveLinkSettings"),
            TEXT("DeviceDiscoveryInterval"), DiscoveryInterval, GGameIni);
        
        World->GetTimerManager().SetTimer(DiscoveryTimerHandle, [this]()
        {
            if (!LiveLinkClient) return;
            
            TArray<FLiveLinkSubjectKey> Subjects = LiveLinkClient->GetSubjects(true, true);
            for (const FLiveLinkSubjectKey& SubjectKey : Subjects)
            {
                FName SubjectName = SubjectKey.SubjectName.Name;
                
                // Check if this is a new face tracking subject
                bool bAlreadyDiscovered = false;
                for (const auto& Device : DiscoveredDevices)
                {
                    if (Device.SubjectName == SubjectName.ToString())
                    {
                        bAlreadyDiscovered = true;
                        break;
                    }
                }
                
                if (!bAlreadyDiscovered)
                {
                    FFELLiveLinkDevice NewDevice;
                    NewDevice.DeviceName = SubjectName.ToString();
                    NewDevice.SubjectName = SubjectName.ToString();
                    NewDevice.bIsConnected = false;
                    
                    DiscoveredDevices.Add(NewDevice);
                    OnDeviceDiscovered.Broadcast(NewDevice);
                    
                    UE_LOG(LogFELLiveLink, Log, TEXT("Discovered Live Link Face device: %s"), *NewDevice.DeviceName);
                }
            }
        }, DiscoveryInterval, true);
    }
    
    UE_LOG(LogFELLiveLink, Log, TEXT("Device discovery started."));
}

void UFELLiveLinkManager::StopDeviceDiscovery()
{
    bDiscoveryActive = false;
    if (UWorld* World = GetWorld())
    {
        World->GetTimerManager().ClearTimer(DiscoveryTimerHandle);
    }
    UE_LOG(LogFELLiveLink, Log, TEXT("Device discovery stopped."));
}

TArray<FFELLiveLinkDevice> UFELLiveLinkManager::GetDiscoveredDevices() const
{
    return DiscoveredDevices;
}

// --- Connection Management ---

bool UFELLiveLinkManager::ConnectToDevice(const FFELLiveLinkDevice& Device)
{
    if (!LiveLinkClient)
    {
        SetConnectionState(EFELLiveLinkState::Error, TEXT("Live Link client not available."));
        return false;
    }
    
    SetConnectionState(EFELLiveLinkState::Connecting, FString::Printf(TEXT("Connecting to %s..."), *Device.DeviceName));
    
    // Register the subject as a face tracking source
    FName SubjectName(*Device.SubjectName);
    
    // Check if subject exists in Live Link
    TArray<FLiveLinkSubjectKey> Subjects = LiveLinkClient->GetSubjects(true, true);
    bool bFound = false;
    for (const auto& SubjectKey : Subjects)
    {
        if (SubjectKey.SubjectName.Name == SubjectName)
        {
            bFound = true;
            break;
        }
    }
    
    if (!bFound)
    {
        UE_LOG(LogFELLiveLink, Warning, TEXT("Subject '%s' not found in Live Link. Will wait for connection."), *Device.SubjectName);
    }
    
    // Add to connected devices
    FFELLiveLinkDevice ConnectedDevice = Device;
    ConnectedDevice.bIsConnected = true;
    ConnectedDevice.LastHeartbeat = GetWorld() ? GetWorld()->GetTimeSeconds() : 0.f;
    ConnectedDevices.Add(ConnectedDevice);
    
    // Start processing data
    if (UWorld* World = GetWorld())
    {
        World->GetTimerManager().SetTimer(DataProcessTimerHandle, this,
            &UFELLiveLinkManager::ProcessIncomingFrameData, 1.f / 60.f, true);
    }
    
    SetConnectionState(EFELLiveLinkState::Connected, FString::Printf(TEXT("Connected to %s"), *Device.DeviceName));
    CurrentReconnectAttempt = 0;
    
    UE_LOG(LogFELLiveLink, Log, TEXT("Connected to device: %s"), *Device.DeviceName);
    return true;
}

void UFELLiveLinkManager::DisconnectDevice(const FString& DeviceName)
{
    ConnectedDevices.RemoveAll([&DeviceName](const FFELLiveLinkDevice& D)
    {
        return D.DeviceName == DeviceName;
    });
    
    CachedBlendShapes.Remove(FName(*DeviceName));
    
    if (ConnectedDevices.Num() == 0)
    {
        SetConnectionState(EFELLiveLinkState::Disconnected, TEXT("All devices disconnected."));
        if (UWorld* World = GetWorld())
        {
            World->GetTimerManager().ClearTimer(DataProcessTimerHandle);
        }
    }
    
    UE_LOG(LogFELLiveLink, Log, TEXT("Disconnected device: %s"), *DeviceName);
}

void UFELLiveLinkManager::DisconnectAll()
{
    for (const auto& Device : ConnectedDevices)
    {
        CachedBlendShapes.Remove(FName(*Device.DeviceName));
    }
    ConnectedDevices.Empty();
    
    SetConnectionState(EFELLiveLinkState::Disconnected, TEXT("All devices disconnected."));
    
    if (UWorld* World = GetWorld())
    {
        World->GetTimerManager().ClearTimer(DataProcessTimerHandle);
    }
}

int32 UFELLiveLinkManager::GetActiveConnectionCount() const
{
    return ConnectedDevices.Num();
}

// --- Data Access ---

TMap<FName, float> UFELLiveLinkManager::GetBlendShapeValues(const FName& SubjectName) const
{
    if (const TMap<FName, float>* BlendShapes = CachedBlendShapes.Find(SubjectName))
    {
        return *BlendShapes;
    }
    return TMap<FName, float>();
}

float UFELLiveLinkManager::GetBlendShapeValue(const FName& SubjectName, const FName& BlendShapeName) const
{
    if (const TMap<FName, float>* BlendShapes = CachedBlendShapes.Find(SubjectName))
    {
        if (const float* Value = BlendShapes->Find(BlendShapeName))
        {
            return *Value;
        }
    }
    return 0.f;
}

// --- Configuration ---

void UFELLiveLinkManager::SetSmoothingAlpha(float Alpha)
{
    SmoothingAlpha = FMath::Clamp(Alpha, 0.f, 1.f);
    UE_LOG(LogFELLiveLink, Log, TEXT("Smoothing alpha set to %.2f"), SmoothingAlpha);
}

void UFELLiveLinkManager::SetFaceTrackingEnabled(bool bEnabled)
{
    bFaceTrackingEnabled = bEnabled;
    if (!bEnabled)
    {
        DisconnectAll();
    }
    UE_LOG(LogFELLiveLink, Log, TEXT("Face tracking %s"), bEnabled ? TEXT("enabled") : TEXT("disabled"));
}

// --- Calibration ---

void UFELLiveLinkManager::CaptureNeutralPose(const FName& SubjectName)
{
    if (const TMap<FName, float>* Current = CachedBlendShapes.Find(SubjectName))
    {
        NeutralPoseOffsets.Add(SubjectName, *Current);
        UE_LOG(LogFELLiveLink, Log, TEXT("Captured neutral pose for subject: %s (%d blend shapes)"),
            *SubjectName.ToString(), Current->Num());
    }
    else
    {
        UE_LOG(LogFELLiveLink, Warning, TEXT("No blend shape data available for subject: %s"), *SubjectName.ToString());
    }
}

void UFELLiveLinkManager::ResetCalibration(const FName& SubjectName)
{
    NeutralPoseOffsets.Remove(SubjectName);
    UE_LOG(LogFELLiveLink, Log, TEXT("Calibration reset for subject: %s"), *SubjectName.ToString());
}

// --- Internal ---

void UFELLiveLinkManager::SetConnectionState(EFELLiveLinkState NewState, const FString& Message)
{
    if (ConnectionState != NewState)
    {
        EFELLiveLinkState OldState = ConnectionState;
        ConnectionState = NewState;
        OnStateChanged.Broadcast(NewState, Message);
        UE_LOG(LogFELLiveLink, Log, TEXT("Live Link state: %d -> %d: %s"), (int32)OldState, (int32)NewState, *Message);
    }
}

void UFELLiveLinkManager::ProcessIncomingFrameData()
{
    if (!LiveLinkClient || !bFaceTrackingEnabled) return;
    
    for (auto& Device : ConnectedDevices)
    {
        FName SubjectName(*Device.SubjectName);
        
        // Evaluate subject frame
        FLiveLinkSubjectFrameData FrameData;
        TSubclassOf<ULiveLinkRole> Role = ULiveLinkAnimationRole::StaticClass();
        
        if (LiveLinkClient->EvaluateFrame_AnyThread(FLiveLinkSubjectName(SubjectName), Role, FrameData))
        {
            TMap<FName, float> NewBlendShapes;
            
            // Extract property values from the frame
            const FLiveLinkBaseFrameData& BaseData = *FrameData.FrameData.GetBaseData();
            const TArray<float>& PropertyValues = BaseData.PropertyValues;
            
            // ARKit blend shape names (52 total)
            static const FName ARKitBlendShapes[] = {
                TEXT("EyeBlinkLeft"), TEXT("EyeLookDownLeft"), TEXT("EyeLookInLeft"), TEXT("EyeLookOutLeft"),
                TEXT("EyeLookUpLeft"), TEXT("EyeSquintLeft"), TEXT("EyeWideLeft"),
                TEXT("EyeBlinkRight"), TEXT("EyeLookDownRight"), TEXT("EyeLookInRight"), TEXT("EyeLookOutRight"),
                TEXT("EyeLookUpRight"), TEXT("EyeSquintRight"), TEXT("EyeWideRight"),
                TEXT("JawForward"), TEXT("JawLeft"), TEXT("JawRight"), TEXT("JawOpen"),
                TEXT("MouthClose"), TEXT("MouthFunnel"), TEXT("MouthPucker"),
                TEXT("MouthLeft"), TEXT("MouthRight"),
                TEXT("MouthSmileLeft"), TEXT("MouthSmileRight"),
                TEXT("MouthFrownLeft"), TEXT("MouthFrownRight"),
                TEXT("MouthDimpleLeft"), TEXT("MouthDimpleRight"),
                TEXT("MouthStretchLeft"), TEXT("MouthStretchRight"),
                TEXT("MouthRollLower"), TEXT("MouthRollUpper"),
                TEXT("MouthShrugLower"), TEXT("MouthShrugUpper"),
                TEXT("MouthPressLeft"), TEXT("MouthPressRight"),
                TEXT("MouthLowerDownLeft"), TEXT("MouthLowerDownRight"),
                TEXT("MouthUpperUpLeft"), TEXT("MouthUpperUpRight"),
                TEXT("BrowDownLeft"), TEXT("BrowDownRight"),
                TEXT("BrowInnerUp"), TEXT("BrowOuterUpLeft"), TEXT("BrowOuterUpRight"),
                TEXT("CheekPuff"), TEXT("CheekSquintLeft"), TEXT("CheekSquintRight"),
                TEXT("NoseSneerLeft"), TEXT("NoseSneerRight"),
                TEXT("TongueOut")
            };
            
            const int32 NumBlendShapes = FMath::Min(PropertyValues.Num(), 52);
            
            for (int32 i = 0; i < NumBlendShapes; ++i)
            {
                float Value = PropertyValues[i];
                
                // Apply neutral pose offset if calibrated
                if (const TMap<FName, float>* Offsets = NeutralPoseOffsets.Find(SubjectName))
                {
                    if (const float* Offset = Offsets->Find(ARKitBlendShapes[i]))
                    {
                        Value = FMath::Clamp(Value - *Offset, 0.f, 1.f);
                    }
                }
                
                // Apply smoothing
                if (const TMap<FName, float>* PrevBlendShapes = CachedBlendShapes.Find(SubjectName))
                {
                    if (const float* PrevValue = PrevBlendShapes->Find(ARKitBlendShapes[i]))
                    {
                        Value = FMath::Lerp(*PrevValue, Value, 1.f - SmoothingAlpha);
                    }
                }
                
                NewBlendShapes.Add(ARKitBlendShapes[i], Value);
            }
            
            CachedBlendShapes.Add(SubjectName, NewBlendShapes);
            OnBlendShapesReceived.Broadcast(SubjectName, NewBlendShapes);
            
            // Update heartbeat
            if (UWorld* World = GetWorld())
            {
                Device.LastHeartbeat = World->GetTimeSeconds();
            }
            
            // Set streaming state if not already
            if (ConnectionState != EFELLiveLinkState::Streaming)
            {
                SetConnectionState(EFELLiveLinkState::Streaming, TEXT("Receiving facial animation data."));
            }
        }
    }
}

void UFELLiveLinkManager::AttemptReconnect()
{
    if (CurrentReconnectAttempt >= MaxReconnectAttempts)
    {
        SetConnectionState(EFELLiveLinkState::Error, TEXT("Max reconnect attempts reached."));
        return;
    }
    
    ++CurrentReconnectAttempt;
    UE_LOG(LogFELLiveLink, Log, TEXT("Reconnect attempt %d/%d"), CurrentReconnectAttempt, MaxReconnectAttempts);
    
    // Try to reconnect to previously connected devices
    for (auto& Device : ConnectedDevices)
    {
        Device.bIsConnected = false;
    }
    
    TArray<FFELLiveLinkDevice> DevicesToReconnect = ConnectedDevices;
    ConnectedDevices.Empty();
    
    for (const auto& Device : DevicesToReconnect)
    {
        ConnectToDevice(Device);
    }
}

void UFELLiveLinkManager::OnLiveLinkSubjectAdded(FLiveLinkSubjectKey SubjectKey)
{
    UE_LOG(LogFELLiveLink, Log, TEXT("Live Link subject added: %s"), *SubjectKey.SubjectName.Name.ToString());
}

void UFELLiveLinkManager::OnLiveLinkSubjectRemoved(FLiveLinkSubjectKey SubjectKey)
{
    FString SubjectName = SubjectKey.SubjectName.Name.ToString();
    UE_LOG(LogFELLiveLink, Log, TEXT("Live Link subject removed: %s"), *SubjectName);
    
    // Check if this was a connected device and attempt reconnect
    for (auto& Device : ConnectedDevices)
    {
        if (Device.SubjectName == SubjectName)
        {
            Device.bIsConnected = false;
            SetConnectionState(EFELLiveLinkState::Connecting, FString::Printf(TEXT("Lost connection to %s. Reconnecting..."), *SubjectName));
            
            if (UWorld* World = GetWorld())
            {
                World->GetTimerManager().SetTimer(ReconnectTimerHandle, this,
                    &UFELLiveLinkManager::AttemptReconnect, ReconnectDelay, false);
            }
            break;
        }
    }
}
