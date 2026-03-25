using UnityEngine;
using UnityEditor;
using UnityEditor.Callbacks;
#if UNITY_IOS
using UnityEditor.iOS.Xcode;
using System.IO;
using System.Linq;

public class PostProcessIOS
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

            // Set Objective-C Exceptions and C++ Standard Library compatibility
            project.SetBuildProperty(frameworkTargetGuid, "GCC_ENABLE_OBJC_EXCEPTIONS", "YES");
            project.SetBuildProperty(mainTargetGuid, "GCC_ENABLE_OBJC_EXCEPTIONS", "YES");

            project.SetBuildProperty(frameworkTargetGuid, "CLANG_CXX_LANGUAGE_STANDARD", "c++17");
            project.SetBuildProperty(frameworkTargetGuid, "CLANG_CXX_LIBRARY", "libc++");

            // Ensure Data folder targets UnityFramework
            string dataFolderPath = Path.Combine(path, "Data");
            if (Directory.Exists(dataFolderPath))
            {
                string dataGuid = project.AddFolderReference(dataFolderPath, "Data", PBXSourceTree.Source);
                project.AddFileToBuild(frameworkTargetGuid, dataGuid);
            }

            // Expose NativeCallProxy.h to UnityFramework headers
            string proxyHeaderPath = "Libraries/Plugins/iOS/NativeCallProxy.h";
            string headerGuid = project.FindFileGuidByProjectPath(proxyHeaderPath);
            if (headerGuid != null)
            {
                // Make it public so Swift can see it
                project.AddPublicHeaderToBuild(frameworkTargetGuid, headerGuid);
            }

            project.WriteToFile(pbxprojPath);

            Debug.Log("[PostProcessBuild] Configured Xcode project for Final Evolution Lab.");
        }
    }
}
#endif
