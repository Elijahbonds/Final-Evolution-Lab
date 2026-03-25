// Draws joint-to-joint vectors from synced biomechanics samples (screen-space or world-space).

using UnityEngine;

[DisallowMultipleComponent]
public class BiomechanicsRenderer : MonoBehaviour
{
    [SerializeField] private LineRenderer[] segmentLines;
    [SerializeField] private int maxSegments = 12;

    /// <summary>
    /// Normalized 0..1 joint positions in the video plane; maps to local XY (extend with camera→world as needed).
    /// </summary>
    public void DrawFrame(BiomechanicsFrame frame)
    {
        if (frame?.joints == null || frame.joints.Length < 2 || segmentLines == null)
            return;

        var n = Mathf.Min(maxSegments, segmentLines.Length, frame.joints.Length / 2);
        for (var i = 0; i < n; i++)
        {
            var lr = segmentLines[i];
            if (lr == null) continue;
            var a = i * 2;
            if (a + 1 >= frame.joints.Length) break;

            var p0 = new Vector3(frame.joints[a].x, frame.joints[a].y, 0f);
            var p1 = new Vector3(frame.joints[a + 1].x, frame.joints[a + 1].y, 0f);
            lr.positionCount = 2;
            lr.SetPosition(0, p0);
            lr.SetPosition(1, p1);
            var ang = JointAngleDegrees(p0, p1);
            var c = Color.Lerp(Color.green, Color.red, ang / 180f);
            lr.startColor = c;
            lr.endColor = c;
        }
    }

    public void Clear()
    {
        if (segmentLines == null) return;
        foreach (var lr in segmentLines)
        {
            if (lr == null) continue;
            lr.positionCount = 0;
        }
    }

    private static float JointAngleDegrees(Vector3 a, Vector3 b) => Vector3.Angle(a, b);
}

[System.Serializable]
public class BiomechanicsFrame
{
    public float timeSeconds;
    public Vector2[] joints;
}
