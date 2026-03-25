#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

/// <summary>
/// Batch iOS export for CI / scripts. Command line:
/// Unity -batchmode -quit -projectPath ... -executeMethod FELIOSBuilder.BuildIOS
/// Optional env: FEL_IOS_OUT (output folder, default Builds/iOS).
/// </summary>
public static class FELIOSBuilder
{
    private const string DefaultRelativeOut = "Builds/iOS";

    /// <summary>Entry point for -executeMethod (no dialog).</summary>
    public static void BuildIOS()
    {
        var outDir = Environment.GetEnvironmentVariable("FEL_IOS_OUT");
        if (string.IsNullOrEmpty(outDir))
        {
            outDir = Path.Combine(Directory.GetParent(Application.dataPath)!.FullName, DefaultRelativeOut);
        }

        var scenes = EditorBuildSettings.scenes.Where(s => s.enabled).Select(s => s.path).ToArray();
        if (scenes.Length == 0)
        {
            Debug.LogError("[FELIOSBuilder] Add at least one scene in File → Build Settings.");
            if (Application.isBatchMode)
                EditorApplication.Exit(1);
            return;
        }

        if (!Directory.Exists(outDir))
            Directory.CreateDirectory(outDir);

        var opts = new BuildPlayerOptions
        {
            scenes = scenes,
            locationPathName = outDir,
            target = BuildTarget.iOS,
            options = BuildOptions.CompressWithLz4HC
        };

        var report = BuildPipeline.BuildPlayer(opts);
        if (report.summary.result != BuildResult.Succeeded)
        {
            Debug.LogError("[FELIOSBuilder] Build failed: " + report.summary.result);
            if (Application.isBatchMode)
                EditorApplication.Exit(1);
            return;
        }

        Debug.Log("[FELIOSBuilder] Succeeded → " + outDir);
        if (Application.isBatchMode)
            EditorApplication.Exit(0);
    }

    [MenuItem("FEL/Build iOS Player (FEL_IOS_BUILD)")]
    public static void BuildIOSFromMenu() => BuildIOS();
}
#endif
