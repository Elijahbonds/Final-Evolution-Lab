using UnityEngine;

/// <summary>
/// Receives motion data from the native iOS Swift app via UnityFramework.sendMessageToGO.
/// Ensure this script is attached to a GameObject named "MotionReceiver" in the active scene.
/// </summary>
public class MotionReceiver : MonoBehaviour
{
    private void Start()
    {
        // Ensure the GameObject has the correct name expected by UnityManager.swift
        if (gameObject.name != "MotionReceiver")
        {
            Debug.LogWarning($"[MotionReceiver] GameObject is named '{gameObject.name}' instead of 'MotionReceiver'. Native messages may fail to route.");
        }
    }

    /// <summary>
    /// Called by UnityManager.swift: sendMessageToGO("MotionReceiver", method: "OnMotionData", message: data)
    /// </summary>
    /// <param name="data">The JSON string or data payload containing CMDeviceMotion/CMAcceleration data</param>
    public void OnMotionData(string data)
    {
        Debug.Log($"[MotionReceiver] Received OnMotionData: {data}");
        
        // TODO: Parse the JSON string into your desired motion data struct and apply it to characters/cameras
        // Example:
        // MotionDataPayload payload = JsonUtility.FromJson<MotionDataPayload>(data);
        // ApplyMotion(payload);
    }
}
