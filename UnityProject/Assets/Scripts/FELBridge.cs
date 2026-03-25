using UnityEngine;

/// <summary>
/// Receives Film Vault and Skill Lab messages from the native iOS Swift app via UnityFramework.sendMessageToGO.
/// Ensure this script is attached to a GameObject named "FELBridge" in the active scene.
/// </summary>
public class FELBridge : MonoBehaviour
{
    // Optionally link to FilmVaultController
    public FilmVaultController filmVaultController;

    private void Start()
    {
        // Ensure the GameObject has the correct name expected by UnityManager.swift
        if (gameObject.name != "FELBridge")
        {
            Debug.LogWarning($"[FELBridge] GameObject is named '{gameObject.name}' instead of 'FELBridge'. Native messages may fail to route.");
        }
    }

    public void OnFilmVaultMessage(string message)
    {
        Debug.Log($"[FELBridge] Received OnFilmVaultMessage: {message}");
    }

    public void OnSkillLabMessage(string message)
    {
        Debug.Log($"[FELBridge] Received OnSkillLabMessage: {message}");
    }

    public void OnClipSelection(string clipId)
    {
        Debug.Log($"[FELBridge] Received OnClipSelection for Clip ID: {clipId}");
        if (filmVaultController != null)
        {
            // Dummy JSON payload to test BiomechanicsRenderer and FilmVault
            string mockJson = $"{{\"frames\":[{{\"time\":0.0,\"leftShoulder\":[0,1,0],\"leftElbow\":[0,0,0],\"leftWrist\":[1,0,0]}}]}}";
            
            // E.g. trigger SyncVideoWithData
            filmVaultController.SyncVideoWithData($"https://stream.yourcdn.com/clips/{clipId}.m3u8", mockJson);
        }
    }
}
