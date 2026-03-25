using UnityEngine;

public enum PlayMode
{
    Practice,
    StreetBall,
    HalfCourtShootout,
    TimedBlitz,
    FirstTo21
}

public class BasketballGameMode : MonoBehaviour
{
    public PlayMode currentMode = PlayMode.Practice;
    
    [Header("Game State")]
    private int _scoreHome = 0;
    private int _scoreAway = 0;
    private float _timeRemaining = 60f; // Timed Blitz

    public delegate void ScoreChangedDelegate(int home, int away);
    public event ScoreChangedDelegate OnScoreChanged;

    void Update()
    {
        if (currentMode == PlayMode.TimedBlitz && _timeRemaining > 0)
        {
            _timeRemaining -= Time.deltaTime;
            if (_timeRemaining <= 0)
            {
                EndMatch();
            }
        }
    }

    /// <summary>
    /// Triggered by HoopScoreVolume.cs
    /// </summary>
    public void ScoreBasket(bool isHomeTeam, int points)
    {
        if (currentMode == PlayMode.Practice) return; // Practice disables scoring

        if (isHomeTeam)
        {
            _scoreHome += points;
            Debug.Log($"[GameMode] Home scores {points}! Score: {_scoreHome} - {_scoreAway}");
            // Juice: Flash screen, shake camera, burst particles
        }
        else
        {
            _scoreAway += points;
            Debug.Log($"[GameMode] Away scores {points}! Score: {_scoreHome} - {_scoreAway}");
        }

        OnScoreChanged?.Invoke(_scoreHome, _scoreAway);

        CheckWinCondition();
    }

    private void CheckWinCondition()
    {
        if (currentMode == PlayMode.FirstTo21 && (_scoreHome >= 21 || _scoreAway >= 21))
        {
            EndMatch();
        }
        else if (currentMode == PlayMode.HalfCourtShootout && (_scoreHome >= 11 || _scoreAway >= 11))
        {
            EndMatch();
        }
    }

    private void EndMatch()
    {
        Debug.Log("[GameMode] Match Ended!");
        
        // Export Match Readiness JSON
        string summaryJson = $"{{\"home\":{_scoreHome}, \"away\":{_scoreAway}}}";
        NativeCallProxy.OnWorkoutSummary(summaryJson);
    }
}
