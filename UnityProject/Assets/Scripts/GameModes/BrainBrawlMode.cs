using UnityEngine;

/// <summary>
/// Cognitive training / Neural scan pre-game.
/// Flashing sequences to memorize and input. PRQ impacts memory/reaction timers.
/// </summary>
public class BrainBrawlMode : MonoBehaviour, IPlayableMode
{
    private int currentSequenceStep = 0;
    
    public void StartMode() { Debug.Log("[Brain Brawl] Cognitive Scan Initiating. Memorize the pattern."); }
    public void EndMode() { Debug.Log("[Brain Brawl] Neural Diagnostics Complete."); }

    public void OnMove(Vector2 direction)
    {
        // Menu navigation or cursor targeting in cognitive test
    }

    public void OnCrossDown() { SubmitPatternStep("Cross"); }
    public void OnCrossUp() {}

    public void OnSquareDown() { SubmitPatternStep("Square"); }
    public void OnSquareUp(float chargeTime, float prqChance) 
    {
        float reactionSpeed = chargeTime * 1000f; // milliseconds
        Debug.Log($"[Brain Brawl] Synaptic Response Time: {reactionSpeed}ms, Scan Clarity: {prqChance}%");
        if (prqChance > 90f) GameModeManager.Instance.AddScore(5, 0); // Cognitive burst
    }

    public void OnTriangleDown() { SubmitPatternStep("Triangle"); }
    public void OnTriangleUp() {}

    public void OnCircleDown() { SubmitPatternStep("Circle"); }
    public void OnCircleUp() {}
    
    private void SubmitPatternStep(string buttonName)
    {
        currentSequenceStep++;
        Debug.Log($"[Brain Brawl] Node {currentSequenceStep} Input Received: {buttonName}");
        // Example: If input matches target pattern, award points
        GameModeManager.Instance.AddScore(1, 0); // Cognitive hit
    }
}
