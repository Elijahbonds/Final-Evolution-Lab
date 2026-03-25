// Film Vault: HLS or file playback + biomechanics JSON synced to LineRenderers (via BiomechanicsRenderer).

using System;
using System.IO;
using UnityEngine;
using UnityEngine.Video;

[DisallowMultipleComponent]
public class FilmVaultController : MonoBehaviour
{
    [SerializeField] private VideoPlayer videoPlayer;
    [SerializeField] private BiomechanicsRenderer biomechanicsRenderer;
    [SerializeField] private LineRenderer[] vectorLinesFallback;
    [SerializeField] private int maxVectors = 8;

    [Serializable]
    private class VaultFile
    {
        public FrameSample[] frames;
        public string streamingUrl;
    }

    [Serializable]
    private class FrameSample
    {
        public float t;
        public Vector2[] joints;
    }

    private VaultFile _data;

    /// <summary>Load JSON sidecar; optional streamingUrl in JSON switches VideoPlayer to HLS/progressive URL.</summary>
    public void SyncVideoWithData(string jsonPath)
    {
        if (string.IsNullOrEmpty(jsonPath) || !File.Exists(jsonPath))
        {
            Debug.LogWarning($"[FilmVault] Missing JSON: {jsonPath}");
            return;
        }

        var json = File.ReadAllText(jsonPath);
        _data = JsonUtility.FromJson<VaultFile>(json);
        if (_data?.frames == null || _data.frames.Length == 0)
        {
            Debug.LogWarning("[FilmVault] JSON has no frames.");
            return;
        }

        if (videoPlayer == null)
            videoPlayer = GetComponent<VideoPlayer>();

        if (!string.IsNullOrEmpty(_data.streamingUrl))
            SetHlsOrProgressiveUrl(_data.streamingUrl);

        videoPlayer.prepareCompleted += OnPrepared;
        videoPlayer.Prepare();
    }

    /// <summary>Direct HLS (m3u8) or mp4 URL — Unity VideoPlayer on iOS uses AVFoundation where supported.</summary>
    public void SetHlsOrProgressiveUrl(string url)
    {
        if (videoPlayer == null)
            videoPlayer = GetComponent<VideoPlayer>();
        videoPlayer.source = VideoSource.Url;
        videoPlayer.url = url;
    }

    private void OnPrepared(VideoPlayer source)
    {
        source.prepareCompleted -= OnPrepared;
        source.Play();
    }

    private void Update()
    {
        if (_data == null || _data.frames == null || _data.frames.Length == 0 || videoPlayer == null)
            return;

        var t = (float)videoPlayer.time;
        var idx = FindFrameIndex(t);
        if (idx < 0) return;

        var frame = _data.frames[idx];
        var bioFrame = new BiomechanicsFrame
        {
            timeSeconds = t,
            joints = frame.joints
        };

        if (biomechanicsRenderer != null)
            biomechanicsRenderer.DrawFrame(bioFrame);
        else
            DrawVectorsFallback(frame);
    }

    private int FindFrameIndex(float timeSeconds)
    {
        for (var i = 0; i < _data.frames.Length - 1; i++)
        {
            if (timeSeconds >= _data.frames[i].t && timeSeconds < _data.frames[i + 1].t)
                return i;
        }

        return _data.frames.Length - 1;
    }

    private void DrawVectorsFallback(FrameSample frame)
    {
        if (frame.joints == null || vectorLinesFallback == null) return;
        var n = Mathf.Min(maxVectors, vectorLinesFallback.Length);
        for (var i = 0; i < n; i++)
        {
            var lr = vectorLinesFallback[i];
            if (lr == null) continue;
            var a = i * 2;
            if (a + 1 >= frame.joints.Length) break;
            lr.positionCount = 2;
            lr.SetPosition(0, new Vector3(frame.joints[a].x, frame.joints[a].y, 0));
            lr.SetPosition(1, new Vector3(frame.joints[a + 1].x, frame.joints[a + 1].y, 0));
        }
    }
}
