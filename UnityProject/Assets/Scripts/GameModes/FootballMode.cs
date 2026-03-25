using UnityEngine;

/// <summary>
/// Arcade American Football. Quarterback passing, running back dodging.
/// </summary>
public class FootballMode : MonoBehaviour, IPlayableMode
{
    private CharacterController _player;

    void Awake() => _player = GetComponent<CharacterController>();

    public void StartMode() { Debug.Log("[Football] Hut! Hut! Hike!"); }
    public void EndMode() { Debug.Log("[Football] Touchdown."); }

    public void OnMove(Vector2 direction)
    {
        if (direction.magnitude > 0.1f && _player != null)
        {
            Vector3 move = new Vector3(direction.x, 0, direction.y) * 5.5f * Time.deltaTime;
            _player.Move(move);
        }
    }

    public void OnCrossDown() { Debug.Log("[Football] Spin Move / Stiff Arm"); }
    public void OnCrossUp() {}

    public void OnSquareDown() { Debug.Log("[Football] QB Dropback / Target receiver..."); }
    public void OnSquareUp(float chargeTime, float prqChance) 
    {
        float passStrength = Mathf.Lerp(10f, 40f, chargeTime);
        bool isCaught = prqChance > 60f;
        Debug.Log($"[Football] Pass thrown! Strength: {passStrength}, Caught: {isCaught}");
        if (isCaught) GameModeManager.Instance.AddScore(6, 0); // Touchdown!
    }

    public void OnTriangleDown() { Debug.Log("[Football] Hurdle / Dive"); }
    public void OnTriangleUp() {}

    public void OnCircleDown() { Debug.Log("[Football] Juke / Truck"); }
    public void OnCircleUp() {}
}
