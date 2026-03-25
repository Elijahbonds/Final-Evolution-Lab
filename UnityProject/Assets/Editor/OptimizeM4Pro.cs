using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public class OptimizeM4Pro
{
    static OptimizeM4Pro()
    {
        // 1. Target Apple Silicon natively (ARM64)
        PlayerSettings.SetArchitecture(BuildTargetGroup.iOS, 2); // 2 = ARM64
        
        // 2. Enable Metal-based GPU skinning
        PlayerSettings.gpuSkinning = true;
        
        // 3. Multi-threaded Rendering
        PlayerSettings.MTRendering = true;
        
        // 4. Force Metal as graphics API for M4 Pro shaders
        PlayerSettings.SetGraphicsAPIs(BuildTarget.iOS, new UnityEngine.Rendering.GraphicsDeviceType[] { UnityEngine.Rendering.GraphicsDeviceType.Metal });

        // 5. Enforce Stable 120 FPS
        QualitySettings.vSyncCount = 0; // Disable VSync to allow targetFrameRate to work on iOS devices
        Application.targetFrameRate = 120;

        Debug.Log("[OptimizeM4Pro] Configured PlayerSettings for M4 Pro (Metal GPU Skinning, Multithreading, 120 FPS).");
    }
}
