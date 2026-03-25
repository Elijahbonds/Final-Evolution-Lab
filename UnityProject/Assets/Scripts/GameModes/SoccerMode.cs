using UnityEngine;

/// <summary>
/// FIFA / PES style arcade soccer mechanics.
/// </summary>
public class SoccerMode : MonoBehaviour, IPlayableMode
{
    private CharacterController _player;
    private Rigidbody _ball;

    void Awake() => _player = GetComponent<CharacterController>();

    void Start()
    {
        if (_ball == null && FELMeshyStreamingLoader.Instance != null)
            _ball = FELMeshyStreamingLoader.Instance.SoccerBallRigidbody;
    }

    public void StartMode() { Debug.Log("[Soccer] Kickoff!"); }
    public void EndMode() { Debug.Log("[Soccer] Full Time."); }

    public void OnMove(Vector2 direction)
    {
        if (direction.magnitude > 0.1f && _player != null)
        {
            Vector3 move = new Vector3(direction.x, 0, direction.y) * 6f * Time.deltaTime;
            _player.Move(move);
        }
    }

    public void OnCrossDown() { Debug.Log("[Soccer] Tackle / Sprint"); }
    public void OnCrossUp() {}

    public void OnSquareDown() { Debug.Log("[Soccer] Charging Shot on Goal..."); }
    public void OnSquareUp(float chargeTime, float prqChance) 
    {
        if (_ball == null && FELMeshyStreamingLoader.Instance != null)
            _ball = FELMeshyStreamingLoader.Instance.SoccerBallRigidbody;

        float power = Mathf.Lerp(10f, 35f, chargeTime);
        float accuracy = (prqChance > 80f) ? 1.0f : 0.6f;
        Debug.Log($"[Soccer] Shoot! Power: {power}, Accuracy: {accuracy * 100f}%");
        
        if (_ball != null)
            _ball.linearVelocity = transform.forward * power * accuracy;
        
        GameModeManager.Instance.AddScore(1, 0); // GOAL!
    }

    public void OnTriangleDown() { Debug.Log("[Soccer] Through Ball Lob"); }
    public void OnTriangleUp() {}

    public void OnCircleDown() { Debug.Log("[Soccer] Ground Pass"); }
    public void OnCircleUp() {}
}
