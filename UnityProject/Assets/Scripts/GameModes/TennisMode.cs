using UnityEngine;

/// <summary>
/// Tennis mode comparable to Wii Sports / Virtua Tennis.
/// Square = Forehand, Triangle = Backhand.
/// Timing and position determines spin and court placement.
/// </summary>
public class TennisMode : MonoBehaviour, IPlayableMode
{
    private CharacterController _player;
    private Rigidbody _ball;

    void Awake() => _player = GetComponent<CharacterController>();

    void Start()
    {
        if (_ball == null && FELMeshyStreamingLoader.Instance != null)
        {
            var t = FELMeshyStreamingLoader.Instance.TennisBallTransform;
            if (t != null)
                _ball = t.GetComponent<Rigidbody>();
        }
    }

    public void StartMode() { Debug.Log("[Tennis] Love - All"); }
    public void EndMode() { Debug.Log("[Tennis] Game, Set, Match."); }

    public void OnMove(Vector2 direction)
    {
        if (direction.magnitude > 0.1f && _player != null)
        {
            Vector3 move = new Vector3(direction.x, 0, direction.y) * 5f * Time.deltaTime;
            _player.Move(move);
        }
    }

    public void OnCrossDown() { Debug.Log("[Tennis] Dive / Lunge"); }
    public void OnCrossUp() {}

    public void OnSquareDown() { Debug.Log("[Tennis] Charging Forehand..."); }
    public void OnSquareUp(float chargeTime, float prqChance) 
    {
        if (_ball == null && FELMeshyStreamingLoader.Instance != null)
        {
            var t = FELMeshyStreamingLoader.Instance.TennisBallTransform;
            if (t != null)
                _ball = t.GetComponent<Rigidbody>();
        }

        float curve = (prqChance > 75f) ? 0.8f : 0.2f; // Topspin curve
        Debug.Log($"[Tennis] Topspin Forehand hit with {Mathf.Lerp(10, 50, chargeTime)} power! Curve: {curve}");
        GameModeManager.Instance.AddScore(15, 0); // e.g., won the point
    }

    public void OnTriangleDown() { Debug.Log("[Tennis] Charging Backhand Slice..."); }
    public void OnTriangleUp() { Debug.Log("[Tennis] Backhand Slice Release."); }

    public void OnCircleDown() { Debug.Log("[Tennis] Lob Shot"); }
    public void OnCircleUp() {}
}
