#if UNITY_EDITOR
// Automates the tedious Canvas + RawImage + VideoPlayer wiring for Film Vault.
// Unity: menu **FEL → Setup Film Vault Host (Canvas + Video)** — no manual Hub clicking required.
// Copy this `Editor` folder under your Unity project `Assets/` (e.g. `Assets/FEL/Editor/`).

using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Video;

public static class FELFilmVaultHostSetup
{
    private const string MenuPath = "FEL/Setup Film Vault Host (Canvas + Video)";

    [MenuItem(MenuPath)]
    public static void SetupFilmVaultHost()
    {
        var root = Object.FindObjectOfType<FELBridge>(true)?.gameObject;
        if (root == null)
        {
            root = new GameObject("FELBridge");
            root.AddComponent<FELBridge>();
        }
        else if (root.GetComponent<FELBridge>() == null)
        {
            root.AddComponent<FELBridge>();
        }

        var canvas = root.GetComponentInChildren<Canvas>(true);
        if (canvas == null)
        {
            var canvasGo = new GameObject("FilmVaultCanvas");
            canvasGo.transform.SetParent(root.transform, false);
            canvas = canvasGo.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = canvasGo.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1920, 1080);
            canvasGo.AddComponent<GraphicRaycaster>();
        }

        var raw = canvas.GetComponentInChildren<RawImage>(true);
        if (raw == null)
        {
            var rawGo = new GameObject("FilmVaultRawImage");
            rawGo.transform.SetParent(canvas.transform, false);
            raw = rawGo.AddComponent<RawImage>();
            var rt = raw.rectTransform;
            rt.anchorMin = Vector2.zero;
            rt.anchorMax = Vector2.one;
            rt.offsetMin = Vector2.zero;
            rt.offsetMax = Vector2.zero;
        }

        var vp = raw.GetComponent<VideoPlayer>();
        if (vp == null)
            vp = raw.gameObject.AddComponent<VideoPlayer>();

        vp.playOnAwake = false;
        vp.renderMode = VideoRenderMode.RenderTexture;

        const int w = 1920;
        const int h = 1080;
        var rtex = new RenderTexture(w, h, 0, RenderTextureFormat.ARGB32);
        rtex.name = "FilmVault_RenderTexture";
        vp.targetTexture = rtex;
        raw.texture = rtex;

        Undo.RegisterCreatedObjectUndo(root, "FEL Film Vault Host");
        EditorUtility.SetDirty(root);
        Selection.activeGameObject = root;
        Debug.Log("[FEL] Film Vault host ready: FELBridge → Canvas → RawImage + VideoPlayer (RenderTexture).");
    }
}
#endif
