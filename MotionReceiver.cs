using System;
using UnityEngine;

public sealed class MotionReceiver : MonoBehaviour
{
    [Header("Jump tuning")]
    [SerializeField] private float baseJumpForce = 10f;
    [SerializeField] private string eliteTrackName = "Elite";

    public float JumpForce { get; private set; }

    public AvatarSkinConfig AvatarSkin { get; private set; }
    public ArcadePhysics Arcade { get; private set; }

    [Serializable]
    public sealed class TrackSyncPayload
    {
        public string selectedTrack;
        public double neuralDriveMultiplier;
        public PerformanceMetrics performanceMetrics;
        public AvatarSkinConfig avatarSkinConfig;
        public ArcadePhysics arcadePhysics;
    }

    [Serializable]
    public sealed class PerformanceMetrics
    {
        public double neuralDrive;
        public double neuralDriveMultiplier;
    }

    [Serializable]
    public sealed class AvatarSkinConfig
    {
        public double heightScale;
        public double weightScale;
        public double limbLength;
        public string skinTone;
        public string outfitStyle;
        public double auraColorR;
        public double auraColorG;
        public double auraColorB;
        public double trailIntensity;
    }

    [Serializable]
    public sealed class ArcadePhysics
    {
        public double hangTimeMultiplier;
        public double explosiveFirstStep;
        public double comboDecayRate;
        public double maxComboMultiplier;
        public double successChanceBase;
        public double criticalHitChance;
        public double neuralBurstMultiplier;
        public double impactIntensity;
        public double perfectGuardWindow;
        public double specialMeterGainRate;
        public double perimeterDefense;
        public double contestBonus;
    }

    private void Awake()
    {
        JumpForce = baseJumpForce;
    }

    // Called from Swift: UnityManager.sendDataToUnity
    public void OnMotionData(string message)
    {
        // Keep for compatibility with existing native motion bridge.
        // Motion payload parsing can be added here when needed.
    }

    // Called from Swift: UnityManager.sendTrackSyncToUnity
    public void OnRorkConfig(string json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return;
        }

        TrackSyncPayload payload;
        try
        {
            payload = JsonUtility.FromJson<TrackSyncPayload>(json);
        }
        catch (Exception ex)
        {
            Debug.LogError($"MotionReceiver failed to parse track payload: {ex.Message}");
            return;
        }

        if (payload == null)
        {
            return;
        }

        AvatarSkin = payload.avatarSkinConfig;
        Arcade = payload.arcadePhysics;

        var isElite = string.Equals(payload.selectedTrack, eliteTrackName, StringComparison.OrdinalIgnoreCase);
        var multiplier = ResolveMultiplier(payload);

        JumpForce = isElite ? baseJumpForce * (float)multiplier : baseJumpForce;
    }

    private static double ResolveMultiplier(TrackSyncPayload payload)
    {
        if (payload.neuralDriveMultiplier > 0)
        {
            return payload.neuralDriveMultiplier;
        }

        if (payload.performanceMetrics != null && payload.performanceMetrics.neuralDriveMultiplier > 0)
        {
            return payload.performanceMetrics.neuralDriveMultiplier;
        }

        if (payload.performanceMetrics != null)
        {
            return 1.0 + Math.Max(0.0, payload.performanceMetrics.neuralDrive) / 100.0;
        }

        return 1.0;
    }
}
