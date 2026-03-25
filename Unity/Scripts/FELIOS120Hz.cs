// ProMotion / high refresh: request up to 120 FPS on capable devices (actual rate is OS-dependent).
// Shader / URP: prefer URP Lit with GPU instancing; profile on device — M4 benefits from Metal + batching.

using UnityEngine;

[DisallowMultipleComponent]
public class FELIOS120Hz : MonoBehaviour
{
    [SerializeField] private int targetFrameRate = 120;

    private void Awake()
    {
        QualitySettings.vSyncCount = 0;
        Application.targetFrameRate = targetFrameRate;
    }
}
