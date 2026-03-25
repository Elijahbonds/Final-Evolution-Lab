using UnityEngine;

/// <summary>
/// Wii Sports inspired Golf.
/// </summary>
public class GolfMode : MonoBehaviour, IPlayableMode
{
    private Transform _clubTransform;
    private Rigidbody _golfBall;
    
    public void StartMode() { Debug.Log("[Golf] Tee off!"); }
    public void EndMode() { Debug.Log("[Golf] Hole in 1!"); }

    public void OnMove(Vector2 direction)
    {
        // Aiming the shot
        if (direction.magnitude > 0.1f)
            Debug.Log($"[Golf] Aiming club angle: {direction.x * 5f}");
    }

    public void OnCrossDown() { Debug.Log("[Golf] Change Club"); }
    public void OnCrossUp() {}

    public void OnSquareDown() { Debug.Log("[Golf] Charging Power..."); }
    public void OnSquareUp(float chargeTime, float prqChance) 
    {
        float power = Mathf.Lerp(10f, 250f, chargeTime);
        float accuracy = (prqChance > 90f) ? 1.0f : 0.7f; // Perfect swing
        Debug.Log($"[Golf] Swung club with {power} force, {accuracy * 100f}% accuracy.");
        
        if (_golfBall != null) 
            _golfBall.AddForce(Vector3.forward * power * accuracy, ForceMode.Impulse);
        
        GameModeManager.Instance.AddScore(1, 0); // E.g., points for close to pin
    }

    public void OnTriangleDown() {}
    public void OnTriangleUp() {}

    public void OnCircleDown() { Debug.Log("[Golf] Check Wind / Course Map"); }
    public void OnCircleUp() {}
}
