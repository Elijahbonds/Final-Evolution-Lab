using UnityEngine;
using UnityEngine.Video;
using Unity.Mathematics;
using System.Collections.Generic;

[RequireComponent(typeof(VideoPlayer))]
public class FilmVaultController : MonoBehaviour
{
    private VideoPlayer _videoPlayer;
    public BiomechanicsRenderer leftArmRenderer;
    public EvolutionShardManager shardManager;
    
    [System.Serializable]
    public class SkeletonFrame
    {
        public float time;
        public Vector3 leftShoulder;
        public Vector3 leftElbow;
        public Vector3 leftWrist;
    }
    
    [System.Serializable]
    public class FilmVaultData
    {
        public List<SkeletonFrame> frames;
    }
    
    private FilmVaultData _currentData;

    void Awake()
    {
        _videoPlayer = GetComponent<VideoPlayer>();
        _videoPlayer.renderMode = VideoRenderMode.RenderTexture; // Use Render Texture if needed or overlay
    }

    /// <summary>
    /// Loads an HLS streaming URL into the VideoPlayer and a JSON file containing biomechanical vectors, then syncs them.
    /// </summary>
    public void SyncVideoWithData(string hlsUrl, string jsonPayload)
    {
        Debug.Log($"[FilmVaultController] Connecting to HLS URL: {hlsUrl}");
        
        _currentData = JsonUtility.FromJson<FilmVaultData>(jsonPayload);
        
        _videoPlayer.source = VideoSource.Url;
        _videoPlayer.url = hlsUrl;
        _videoPlayer.Play();
    }

    void Update()
    {
        if (_videoPlayer.isPlaying && _currentData != null && _currentData.frames != null)
        {
            float currentTime = (float)_videoPlayer.time;
            
            SkeletonFrame currentFrame = GetFrameAtTime(currentTime);
            if (currentFrame != null && leftArmRenderer != null)
            {
                RenderBiomechanicalCues(currentFrame);
            }
        }
    }

    private SkeletonFrame GetFrameAtTime(float time)
    {
        // Simple search.
        foreach (var frame in _currentData.frames)
        {
            if (math.abs(frame.time - time) < 0.1f)
            {
                return frame;
            }
        }
        return null;
    }

    private void RenderBiomechanicalCues(SkeletonFrame frame)
    {
        float3 ls = frame.leftShoulder;
        float3 le = frame.leftElbow;
        float3 lw = frame.leftWrist;
        
        float3 upperArmVector = math.normalize(le - ls);
        float3 lowerArmVector = math.normalize(lw - le);
        
        float dot = math.dot(upperArmVector, lowerArmVector);
        float angle = math.degrees(math.acos(dot));
        
        List<float3> armJoints = new List<float3>() { ls, le, lw };
        
        // Pass the joint vector map to the BiomechanicsRenderer and test if angle < 90
        leftArmRenderer.DrawVectors(armJoints, angle, 90f);

        // Feature: Game Mechanics - Call Swift function on successful "Kobe" snap rep
        if (angle < 90f && Random.value > 0.99f && shardManager != null) 
        {
            // Awards shards, which immediately bridges to Swift's NativeCallProxy
            shardManager.AwardShards(10); 
        }
    }
}
