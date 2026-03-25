// Skill stream: HLS via VideoPlayer.url, rep counter UI, CoachGhost animator hook.
// UI Toolkit: add UIDocument + UXML separately; this controller uses Unity UI Text for zero extra packages.

using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Video;

[DisallowMultipleComponent]
public class StreamOverlayUIController : MonoBehaviour
{
    [SerializeField] private VideoPlayer streamPlayer;
    [SerializeField] private Text repCounter;
    [SerializeField] private Animator coachGhost;

    private void Awake()
    {
        if (streamPlayer != null)
        {
            streamPlayer.playOnAwake = false;
            streamPlayer.renderMode = VideoRenderMode.RenderTexture;
        }
    }

    /// <summary>HLS or progressive URL (platform HLS support applies).</summary>
    public void SetStreamUrl(string url)
    {
        if (streamPlayer == null) return;
        streamPlayer.url = url;
        streamPlayer.Play();
    }

    /// <summary>Rep count from Swift / pose pipeline via FELBridge messaging.</summary>
    public void SetRepCount(int reps)
    {
        if (repCounter != null)
            repCounter.text = reps.ToString();
    }

    /// <summary>Interpolate CoachGhost from stream metadata (stub).</summary>
    public void ApplyCoachKeyframeSample(float normalizedTime, Vector3[] joints)
    {
        if (coachGhost == null || joints == null) return;
        coachGhost.Play("CoachDemo", 0, normalizedTime);
    }
}
