using UnityEngine;

/// <summary>
/// Rhythm/timing matching (like a QTE or rhythm game).
/// Precision scaling based on Neural Drive.
/// </summary>
public class GymnasticsMode : MonoBehaviour, IPlayableMode
{
    public void StartMode() { Debug.Log("[Gymnastics] Routine started."); }
    public void EndMode() { Debug.Log("[Gymnastics] Routine complete."); }

    public void OnMove(Vector2 direction)
    {
        if (direction.magnitude > 0.1f)
            Debug.Log($"[Gymnastics] Balancing / Vault approach: {direction.y}");
    }

    public void OnCrossDown() { Debug.Log("[Gymnastics] Tumbling Jump!"); }
    public void OnCrossUp() {}

    public void OnSquareDown() { Debug.Log("[Gymnastics] Holding Handstand / Iron Cross..."); }
    public void OnSquareUp(float chargeTime, float prqChance) 
    {
        // 85+ PRQ is a perfect execution
        if (prqChance > 85f) {
            Debug.Log($"[Gymnastics] FLAWLESS DISMOUNT! Score: 10.0 (Charge {chargeTime})");
            GameModeManager.Instance.AddScore(10, 0); 
        } else if (prqChance > 40f) {
            Debug.Log($"[Gymnastics] Good execution. Score: 7.5 (Charge {chargeTime})");
            GameModeManager.Instance.AddScore(7, 0);
        } else {
            Debug.Log($"[Gymnastics] Stumbled on landing! Score: 4.0 (Charge {chargeTime})");
            GameModeManager.Instance.AddScore(4, 0);
        }
    }

    public void OnTriangleDown() { Debug.Log("[Gymnastics] Flourish / Style point"); }
    public void OnTriangleUp() {}

    public void OnCircleDown() { Debug.Log("[Gymnastics] Aerial Flip"); }
    public void OnCircleUp() {}
}
