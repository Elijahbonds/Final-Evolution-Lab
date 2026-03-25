using UnityEngine;

/// <summary>
/// Storm x Matrix inspired point sparring.
/// PRQ determines critical burst speed for punches/kicks.
/// </summary>
public class KarateMode : MonoBehaviour, IPlayableMode
{
    private CharacterController _player;
    private float _stamina = 100f;

    void Awake() => _player = GetComponent<CharacterController>();

    public void StartMode() { Debug.Log("[Karate] Round 1... FIGHT!"); }
    public void EndMode() { Debug.Log("[Karate] Match finished."); }

    public void OnMove(Vector2 direction)
    {
        if (direction.magnitude > 0.1f && _player != null)
        {
            Vector3 move = new Vector3(direction.x, 0, direction.y) * 4f * Time.deltaTime;
            _player.Move(move);
        }
    }

    public void OnCrossDown() { Debug.Log("[Karate] Dodge!"); _stamina -= 10f; }
    public void OnCrossUp() {}

    public void OnSquareDown() { Debug.Log("[Karate] Charging Punch..."); }
    public void OnSquareUp(float chargeTime, float prqChance) 
    {
        bool isCritical = prqChance > 80f;
        int dmg = isCritical ? 10 : 5;
        Debug.Log($"[Karate] Punch landed! {(isCritical ? "CRITICAL BURST!" : "")} DMG: {dmg}");
        GameModeManager.Instance.AddScore(dmg, 0); // Gain points for landing strikes
    }

    public void OnTriangleDown() { Debug.Log("[Karate] Heavy Kick!"); _stamina -= 15f; }
    public void OnTriangleUp() {}

    public void OnCircleDown() { Debug.Log("[Karate] Block / Parry Stance"); }
    public void OnCircleUp() { Debug.Log("[Karate] Release Block"); }
}
