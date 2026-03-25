#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

/// <summary>Adds <see cref="FELMeshyStreamingLoader"/> to the open scene for Meshy GLB runtime import.</summary>
public static class FELMeshyBootstrapMenu
{
    [MenuItem("FEL/Add Meshy Streaming Loader to Scene")]
    public static void AddMeshyLoader()
    {
        if (Object.FindFirstObjectByType<FELMeshyStreamingLoader>() != null)
        {
            EditorUtility.DisplayDialog("FEL", "A FELMeshyStreamingLoader is already in the scene.", "OK");
            return;
        }

        var go = new GameObject("FEL_MeshyStreamingLoader");
        go.AddComponent<FELMeshyStreamingLoader>();
        Selection.activeGameObject = go;
        Undo.RegisterCreatedObjectUndo(go, "Add FEL Meshy Streaming Loader");
        Debug.Log("[FEL] Added FELMeshyStreamingLoader. Ensure GLBs are in Assets/StreamingAssets/Meshy/");
    }
}
#endif
