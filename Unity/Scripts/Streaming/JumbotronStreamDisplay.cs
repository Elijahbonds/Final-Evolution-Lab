// Renders a live/HLS stream onto a 3D quad (jumbotron) via shared RenderTexture.

using UnityEngine;
using UnityEngine.Video;

[DisallowMultipleComponent]
public class JumbotronStreamDisplay : MonoBehaviour
{
    [SerializeField] private VideoPlayer streamPlayer;
    [SerializeField] private MeshRenderer quadRenderer;
    [SerializeField] private int textureWidth = 1920;
    [SerializeField] private int textureHeight = 1080;

    private RenderTexture _rt;

    private void Awake()
    {
        if (streamPlayer == null)
            streamPlayer = GetComponent<VideoPlayer>();
        if (streamPlayer == null) return;

        _rt = new RenderTexture(textureWidth, textureHeight, 0, RenderTextureFormat.ARGB32);
        _rt.name = "Jumbotron_RT";
        streamPlayer.renderMode = VideoRenderMode.RenderTexture;
        streamPlayer.targetTexture = _rt;
        streamPlayer.playOnAwake = false;

        if (quadRenderer != null)
        {
            var mat = quadRenderer.material;
            if (mat != null)
                mat.mainTexture = _rt;
        }
    }

    private void OnDestroy()
    {
        if (_rt != null)
            _rt.Release();
    }

    /// <summary>HLS or progressive URL; platform must support the format.</summary>
    public void PlayStream(string url)
    {
        if (streamPlayer == null) return;
        streamPlayer.url = url;
        streamPlayer.Play();
    }
}
