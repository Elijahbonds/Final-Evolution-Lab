#if UNITY_EDITOR
using UnityEditor;

/// <summary>Alias for batch / Claw: <c>Unity -executeMethod FELBuildScript.ExportIOS</c></summary>
public static class FELBuildScript
{
    public static void ExportIOS() => FELIOSBuilder.BuildIOS();
}
#endif
