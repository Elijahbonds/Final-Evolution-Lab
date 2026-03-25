using UnityEngine;

/// <summary>
/// NBA Live 06 style Dunk contest.
/// Face buttons combined in air determine trick style. PRQ determines landing impact.
/// </summary>
public class DunkContestMode : MonoBehaviour, IPlayableMode
{
    private CharacterController _player;
    private bool inAir = false;

    public void StartMode() { Debug.Log("[Dunk Contest] Approaching the runway..."); }
    public void EndMode() { Debug.Log("[Dunk Contest] Judges locking in scores."); }

    public void OnMove(Vector2 direction)
    {
        if (direction.magnitude > 0.1f)
            Debug.Log($"[Dunk Contest] Sprinting down the court: {direction.y * 10f} m/s");
    }

    public void OnCrossDown() { Debug.Log("[Dunk Contest] Gather / Takeoff"); inAir = true; }
    public void OnCrossUp() {}

    public void OnSquareDown() { if (inAir) Debug.Log("[Dunk Contest] Trick: Windmill..."); }
    public void OnSquareUp(float chargeTime, float prqChance) 
    {
        if (inAir) 
        {
            Debug.Log($"[Dunk Contest] Slamming it home! Windmill execution: {prqChance}%");
            float score = (prqChance > 80f) ? 50f : 35f;
            GameModeManager.Instance.AddScore(Mathf.RoundToInt(score), 0); // 50 point dunk!
            inAir = false; // Landed
        }
    }

    public void OnTriangleDown() { if (inAir) Debug.Log("[Dunk Contest] Trick: Between the legs..."); }
    public void OnTriangleUp() { if (inAir) Debug.Log("[Dunk Contest] Reverse Jam!"); }

    public void OnCircleDown() { if (inAir) Debug.Log("[Dunk Contest] 360 Spin"); }
    public void OnCircleUp() {}
}
