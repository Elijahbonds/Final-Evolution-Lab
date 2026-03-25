// Unity → iOS: FELNativeCallProxy.m (host app). Symbols must match Swift/ObjC exports.

using System;
using System.Runtime.InteropServices;
using System.Text;
using UnityEngine;

public static class FELNativeBridge
{
#if UNITY_IOS && !UNITY_EDITOR
    [DllImport("__Internal")]
    private static extern void FEL_OnExerciseComplete(IntPtr jsonUtf8);

    [DllImport("__Internal")]
    private static extern void FEL_UpdateUserXP(int xp);

    [DllImport("__Internal")]
    private static extern void FEL_OnRepCompleted(int shards);

    public static void NotifyExerciseComplete(string json)
    {
        if (string.IsNullOrEmpty(json))
        {
            FEL_OnExerciseComplete(IntPtr.Zero);
            return;
        }

        var bytes = Encoding.UTF8.GetBytes(json);
        var ptr = Marshal.AllocHGlobal(bytes.Length + 1);
        try
        {
            Marshal.Copy(bytes, 0, ptr, bytes.Length);
            Marshal.WriteByte(ptr, bytes.Length, 0);
            FEL_OnExerciseComplete(ptr);
        }
        finally
        {
            Marshal.FreeHGlobal(ptr);
        }
    }

    public static void NotifyUpdateUserXP(int xp) => FEL_UpdateUserXP(xp);

    public static void NotifyRepCompleted(int shards) => FEL_OnRepCompleted(shards);
#else
    public static void NotifyExerciseComplete(string json) =>
        Debug.Log($"[FELNativeBridge] ExerciseComplete (editor stub): {json}");

    public static void NotifyUpdateUserXP(int xp) =>
        Debug.Log($"[FELNativeBridge] UpdateUserXP (editor stub): {xp}");

    public static void NotifyRepCompleted(int shards) =>
        Debug.Log($"[FELNativeBridge] RepCompleted shards (editor stub): {shards}");
#endif
}
