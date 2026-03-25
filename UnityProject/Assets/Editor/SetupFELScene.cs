using UnityEditor;
using UnityEngine;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;
using System.IO;

[InitializeOnLoad]
public class SetupFELScene
{
    static SetupFELScene()
    {
        EditorApplication.update += RunOnce;
    }

    static void RunOnce()
    {
        EditorApplication.update -= RunOnce;
        
        string scenePath = "Assets/Scenes/Main.unity";
        
        // Ensure Scenes folder exists
        if (!Directory.Exists("Assets/Scenes"))
        {
            Directory.CreateDirectory("Assets/Scenes");
        }
        
        // Prevent running multiple times if the scene already exists
        if (File.Exists(scenePath))
        {
            return;
        }

        Debug.Log("[FEL Setup] Initializing main scene and mapping bridge components...");

        Scene newScene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameSetup, NewSceneMode.Single);
        
        // Create MotionReceiver
        GameObject motionObj = new GameObject("MotionReceiver");
        motionObj.AddComponent<MotionReceiver>();
        
        // Create FELBridge
        GameObject bridgeObj = new GameObject("FELBridge");
        bridgeObj.AddComponent<FELBridge>();

        // Save scene
        EditorSceneManager.SaveScene(newScene, scenePath);
        
        // Add to Build Settings
        EditorBuildSettingsScene[] buildScenes = new EditorBuildSettingsScene[1];
        buildScenes[0] = new EditorBuildSettingsScene(scenePath, true);
        EditorBuildSettings.scenes = buildScenes;
        
        Debug.Log("[FEL Setup] Scene successfully created and added to Build Settings.");
    }
}
