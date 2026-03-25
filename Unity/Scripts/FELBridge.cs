// Final Evolution Lab — iOS host → Unity (Unity as a Library)
// Swift: UnityManager.sendFilmVaultCommand / sendSkillLabCommand → GameObject name "FELBridge".
// Menu: FEL → Setup Film Vault Host (see ../Editor/FELFilmVaultHostSetup.cs).

using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Video;

public class FELBridge : MonoBehaviour
{
    [Header("Film Vault")]
    [Tooltip("Final URL = clipBaseUrl + clipID + clipUrlSuffix")]
    [SerializeField] private string clipBaseUrl = "https://your-server.com/clips/";

    [SerializeField] private string clipUrlSuffix = ".mp4";

    [Header("Skill Lab")]
    [Tooltip("Optional UI Text for rep count; assign in Inspector or add under Canvas.")]
    [SerializeField] private Text skillLabRepCounter;

    /// <summary>Listens for Film Vault commands from the Swift app (clip id).</summary>
    public void OnFilmVaultMessage(string clipID)
    {
        Debug.Log("Unity Loading Detail Breakdown: " + clipID);

        var vp = GetComponentInChildren<VideoPlayer>(true);
        if (vp == null)
        {
            Debug.LogWarning("[FELBridge] No VideoPlayer in children. Menu: FEL → Setup Film Vault Host.");
            return;
        }

        vp.url = clipBaseUrl + clipID + clipUrlSuffix;
        vp.Play();
    }

    /// <summary>Listens for Skill Lab commands. If message is an integer string, updates rep counter.</summary>
    public void OnSkillLabMessage(string skillID)
    {
        Debug.Log("Unity Starting Skill Session: " + skillID);

        if (int.TryParse(skillID.Trim(), out var reps))
            SetRepCounter(reps);
    }

    private void SetRepCounter(int reps)
    {
        if (skillLabRepCounter != null)
            skillLabRepCounter.text = reps.ToString();
    }
}
