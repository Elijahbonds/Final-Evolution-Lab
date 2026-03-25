#if UNITY_EDITOR
using System;
using System.IO;
using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;

/// <summary>
/// iOS Xcode post-process: UnityFramework flags, system frameworks, Info.plist (camera + background audio),
/// optional DEVELOPMENT_TEAM from env <c>FEL_APPLE_TEAM_ID</c>.
/// Provisioning profiles are best managed in Xcode / automatic signing; set team id for CI.
/// </summary>
public static class FELPostProcessBuild
{
    private const int CallbackOrder = 100;

    [PostProcessBuild(CallbackOrder)]
    public static void OnPostProcessBuild(BuildTarget target, string pathToBuiltProject)
    {
        if (target != BuildTarget.iOS) return;

        var projPath = PBXProject.GetPBXProjectPath(pathToBuiltProject);
        var proj = new PBXProject();
        proj.ReadFromFile(projPath);

        var frameworkGuid = proj.GetUnityFrameworkTargetGuid();
        var mainGuid = proj.GetUnityMainTargetGuid();

        proj.SetBuildProperty(frameworkGuid, "GCC_ENABLE_OBJC_EXCEPTIONS", "YES");
        proj.SetBuildProperty(frameworkGuid, "CLANG_CXX_LIBRARY", "libc++");
        proj.SetBuildProperty(frameworkGuid, "CLANG_CXX_LANGUAGE_STANDARD", "gnu++20");

        proj.AddFrameworkToProject(frameworkGuid, "Metal.framework", false);
        proj.AddFrameworkToProject(frameworkGuid, "QuartzCore.framework", false);

        var team = Environment.GetEnvironmentVariable("FEL_APPLE_TEAM_ID");
        if (!string.IsNullOrEmpty(team))
        {
            proj.SetBuildProperty(mainGuid, "DEVELOPMENT_TEAM", team);
            proj.SetBuildProperty(frameworkGuid, "DEVELOPMENT_TEAM", team);
            proj.SetBuildProperty(mainGuid, "CODE_SIGN_STYLE", "Automatic");
        }

        proj.WriteToFile(projPath);

        var plistPath = Path.Combine(pathToBuiltProject, "Info.plist");
        if (!File.Exists(plistPath))
        {
            UnityEngine.Debug.LogWarning("[FEL] Info.plist not found at " + plistPath);
            return;
        }

        var plist = new PlistDocument();
        plist.ReadFromFile(plistPath);
        var root = plist.root;

        root.SetString("NSCameraUsageDescription",
            "Skill Lab uses the camera for form tracking, rep counting, and biomechanical feedback.");

        PlistElementArray bgModes;
        if (root.values.ContainsKey("UIBackgroundModes"))
            bgModes = root["UIBackgroundModes"].AsArray();
        else
            bgModes = root.CreateArray("UIBackgroundModes");

        var hasAudio = false;
        for (var i = 0; i < bgModes.Count; i++)
        {
            if (bgModes[i].AsString() == "audio")
            {
                hasAudio = true;
                break;
            }
        }

        if (!hasAudio)
            bgModes.AddString("audio");

        plist.WriteToFile(plistPath);

        UnityEngine.Debug.Log("[FEL] PostProcessBuild: Metal, QuartzCore, plist (camera + audio BG), team=" +
                              (string.IsNullOrEmpty(team) ? "(unset)" : team));
    }
}
#endif
