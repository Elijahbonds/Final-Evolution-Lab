using UnityEngine;
using UnityEngine.Video;

[RequireComponent(typeof(VideoPlayer))]
public class JumbotronStreamer : MonoBehaviour
{
    private VideoPlayer _videoPlayer;
    public RenderTexture jumbotronTexture;

    void Awake()
    {
        _videoPlayer = GetComponent<VideoPlayer>();
        _videoPlayer.renderMode = VideoRenderMode.RenderTexture;
        
        if (jumbotronTexture != null)
            _videoPlayer.targetTexture = jumbotronTexture;
    }

    /// <summary>
    /// Opens the Skill Lab livestream HLS. 
    /// Called from Swift via SendMessageToGO("Jumbotron", "PlayHLS", "https://...");
    /// </summary>
    public void PlayHLS(string hlsUrl)
    {
        Debug.Log($"[JumbotronStreamer] Loading live HLS stream onto the 3D Render Texture: {hlsUrl}");
        _videoPlayer.url = hlsUrl;
        _videoPlayer.Play();
    }
}
