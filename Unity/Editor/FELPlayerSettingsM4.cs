#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// M4 Pro / Apple Silicon friendly defaults: Metal-only on iOS, GPU skinning, multithreaded rendering when available.
/// </summary>
public static class FELPlayerSettingsM4
{
    private const string MenuPath = "FEL/Apply M4-optimized Player Settings (Metal / MT / skinning)";

    [MenuItem(MenuPath)]
    public static void Apply()
    {
        PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.iOS, false);
        PlayerSettings.SetGraphicsAPIs(BuildTarget.iOS, new[] { GraphicsDeviceType.Metal });

#if UNITY_2022_1_OR_NEWER
        PlayerSettings.SetMobileMTRendering(BuildTargetGroup.iOS, true);
#endif

        // GPU skinning: project-wide quality tiers — set first tier as example
        QualitySettings.skinWeights = SkinWeights.FourBones;

        AssetDatabase.SaveAssets();
        Debug.Log("[FEL] Player settings: Metal, MT rendering (iOS), 4-bone skin weights. Review Quality tiers for your content.");
    }
}
#endif
