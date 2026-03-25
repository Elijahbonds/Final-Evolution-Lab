using UnityEngine;

public class EvolutionShardManager : MonoBehaviour
{
    private int totalShards = 0;

    /// <summary>
    /// Called when the player successfully performs a biomechanically correct skill rep.
    /// Rewards them with a variable amount of shards depending on form quality.
    /// </summary>
    public void AwardShards(int amount)
    {
        totalShards += amount;
        Debug.Log($"[EvolutionShard] Awarded {amount} shards. Total: {totalShards}");

        // Call back to Swift app to persist the data to the iOS backend / user profile
        NativeCallProxy.OnRepCompleted(amount);
        NativeCallProxy.UpdateUserXP(amount * 10); // Example conversion: 10 XP per shard
    }

    public void FinishWorkout()
    {
        string summaryJson = $"{{\"total_shards\":{totalShards},\"duration\":600,\"accuracy\":95}}";
        NativeCallProxy.OnWorkoutSummary(summaryJson);
    }
}
