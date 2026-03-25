using UnityEngine;
using System.Collections.Generic;

public class GameModeManager : MonoBehaviour
{
    public static GameModeManager Instance;

    public IPlayableMode CurrentMode { get; private set; }

    [Header("Mode State")]
    public int scorePlayer = 0;
    public int scoreOpponent = 0;
    public float matchTimer = 60f;
    public bool isMatchActive = false;

    public EvolutionShardManager shardManager;

    void Awake()
    {
        if (Instance == null) Instance = this;
        else Destroy(gameObject);
    }

    void Update()
    {
        if (isMatchActive && matchTimer > 0f)
        {
            matchTimer -= Time.deltaTime;
            if (matchTimer <= 0f)
            {
                EndMatch();
            }
        }
    }

    public void SetMode(IPlayableMode newMode)
    {
        if (CurrentMode != null) CurrentMode.EndMode();
        CurrentMode = newMode;
        
        scorePlayer = 0;
        scoreOpponent = 0;
        matchTimer = 60f;
        isMatchActive = true;
        
        CurrentMode.StartMode();
        Debug.Log($"[GameModeManager] Switched to new mode: {CurrentMode.GetType().Name}");
    }

    public void AddScore(int playerPoints, int opponentPoints)
    {
        scorePlayer += playerPoints;
        scoreOpponent += opponentPoints;
        Debug.Log($"[GameModeManager] Score: {scorePlayer} - {scoreOpponent}");
        
        if (playerPoints > 0 && shardManager != null)
        {
            shardManager.AwardShards(playerPoints * 5); // Shards per point
        }
    }

    public void EndMatch()
    {
        isMatchActive = false;
        if (CurrentMode != null) CurrentMode.EndMode();

        Debug.Log($"[GameModeManager] Match Over! Final Score: {scorePlayer} - {scoreOpponent}");
        
        string summaryJson = $"{{\"player\":{scorePlayer}, \"opponent\":{scoreOpponent}}}";
        NativeCallProxy.OnWorkoutSummary(summaryJson);
    }
}
