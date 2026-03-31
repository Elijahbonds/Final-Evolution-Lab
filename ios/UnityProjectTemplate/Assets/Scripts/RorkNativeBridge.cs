using System.Runtime.InteropServices;
using TMPro;
using UnityEngine;

public class RorkNativeBridge : MonoBehaviour
{
    // Connects to native iOS symbol exported via Swift @_cdecl("_PostRorkScore").
    [DllImport("__Internal")]
    private static extern void _PostRorkScore(int score);

    [Header("UI References")]
    public TextMeshProUGUI prqScoreDisplay;
    public TextMeshProUGUI unityPRQInternalDisplay;
    public TextMeshProUGUI motionDataDisplay;

    private int _currentUnityPRQ;
    public int CurrentUnityPRQ => _currentUnityPRQ;

    private void Start()
    {
        UpdateUnityPRQDisplay();
        Debug.Log("[RorkNativeBridge] Initialized.");
    }

    public void PostRorkScoreToNative(int score)
    {
        Debug.Log($"[RorkNativeBridge] Sending PRQ score {score} to native iOS.");

#if UNITY_IOS && !UNITY_EDITOR
        _PostRorkScore(score);
#else
        Debug.LogWarning("[RorkNativeBridge] _PostRorkScore called outside iOS build. Simulating native update.");
        OnRorkScoreUpdated(score);
#endif

        _currentUnityPRQ = score;
        UpdateUnityPRQDisplay();
    }

    public void UpdateUnityPRQDisplayPublic()
    {
        UpdateUnityPRQDisplay();
    }

    // Called by native through UnitySendMessage, so this string overload is required.
    public void OnRorkScoreUpdated(string scoreString)
    {
        if (!int.TryParse(scoreString, out int score))
        {
            Debug.LogError($"[RorkNativeBridge] Invalid score payload: {scoreString}");
            return;
        }

        OnRorkScoreUpdated(score);
    }

    // Optional direct int entry point for editor/internal calls.
    public void OnRorkScoreUpdated(int score)
    {
        Debug.Log($"[RorkNativeBridge] Received PRQ score from Native: {score}");
        if (prqScoreDisplay != null)
        {
            prqScoreDisplay.text = $"Native PRQ: {score}";
        }
    }

    private void UpdateUnityPRQDisplay()
    {
        if (unityPRQInternalDisplay == null)
        {
            return;
        }

        int scoreToDisplay = _currentUnityPRQ;
        if (PlayerScoreManager.Instance != null)
        {
            scoreToDisplay = PlayerScoreManager.Instance.GetPlayerScore();
        }

        unityPRQInternalDisplay.text = $"Unity Internal PRQ: {scoreToDisplay}";
    }
}
