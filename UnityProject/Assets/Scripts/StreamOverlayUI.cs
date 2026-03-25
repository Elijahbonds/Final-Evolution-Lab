using UnityEngine;
using UnityEngine.UIElements;
using UnityEngine.Video;

public class StreamOverlayUI : MonoBehaviour
{
    public UIDocument uiDocument;
    public VideoPlayer streamingPlayer;
    public GameObject coachGhostAvatar;

    private Label _repCountLabel;
    private int _currentRepCount = 0;

    void OnEnable()
    {
        if (uiDocument != null)
        {
            var root = uiDocument.rootVisualElement;
            _repCountLabel = root.Q<Label>("rep-count-label");
        }
    }

    /// <summary>
    /// Loads an HLS stream into the Unity VideoPlayer
    /// </summary>
    public void LoadSkillOnDemandStream(string hlsUrl)
    {
        Debug.Log($"[StreamOverlayUI] Loading HLS stream: {hlsUrl}");
        if (streamingPlayer != null)
        {
            streamingPlayer.url = hlsUrl;
            streamingPlayer.Play();
        }
    }

    /// <summary>
    /// Updates the real-time rep count from the Swift camera tracking
    /// </summary>
    public void UpdateRepCount(int reps)
    {
        _currentRepCount = reps;
        if (_repCountLabel != null)
        {
            _repCountLabel.text = $"Reps: {_currentRepCount}";
        }
        
        Debug.Log($"[StreamOverlayUI] User Reps updated: {_currentRepCount}");
    }

    /// <summary>
    /// Animates a 3D Ghost Avatar to mirror the instructor's keyframes received via stream metadata
    /// </summary>
    public void UpdateCoachGhost(string keyframeJson)
    {
        if (coachGhostAvatar != null)
        {
            // TODO: Parse keyframeJson to position rotations on the Ghost avatar
            Debug.Log($"[StreamOverlayUI] CoachGhost transforming to metadata keyframe: {keyframeJson}");
        }
    }
}
