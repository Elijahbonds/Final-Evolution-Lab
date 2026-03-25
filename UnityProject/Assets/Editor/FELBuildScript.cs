using UnityEditor;
using UnityEngine;

public class FELBuildScript
{
    public static void ExportIOS()
    {
        Debug.Log("[FELBuildScript] Triggering headless iOS Export...");

        string[] scenes = { "Assets/Scenes/Main.unity" }; // Make sure this matches your main scene
        string buildPath = "Builds/iOS";

        BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
        {
            scenes = scenes,
            locationPathName = buildPath,
            target = BuildTarget.iOS,
            options = BuildOptions.None
        };

        // 120 FPS limit requested
        PlayerSettings.iOS.targetDevice = iOSTargetDevice.iPhoneAndiPad;
        PlayerSettings.iOS.appleEnableAutomaticSigning = true;
        PlayerSettings.iOS.applicationRequiresEnvironmentAR = false;
        
        // M4 Optimization and 120 FPS constraint
        Application.targetFrameRate = 120;
        PlayerSettings.gpuSkinning = true;
        PlayerSettings.MTRendering = true;
        PlayerSettings.SetArchitecture(BuildTargetGroup.iOS, 2); // 2 = ARM64
        PlayerSettings.SetGraphicsAPIs(BuildTarget.iOS, new UnityEngine.Rendering.GraphicsDeviceType[] { UnityEngine.Rendering.GraphicsDeviceType.Metal });

        var report = BuildPipeline.BuildPlayer(buildPlayerOptions);
        var summary = report.summary;

        if (summary.result == UnityEditor.Build.Reporting.BuildResult.Succeeded)
        {
            Debug.Log("[FELBuildScript] iOS Export Succeeded: " + summary.totalSize + " bytes");
        }
        else if (summary.result == UnityEditor.Build.Reporting.BuildResult.Failed)
        {
            Debug.LogError("[FELBuildScript] iOS Export Failed.");
            EditorApplication.Exit(1);
        }
    }
}
