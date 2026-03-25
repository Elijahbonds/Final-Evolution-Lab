using System.Runtime.InteropServices;
using UnityEngine;

/// <summary>
/// Host callbacks: exercise/XP/rep use <see cref="FELNativeBridge"/> (FEL_* symbols in iOS host).
/// Workout summary uses a separate optional export if you add <c>UnityOnWorkoutSummary</c> to the native binary.
/// </summary>
public static class NativeCallProxy
{
#if UNITY_IOS && !UNITY_EDITOR
    [DllImport("__Internal")]
    private static extern void UnityOnWorkoutSummary(string summaryJson);
#else
    private static void UnityOnWorkoutSummary(string summaryJson) =>
        Debug.Log($"[NativeCallProxy] UnityOnWorkoutSummary: {summaryJson}");
#endif

    public static void OnExerciseComplete(string exerciseId, int score)
    {
        var json = $"{{\"id\":\"{exerciseId}\",\"score\":{score}}}";
        FELNativeBridge.NotifyExerciseComplete(json);
    }

    public static void UpdateUserXP(int addedXP) => FELNativeBridge.NotifyUpdateUserXP(addedXP);

    public static void OnRepCompleted(int shards) => FELNativeBridge.NotifyRepCompleted(shards);

    public static void OnWorkoutSummary(string summaryJson) => UnityOnWorkoutSummary(summaryJson);
}
