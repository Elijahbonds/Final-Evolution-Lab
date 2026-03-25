using UnityEngine;
using Unity.Mathematics;
using System.Collections.Generic;

[RequireComponent(typeof(LineRenderer))]
public class BiomechanicsRenderer : MonoBehaviour
{
    private LineRenderer _lineRenderer;
    
    void Awake()
    {
        _lineRenderer = GetComponent<LineRenderer>();
        // Optimize LineRenderer for performance
        _lineRenderer.useWorldSpace = true;
        _lineRenderer.positionCount = 0;
        _lineRenderer.startWidth = 0.05f;
        _lineRenderer.endWidth = 0.05f;
    }
    
    /// <summary>
    /// Renders a series of connected joint positions.
    /// Evaluates if the form (e.g. elbow snap angle) matches the optimal standard.
    /// </summary>
    public void DrawVectors(List<float3> jointPositions, float currentAngle, float optimalAngleThreshold)
    {
        if (jointPositions == null || jointPositions.Count == 0) return;
        
        _lineRenderer.positionCount = jointPositions.Count;
        for(int i = 0; i < jointPositions.Count; i++)
        {
            _lineRenderer.SetPosition(i, jointPositions[i]);
        }
        
        // Form feedback coloring
        Color targetColor = currentAngle <= optimalAngleThreshold ? Color.green : Color.red;
        _lineRenderer.startColor = targetColor;
        _lineRenderer.endColor = targetColor;
    }
}
