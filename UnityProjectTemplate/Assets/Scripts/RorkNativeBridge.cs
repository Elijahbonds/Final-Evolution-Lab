using System.Runtime.InteropServices;
using TMPro;
using UnityEngine;

public class RorkNativeBridge : MonoBehaviour
{
#if UNITY_IOS && !UNITY_EDITOR
    [DllImport("__Internal")]
    private static extern void _PostRorkScore(int score);
#endif

    [Header("UI References")]
    public TextMeshProUGUI prqScoreDisplay;
    public TextMeshProUGUI unityPrqInternalDisplay;

    [SerializeField]
    private int currentUnityPrq;

    private void Start()
    {
        UpdateUnityPrqDisplay();
        Debug.Log("[RorkNativeBridge] Ready.");
    }

    public void PostRorkScoreToNative(int score)
    {
        currentUnityPrq = score;
        UpdateUnityPrqDisplay();

#if UNITY_IOS && !UNITY_EDITOR
        Debug.Log($"[RorkNativeBridge] Sending PRQ {score} to native.");
        _PostRorkScore(score);
#else
        Debug.LogWarning("[RorkNativeBridge] Simulating iOS callback in editor/non-iOS build.");
        OnRorkScoreUpdated(score.ToString());
#endif
    }

    // Must accept string when called via UnitySendMessage.
    public void OnRorkScoreUpdated(string scoreString)
    {
        if (!int.TryParse(scoreString, out int score))
        {
            Debug.LogError($"[RorkNativeBridge] Invalid score payload: {scoreString}");
            return;
        }

        Debug.Log($"[RorkNativeBridge] Native PRQ update received: {score}");

        if (prqScoreDisplay != null)
        {
            prqScoreDisplay.text = $"PRQ: {score}";
        }
    }

    // Public helper used by external scripts (e.g. PlayerScoreManager).
    public void UpdateUnityPRQDisplayPublic()
    {
        if (PlayerScoreManager.Instance != null)
        {
            currentUnityPrq = PlayerScoreManager.Instance.GetPlayerScore();
        }

        UpdateUnityPrqDisplay();
    }

    private void UpdateUnityPrqDisplay()
    {
        if (unityPrqInternalDisplay != null)
        {
            unityPrqInternalDisplay.text = $"Unity Internal PRQ: {currentUnityPrq}";
        }
    }
}
