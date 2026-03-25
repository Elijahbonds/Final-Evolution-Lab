using UnityEngine;

/// <summary>
/// Arcade Volleyball. Bumping, setting, spiking (Jump + Square).
/// </summary>
public class VolleyballMode : MonoBehaviour, IPlayableMode
{
    private CharacterController _player;
    private Rigidbody _ball;
    private float _stamina = 100f;

    void Awake() => _player = GetComponent<CharacterController>();

    public void StartMode() { Debug.Log("[Volleyball] Serve!"); }
    public void EndMode() { Debug.Log("[Volleyball] Match Point."); }

    public void OnMove(Vector2 direction)
    {
        if (direction.magnitude > 0.1f && _player != null)
        {
            Vector3 move = new Vector3(direction.x, 0, direction.y) * 4f * Time.deltaTime;
            _player.Move(move);
        }
    }

    public void OnCrossDown() { Debug.Log("[Volleyball] Jump / Block at Net"); _stamina -= 5f; }
    public void OnCrossUp() {}

    public void OnSquareDown() { Debug.Log("[Volleyball] Charging Spike/Serve..."); }
    public void OnSquareUp(float chargeTime, float prqChance) 
    {
        float power = Mathf.Lerp(10f, 40f, chargeTime);
        float accuracy = (prqChance > 80f) ? 1.0f : 0.5f;
        Debug.Log($"[Volleyball] Spiked the ball! Power: {power}, Accuracy: {accuracy * 100f}%");
        GameModeManager.Instance.AddScore(1, 0); // Scored a point
    }

    public void OnTriangleDown() { Debug.Log("[Volleyball] Set the ball"); }
    public void OnTriangleUp() {}

    public void OnCircleDown() { Debug.Log("[Volleyball] Bump / Dig"); }
    public void OnCircleUp() {}
}
