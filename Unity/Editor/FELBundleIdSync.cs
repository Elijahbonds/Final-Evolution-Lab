#if UNITY_EDITOR
using System.Linq;
using System.IO;
using UnityEditor;
using UnityEngine;

/// <summary>
/// Keeps Unity Player iOS bundle id aligned with the Swift host app.
/// Canonical id is stored in this repo at Config/FEL_IOS_BUNDLE_ID.txt (copy beside Unity project or edit constant below).
/// </summary>
public static class FELBundleIdSync
{
    private const string FallbackBundleId = "FinalEvoAPP";

    [MenuItem("FEL/Sync iOS Bundle Identifier with host app")]
    public static void SyncFromRepoConfigOrFallback()
    {
        var id = ReadBundleIdFromConfig() ?? FallbackBundleId;
        PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.iOS, id);
        AssetDatabase.SaveAssets();
        Debug.Log($"[FEL] PlayerSettings iOS applicationIdentifier = {id}");
    }

    private static string ReadBundleIdFromConfig()
    {
        // If you symlink/copy the FEL repo next to the Unity project:
        // ../final-evolution-lab/Config/FEL_IOS_BUNDLE_ID.txt
        var projectRoot = Directory.GetParent(Application.dataPath)!.FullName;
        var candidates = new[]
        {
            Path.Combine(projectRoot, "final-evolution-lab/Config/FEL_IOS_BUNDLE_ID.txt"),
            Path.Combine(projectRoot, "../final-evolution-lab/Config/FEL_IOS_BUNDLE_ID.txt"),
            Path.Combine(projectRoot, "Config/FEL_IOS_BUNDLE_ID.txt")
        };

        foreach (var path in candidates)
        {
            if (!File.Exists(path)) continue;
            var line = File.ReadAllText(path).Trim();
            var first = line.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
            if (!string.IsNullOrEmpty(first))
                return first.Trim();
        }

        return null;
    }
}
#endif
