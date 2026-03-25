// Calls native Swift when a skill rep completes — Evolution Shard payout.

using UnityEngine;

[DisallowMultipleComponent]
public class EvolutionRepRewards : MonoBehaviour
{
    [SerializeField] private int shardsPerRep = 3;

    /// <summary>Invoke from gameplay when the player finishes one clean rep (Skill Lab).</summary>
    public void OnRepCompleted()
    {
        FELNativeBridge.NotifyRepCompleted(shardsPerRep);
    }

    public void OnRepCompletedWithShards(int shards)
    {
        FELNativeBridge.NotifyRepCompleted(shards);
    }
}
