using UnityEngine;

/// <summary>
/// Classic button mashing sprinting / hurdles.
/// </summary>
public class TrackAndFieldMode : MonoBehaviour, IPlayableMode
{
    private float sprintSpeed = 0f;
    
    public void StartMode() { Debug.Log("[Track] On your marks. Get set. GO!"); }
    public void EndMode() { Debug.Log("[Track] Crossed the finish line."); }

    public void OnMove(Vector2 direction)
    {
        // Minimal horizontal adjustment for lane control
        if (direction.x > 0.5f) Debug.Log("[Track] Drifting Right Lane");
        if (direction.x < -0.5f) Debug.Log("[Track] Drifting Left Lane");
    }

    public void OnCrossDown() 
    {
        sprintSpeed += 1.5f; 
        Debug.Log($"[Track] Left Step! Speed: {sprintSpeed}"); 
    }
    public void OnCrossUp() {}

    public void OnSquareDown() { Debug.Log("[Track] Power Lean at finish line"); }
    public void OnSquareUp(float chargeTime, float prqChance) 
    {
        Debug.Log($"[Track] Lunged forward: +{chargeTime}s advantage!");
    }

    public void OnTriangleDown() 
    { 
        Debug.Log("[Track] Hurdle Jump!"); 
        // Need good PRQ to clear it flawlessly
    }
    public void OnTriangleUp() {}

    public void OnCircleDown() 
    { 
        sprintSpeed += 1.5f; 
        Debug.Log($"[Track] Right Step! Speed: {sprintSpeed}"); 
    }
    public void OnCircleUp() {}
}
