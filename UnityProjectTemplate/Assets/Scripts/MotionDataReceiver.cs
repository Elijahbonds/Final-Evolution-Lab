using System;
using TMPro;
using UnityEngine;

[Serializable]
public class MotionPayload
{
    public float ax;
    public float ay;
    public float az;
    public float gx;
    public float gy;
    public float gz;
    public double t;
}

public class MotionDataReceiver : MonoBehaviour
{
    public TextMeshProUGUI motionDataDisplay;

    private void Start()
    {
        Debug.Log("[MotionDataReceiver] Ready.");
    }

    // Called by native iOS via UnitySendMessage("MotionReceiver", "OnMotionData", json).
    public void OnMotionData(string jsonString)
    {
        try
        {
            MotionPayload payload = JsonUtility.FromJson<MotionPayload>(jsonString);
            if (payload == null)
            {
                throw new Exception("Null payload after JSON parse.");
            }

            if (motionDataDisplay != null)
            {
                motionDataDisplay.text =
                    $"Accel: ({payload.ax:F2}, {payload.ay:F2}, {payload.az:F2})\n" +
                    $"Gyro: ({payload.gx:F2}, {payload.gy:F2}, {payload.gz:F2})\n" +
                    $"Time: {payload.t:F0}";
            }
        }
        catch (Exception ex)
        {
            Debug.LogError($"[MotionDataReceiver] Failed to parse JSON. Error: {ex.Message}\n{jsonString}");
            if (motionDataDisplay != null)
            {
                motionDataDisplay.text = "Error parsing motion data.";
            }
        }
    }
}
