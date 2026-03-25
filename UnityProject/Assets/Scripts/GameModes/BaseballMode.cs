using UnityEngine;

/// <summary>
/// Arcade Baseball. Timing determines hit angle and power (PRQ chance).
/// </summary>
public class BaseballMode : MonoBehaviour, IPlayableMode
{
    private Transform _batTransform;
    
    public void StartMode() { Debug.Log("[Baseball] Play Ball!"); }
    public void EndMode() { Debug.Log("[Baseball] Game Over."); }

    public void OnMove(Vector2 direction)
    {
        if (direction.magnitude > 0.1f)
            Debug.Log($"[Baseball] Adjusting stance/aim in batter's box: {direction}");
    }

    public void OnCrossDown() { Debug.Log("[Baseball] Bunt / Steal Base"); }
    public void OnCrossUp() {}

    public void OnSquareDown() { Debug.Log("[Baseball] Power Swing Windup..."); }
    public void OnSquareUp(float chargeTime, float prqChance) 
    {
        // 90+ PRQ is a perfect hit
        if (prqChance > 90f) {
            Debug.Log($"[Baseball] PERFECT TIMING! HOME RUN! (Charge {chargeTime})");
            GameModeManager.Instance.AddScore(4, 0); // Grand Slam
        } else if (prqChance > 50f) {
            Debug.Log($"[Baseball] Solid Contact. Base Hit! (Charge {chargeTime})");
            GameModeManager.Instance.AddScore(1, 0);
        } else {
            Debug.Log($"[Baseball] Swing and a miss! (Charge {chargeTime})");
        }
    }

    public void OnTriangleDown() {}
    public void OnTriangleUp() {}

    public void OnCircleDown() { Debug.Log("[Baseball] Contact Swing"); }
    public void OnCircleUp() {}
}
