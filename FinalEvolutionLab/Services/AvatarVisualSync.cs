using System.Globalization;
using System.Text.RegularExpressions;
using UnityEngine;

/// <summary>
/// Syncs Unity avatar VFX with PRQ data from the Rork system scan.
/// Attach this to the same GameObject targeted by UnitySendMessage.
/// </summary>
public sealed class AvatarVisualSync : MonoBehaviour
{
    [Header("Visual Targets")]
    [SerializeField] private Renderer auraRenderer;
    [SerializeField] private TrailRenderer trailRenderer;
    [SerializeField] private ParticleSystem gamebreakerVfx;

    [Header("Shader Properties")]
    [SerializeField] private string auraBaseColorProperty = "_BaseColor";
    [SerializeField] private string auraFallbackColorProperty = "_Color";
    [SerializeField] private string auraEmissionColorProperty = "_EmissionColor";
    [SerializeField] private string trailIntensityProperty = "_TrailIntensity";

    [Header("Trail Tuning")]
    [SerializeField] private float minTrailIntensity = 0.2f; // Matches AvatarSkinConfig minimum
    [SerializeField] private float maxTrailIntensity = 0.8f; // 0.2 + (1.0 * 0.6)
    [SerializeField] private float minTrailTime = 0.2f;
    [SerializeField] private float maxTrailTime = 0.8f;
    [SerializeField] private float minTrailWidthMultiplier = 0.8f;
    [SerializeField] private float maxTrailWidthMultiplier = 1.6f;

    private static readonly Regex PrqScoreRegex =
        new Regex("\"prqScore\"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)", RegexOptions.Compiled | RegexOptions.IgnoreCase);

    private static readonly Regex ScoreRegex =
        new Regex("\"score\"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)", RegexOptions.Compiled | RegexOptions.IgnoreCase);

    private float initialTrailStartWidth = 0.1f;
    private float initialTrailEndWidth = 0.05f;

    private void Awake()
    {
        if (auraRenderer == null)
        {
            auraRenderer = GetComponentInChildren<Renderer>();
        }

        if (trailRenderer == null)
        {
            trailRenderer = GetComponentInChildren<TrailRenderer>();
        }

        if (trailRenderer != null)
        {
            initialTrailStartWidth = Mathf.Max(0.0001f, trailRenderer.startWidth);
            initialTrailEndWidth = Mathf.Max(0.0001f, trailRenderer.endWidth);
        }
    }

    /// <summary>
    /// UnitySendMessage listener for a full scan payload.
    /// Supports payloads such as:
    /// - {"prqScore":72.5}
    /// - {"performanceMetrics":{"prqScore":72.5}}
    /// - 72.5
    /// </summary>
    public void OnSystemScanResult(string payload)
    {
        if (!TryExtractPrqScore(payload, out var prqScore))
        {
            Debug.LogWarning($"AvatarVisualSync: unable to parse PRQ from payload: {payload}");
            return;
        }

        ApplyFromPrq(prqScore);
    }

    /// <summary>
    /// UnitySendMessage listener for direct score values.
    /// Example: UnitySendMessage("MotionReceiver", "OnPrqScore", "78.4")
    /// </summary>
    public void OnPrqScore(string scorePayload)
    {
        if (!TryExtractPrqScore(scorePayload, out var prqScore))
        {
            Debug.LogWarning($"AvatarVisualSync: unable to parse PRQ from score payload: {scorePayload}");
            return;
        }

        ApplyFromPrq(prqScore);
    }

    /// <summary>
    /// Compatibility listener for existing MotionReceiver pipelines.
    /// </summary>
    public void OnMotionData(string payload)
    {
        OnSystemScanResult(payload);
    }

    /// <summary>
    /// UnitySendMessage listener the mobile app can call to trigger Gamebreaker VFX.
    /// Example: UnitySendMessage("MotionReceiver", "TriggerGamebreakerVFX", "")
    /// </summary>
    public void TriggerGamebreakerVFX(string _)
    {
        if (gamebreakerVfx == null)
        {
            Debug.LogWarning("AvatarVisualSync: Gamebreaker VFX is not assigned.");
            return;
        }

        gamebreakerVfx.Play(true);
    }

    private void ApplyFromPrq(float prqScore)
    {
        var clampedPrq = Mathf.Clamp(prqScore, 0f, 100f);
        var normalized = clampedPrq / 100f;

        // Mirrors AvatarSkinConfig.fromScan in Swift.
        var auraColor = ResolveAuraColor(clampedPrq);
        var trailIntensity = Mathf.Lerp(minTrailIntensity, maxTrailIntensity, normalized);

        ApplyAuraColor(auraColor, trailIntensity);
        ApplyTrailIntensity(trailIntensity);
    }

    private static Color ResolveAuraColor(float prqScore)
    {
        if (prqScore >= 80f)
        {
            return new Color(0.6f, 0.2f, 1.0f, 1.0f);
        }

        if (prqScore >= 65f)
        {
            return new Color(0.0f, 0.95f, 0.9f, 1.0f);
        }

        if (prqScore >= 50f)
        {
            return new Color(0.0f, 0.83f, 1.0f, 1.0f);
        }

        return new Color(0.2f, 1.0f, 0.4f, 1.0f);
    }

    private void ApplyAuraColor(Color auraColor, float trailIntensity)
    {
        if (auraRenderer == null)
        {
            return;
        }

        var material = auraRenderer.material;
        if (material == null)
        {
            return;
        }

        if (material.HasProperty(auraBaseColorProperty))
        {
            material.SetColor(auraBaseColorProperty, auraColor);
        }
        else if (material.HasProperty(auraFallbackColorProperty))
        {
            material.SetColor(auraFallbackColorProperty, auraColor);
        }

        if (material.HasProperty(auraEmissionColorProperty))
        {
            material.SetColor(auraEmissionColorProperty, auraColor * Mathf.Lerp(0.6f, 2.0f, trailIntensity));
        }
    }

    private void ApplyTrailIntensity(float trailIntensity)
    {
        if (trailRenderer == null)
        {
            return;
        }

        var widthMultiplier = Mathf.Lerp(minTrailWidthMultiplier, maxTrailWidthMultiplier, trailIntensity);
        trailRenderer.startWidth = initialTrailStartWidth * widthMultiplier;
        trailRenderer.endWidth = initialTrailEndWidth * widthMultiplier;
        trailRenderer.time = Mathf.Lerp(minTrailTime, maxTrailTime, trailIntensity);

        var trailMaterial = trailRenderer.material;
        if (trailMaterial != null && trailMaterial.HasProperty(trailIntensityProperty))
        {
            trailMaterial.SetFloat(trailIntensityProperty, trailIntensity);
        }
    }

    private static bool TryExtractPrqScore(string payload, out float prqScore)
    {
        prqScore = 0f;
        if (string.IsNullOrWhiteSpace(payload))
        {
            return false;
        }

        if (float.TryParse(payload, NumberStyles.Float, CultureInfo.InvariantCulture, out prqScore))
        {
            return true;
        }

        var prqMatch = PrqScoreRegex.Match(payload);
        if (prqMatch.Success &&
            float.TryParse(prqMatch.Groups[1].Value, NumberStyles.Float, CultureInfo.InvariantCulture, out prqScore))
        {
            return true;
        }

        var scoreMatch = ScoreRegex.Match(payload);
        if (scoreMatch.Success &&
            float.TryParse(scoreMatch.Groups[1].Value, NumberStyles.Float, CultureInfo.InvariantCulture, out prqScore))
        {
            return true;
        }

        return false;
    }
}
