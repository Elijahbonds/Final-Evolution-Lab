using System;
using UnityEngine;

public sealed class RorkBridgeReceiver : MonoBehaviour
{
    [Header("Live Tuning Targets")]
    [SerializeField] private Animator targetAnimator;

    [Header("Base Values (Before Neural Drive)")]
    [SerializeField] public float BaseJumpForce = 8f;
    [SerializeField] public float BaseAnimationSpeed = 1f;

    [Header("Runtime Values (After Neural Drive)")]
    public float JumpForce = 8f;
    public float AnimationSpeed = 1f;

    public MotionPayload LatestMotion { get; private set; }

    private void Awake()
    {
        ApplyNeuralDrive(0f);
    }

    public void OnRorkBridgeMessage(string envelopeJson)
    {
        if (string.IsNullOrWhiteSpace(envelopeJson))
        {
            return;
        }

        BridgeEnvelope envelope;
        try
        {
            envelope = JsonUtility.FromJson<BridgeEnvelope>(envelopeJson);
        }
        catch (Exception ex)
        {
            Debug.LogWarning($"RorkBridgeReceiver: invalid envelope JSON. {ex.Message}");
            return;
        }

        if (envelope == null || string.IsNullOrEmpty(envelope.type))
        {
            Debug.LogWarning("RorkBridgeReceiver: missing bridge message type.");
            return;
        }

        switch (envelope.type)
        {
            case "motion":
                OnMotionData(envelope.payload);
                break;
            case "manifest":
                OnUnityManifestData(envelope.payload);
                break;
            default:
                Debug.LogWarning($"RorkBridgeReceiver: unknown message type '{envelope.type}'.");
                break;
        }
    }

    public void OnMotionData(string motionJson)
    {
        if (string.IsNullOrWhiteSpace(motionJson))
        {
            return;
        }

        try
        {
            LatestMotion = JsonUtility.FromJson<MotionPayload>(motionJson);
        }
        catch (Exception ex)
        {
            Debug.LogWarning($"RorkBridgeReceiver: invalid motion JSON. {ex.Message}");
        }
    }

    public void OnUnityManifestData(string manifestJson)
    {
        if (string.IsNullOrWhiteSpace(manifestJson))
        {
            return;
        }

        UnityExportManifest manifest;
        try
        {
            manifest = JsonUtility.FromJson<UnityExportManifest>(manifestJson);
        }
        catch (Exception ex)
        {
            Debug.LogWarning($"RorkBridgeReceiver: invalid manifest JSON. {ex.Message}");
            return;
        }

        if (manifest?.performanceMetrics == null)
        {
            Debug.LogWarning("RorkBridgeReceiver: manifest missing performanceMetrics.");
            return;
        }

        // System Scan neuralDrive is the primary multiplier for movement + animation.
        ApplyNeuralDrive(manifest.performanceMetrics.neuralDrive);
    }

    private void ApplyNeuralDrive(float neuralDrive)
    {
        var normalizedNeuralDrive = Mathf.Clamp01(neuralDrive / 100f);
        var neuralDriveMultiplier = 0.75f + (normalizedNeuralDrive * 1.25f);

        JumpForce = BaseJumpForce * neuralDriveMultiplier;
        AnimationSpeed = BaseAnimationSpeed * neuralDriveMultiplier;

        if (targetAnimator != null)
        {
            targetAnimator.speed = AnimationSpeed;
        }
    }

    [Serializable]
    public sealed class BridgeEnvelope
    {
        public string type;
        public string payload;
    }

    [Serializable]
    public sealed class MotionPayload
    {
        public float ax;
        public float ay;
        public float az;
        public float gx;
        public float gy;
        public float gz;
        public float t;
    }

    // Authoritative schema mirrors FinalEvolutionLab/Services/UnityExportManifest.swift
    [Serializable]
    public sealed class UnityExportManifest
    {
        public string version;
        public string exportDate;
        public AthleteData athlete;
        public MetricsData performanceMetrics;
        public ArcadePhysicsData arcadePhysics;
        public GameModeExport[] gameModes;
        public ComboSystemExport comboSystem;
        public TimeScaleExport timeScaleConfig;
        public DDAExport ddaConfig;
        public AnimationManifest animationManifest;
    }

    [Serializable]
    public sealed class AthleteData
    {
        public string id;
        public string displayName;
        public string athleteTag;
        public string sport;
        public int totalWorkouts;
        public int streakDays;
        public int evolutionShards;
    }

    [Serializable]
    public sealed class MetricsData
    {
        public float prqScore;
        public float neuralDrive;
        public float efficiencyScore;
        public float readinessScore;
        public float verticalPotential;
        public string prqTier;
        public bool neuralBurstActive;
        public string auraLevel;
    }

    [Serializable]
    public sealed class ArcadePhysicsData
    {
        public float hangTimeMultiplier;
        public float explosiveFirstStep;
        public float comboDecayRate;
        public float maxComboMultiplier;
        public float successChanceBase;
        public float criticalHitChance;
        public float neuralBurstMultiplier;
        public float impactIntensity;
        public float perfectGuardWindow;
        public float specialMeterGainRate;
        public float perimeterDefense;
        public float contestBonus;
    }

    [Serializable]
    public sealed class GameModeExport
    {
        public string id;
        public string name;
        public string sport;
        public string environment;
        public string inputScheme;
        public PhysicsConfigExport physicsConfig;
        public MovementConfigExport movementConfig;
    }

    [Serializable]
    public sealed class PhysicsConfigExport
    {
        public float jumpHeight;
        public float moveSpeed;
        public float impactIntensity;
        public float floorShakeAmplitude;
        public float particleTrailDensity;
    }

    [Serializable]
    public sealed class MovementConfigExport
    {
        public float topSpeed;
        public float acceleration;
        public float deceleration;
        public float airControl;
        public float baseJump;
        public float chargedJump;
    }

    [Serializable]
    public sealed class ComboSystemExport
    {
        public int maxChainLength;
        public float chainWindowSeconds;
        public float styleLandingWindowSeconds;
        public float qteApexWindowSeconds;
        public QTEGradeExport[] qteGrades;
        public TrickExport[] dunkTricks;
        public TrickExport[] combatTricks;
    }

    [Serializable]
    public sealed class QTEGradeExport
    {
        public string grade;
        public float multiplier;
        public bool triggersSlowMo;
    }

    [Serializable]
    public sealed class TrickExport
    {
        public string id;
        public string name;
        public string direction;
        public string modifier;
        public int basePoints;
        public float riskFactor;
        public string animationKey;
    }

    [Serializable]
    public sealed class TimeScaleExport
    {
        public float normalScale;
        public float slowMoScale;
        public float finisherScale;
        public float perfectGuardScale;
        public float apexScale;
        public float blendInDuration;
        public float blendOutDuration;
        public float slowMoDuration;
        public float finisherDuration;
        public float stateMachineBlendDuration;
    }

    [Serializable]
    public sealed class DDAExport
    {
        public string difficultyTier;
        public float aiAggressionFloor;
        public float aiAggressionCeiling;
        public int aiPatternComplexity;
        public float aiFeintChance;
        public float counterWindowShrink;
    }

    [Serializable]
    public sealed class AnimationManifest
    {
        public AnimationEntry[] dunkAnimations;
        public AnimationEntry[] combatAnimations;
        public AnimationEntry[] generalAnimations;
    }

    [Serializable]
    public sealed class AnimationEntry
    {
        public string key;
        public string name;
        public string category;
        public float blendDuration;
    }
}
