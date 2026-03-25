using UnityEngine;
using UnityEditor;
using UnityEditor.Callbacks;
#if UNITY_IOS
using UnityEditor.iOS.Xcode;
using System.IO;

public class FELPostProcessBuild
{
    [PostProcessBuild(999)]
    public static void OnPostProcessBuild(BuildTarget target, string path)
    {
        if (target == BuildTarget.iOS)
        {
            string pbxprojPath = PBXProject.GetPBXProjectPath(path);
            PBXProject project = new PBXProject();
            project.ReadFromFile(pbxprojPath);

            string mainTargetGuid = project.GetUnityMainTargetGuid();
            string frameworkTargetGuid = project.GetUnityFrameworkTargetGuid();

            // Set Provisioning and Bundle ID matching Apple Developer account
            // Replace with your actual Team ID & Bundle ID inside Claw if necessary
            project.SetBuildProperty(mainTargetGuid, "PRODUCT_BUNDLE_IDENTIFIER", "com.finalevolution.lab");
            project.SetBuildProperty(mainTargetGuid, "DEVELOPMENT_TEAM", "YOUR_TEAM_ID"); 

            // Add Metal and QuartzCore
            project.AddFrameworkToProject(frameworkTargetGuid, "Metal.framework", false);
            project.AddFrameworkToProject(frameworkTargetGuid, "QuartzCore.framework", false);
            project.AddFrameworkToProject(mainTargetGuid, "Metal.framework", false);
            project.AddFrameworkToProject(mainTargetGuid, "QuartzCore.framework", false);

            // Configure Background Modes (audio) and Camera Usage (skill tracking)
            string plistPath = Path.Combine(path, "Info.plist");
            PlistDocument plist = new PlistDocument();
            plist.ReadFromFile(plistPath);
            PlistElementDict rootDict = plist.root;

            // Camera Usage
            rootDict.SetString("NSCameraUsageDescription", "Final Evolution requires camera access to track biomechanics in real-time.");
            
            // Background Modes for Audio
            PlistElementArray backgroundModes = rootDict.CreateArray("UIBackgroundModes");
            backgroundModes.AddString("audio");

            plist.WriteToFile(plistPath);
            project.WriteToFile(pbxprojPath);

            Debug.Log("[FELPostProcessBuild] Added Metal/QuartzCore, Configured Plist (Camera/Audio), and assigned Bundle Identifier.");
        }
    }
}
#endif
