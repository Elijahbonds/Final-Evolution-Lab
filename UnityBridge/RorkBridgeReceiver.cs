using System;
using UnityEngine;

[Serializable]
public class RorkManifest
{
    public float prqScore;
    public float neuralDrive;
    public float elasticity;
    public string athleteTier; // Platinum, Gold, etc.
}

public class RorkBridgeReceiver : MonoBehaviour
{
    [SerializeField] private float baseJumpForce = 12.0f;
    [SerializeField] private Animator athleteAnimator;

    private Rigidbody athleteBody;

    private void Awake()
    {
        athleteBody = GetComponent<Rigidbody>();
        if (athleteAnimator == null)
        {
            athleteAnimator = GetComponentInChildren<Animator>();
        }
    }

    // Called from Swift via UnitySendMessage("RorkBridgeReceiver", "SyncAthleteData", jsonManifest)
    public void SyncAthleteData(string jsonManifest)
    {
        if (string.IsNullOrWhiteSpace(jsonManifest))
        {
            Debug.LogWarning("RorkBridgeReceiver received empty athlete manifest.");
            return;
        }

        RorkManifest data = JsonUtility.FromJson<RorkManifest>(jsonManifest);
        if (data == null)
        {
            Debug.LogWarning("RorkBridgeReceiver failed to parse athlete manifest.");
            return;
        }

        // 1) Scale vertical impulse based on Neural Drive.
        if (athleteBody != null)
        {
            float jumpMultiplier = 1.0f + (data.neuralDrive / 100f);
            athleteBody.AddForce(Vector3.up * baseJumpForce * jumpMultiplier, ForceMode.Impulse);
        }

        // 2) Adjust animation speed based on Elasticity.
        if (athleteAnimator != null)
        {
            athleteAnimator.speed = 1.0f + (data.elasticity / 50f);
        }

        // 3) Trigger Golden Era VFX for Platinum Tier.
        if (string.Equals(data.athleteTier, "Platinum", StringComparison.OrdinalIgnoreCase))
        {
            TriggerAuraEffect();
        }
    }

    private void TriggerAuraEffect()
    {
        // TODO: Implement Neon Green / Slate Gray particle aura.
        Debug.Log("RorkBridgeReceiver: Platinum aura trigger.");
    }
}
