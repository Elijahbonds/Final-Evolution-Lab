using UnityEngine;

public class PlayerScoreManager : MonoBehaviour
{
    public static PlayerScoreManager Instance { get; private set; }

    [SerializeField]
    private int score;

    private RorkNativeBridge rorkBridge;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }

        Instance = this;
        rorkBridge = FindObjectOfType<RorkNativeBridge>();
    }

    public int GetPlayerScore()
    {
        return score;
    }

    public void UpdatePlayerScore(int newScore)
    {
        score = newScore;
        Debug.Log($"[PlayerScoreManager] Local score updated: {score}");

        if (rorkBridge == null)
        {
            rorkBridge = FindObjectOfType<RorkNativeBridge>();
        }

        if (rorkBridge != null)
        {
            rorkBridge.UpdateUnityPRQDisplayPublic();
        }
    }
}
