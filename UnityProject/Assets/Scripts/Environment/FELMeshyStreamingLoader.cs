using System;
using System.IO;
using System.Threading.Tasks;
using GLTFast;
using UnityEngine;

/// <summary>
/// Loads Meshy GLB props/stadium from <see cref="Application.streamingAssetsPath"/>/Meshy at runtime (glTFast).
/// Place the five Meshy exports in StreamingAssets/Meshy (see README there).
/// </summary>
[DefaultExecutionOrder(-100)]
public class FELMeshyStreamingLoader : MonoBehaviour
{
    public static FELMeshyStreamingLoader Instance { get; private set; }

    public const string MeshySubfolder = "Meshy";

    public static class FileNames
    {
        public const string StadiumSoccer = "Meshy_AI_Stadium_Soccer_stad_0323202143_stylize.glb";
        public const string SoccerBall = "Meshy_AI_Soccer_Ball_FIFA_st_0323202119_texture.glb";
        public const string GoalPosts = "Meshy_AI_Goal_Posts_Professi_0323202113_texture.glb";
        public const string TennisRacket = "Meshy_AI_Tennis_Racket_Profe_0323202215_texture.glb";
        public const string TennisBall = "Meshy_AI_Tennis_Ball_Bright__0323202210_texture.glb";
    }

    [Header("Optional parents (auto-created under this loader)")]
    public Transform soccerEnvironmentRoot;
    public Transform tennisEnvironmentRoot;

    [Header("Placement")]
    public float stadiumScale = 1f;
    public float propScale = 1f;
    public Vector3 stadiumLocalPosition = new Vector3(0f, 0f, 0f);
    public Vector3 goalsLocalPosition = new Vector3(0f, 0f, 25f);
    public Vector3 soccerBallLocalPosition = new Vector3(0f, 0.2f, 10f);
    public Vector3 tennisRacketLocalPosition = new Vector3(0.5f, 1.2f, 0f);
    public Vector3 tennisBallLocalPosition = new Vector3(0f, 1f, 2f);

    /// <summary>Physics-ready ball for <see cref="SoccerMode"/> (may be null until load completes).</summary>
    public Rigidbody SoccerBallRigidbody { get; private set; }

    public Transform TennisRacketTransform { get; private set; }
    public Transform TennisBallTransform { get; private set; }

    async void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }

        Instance = this;
        EnsureRoots();
        await LoadAllAsync();
    }

    private void EnsureRoots()
    {
        if (soccerEnvironmentRoot == null)
        {
            var go = new GameObject("SoccerEnvironment");
            go.transform.SetParent(transform, false);
            soccerEnvironmentRoot = go.transform;
        }

        if (tennisEnvironmentRoot == null)
        {
            var go = new GameObject("TennisEnvironment");
            go.transform.SetParent(transform, false);
            tennisEnvironmentRoot = go.transform;
        }
    }

    private async Task LoadAllAsync()
    {
        await LoadGltf(FileNames.StadiumSoccer, soccerEnvironmentRoot, stadiumLocalPosition, stadiumScale, physics: false);
        await LoadGltf(FileNames.GoalPosts, soccerEnvironmentRoot, goalsLocalPosition, propScale, physics: false);
        await LoadGltf(FileNames.SoccerBall, soccerEnvironmentRoot, soccerBallLocalPosition, propScale, physics: true);
        await LoadGltf(FileNames.TennisRacket, tennisEnvironmentRoot, tennisRacketLocalPosition, propScale, physics: false);
        await LoadGltf(FileNames.TennisBall, tennisEnvironmentRoot, tennisBallLocalPosition, propScale, physics: true);
    }

    private async Task LoadGltf(string fileName, Transform parent, Vector3 localPosition, float scale, bool physics)
    {
        string folder = Path.Combine(Application.streamingAssetsPath, MeshySubfolder);
        string path = Path.Combine(folder, fileName);
        if (!File.Exists(path))
        {
            Debug.LogWarning($"[FELMeshy] Missing GLB — copy into Assets/StreamingAssets/{MeshySubfolder}/ : {fileName}");
            return;
        }

        string loadPath = path;
#if UNITY_IOS && !UNITY_EDITOR
        if (!loadPath.StartsWith("file://", StringComparison.Ordinal))
            loadPath = "file://" + loadPath;
#endif

        using var gltf = new GltfImport();
        var success = await gltf.Load(loadPath);
        if (!success)
        {
            Debug.LogError($"[FELMeshy] glTFast failed to load: {fileName}");
            return;
        }

        var root = new GameObject(Path.GetFileNameWithoutExtension(fileName));
        root.transform.SetParent(parent, false);
        root.transform.localPosition = localPosition;
        root.transform.localRotation = Quaternion.identity;
        root.transform.localScale = Vector3.one * scale;

        await gltf.InstantiateMainSceneAsync(root.transform);

        if (physics)
        {
            var rb = root.GetComponentInChildren<Rigidbody>();
            if (rb == null)
            {
                var target = root.GetComponentInChildren<MeshRenderer>()?.transform ?? root.transform;
                rb = target.gameObject.AddComponent<Rigidbody>();
                rb.mass = fileName.Contains("Tennis", StringComparison.OrdinalIgnoreCase) ? 0.057f : 0.43f;
            }

            var col = rb.GetComponent<Collider>() ?? rb.GetComponentInChildren<Collider>();
            if (col == null)
            {
                var sc = rb.gameObject.AddComponent<SphereCollider>();
                sc.radius = fileName.Contains("Tennis", StringComparison.OrdinalIgnoreCase) ? 0.034f : 0.11f;
            }

            if (fileName.Contains("Soccer", StringComparison.OrdinalIgnoreCase) && fileName.Contains("Ball", StringComparison.OrdinalIgnoreCase))
                SoccerBallRigidbody = rb;
            else if (fileName.Contains("Tennis", StringComparison.OrdinalIgnoreCase) && fileName.Contains("Ball", StringComparison.OrdinalIgnoreCase))
                TennisBallTransform = rb.transform;
        }

        if (fileName.Contains("Racket", StringComparison.OrdinalIgnoreCase))
            TennisRacketTransform = root.transform;

        Debug.Log($"[FELMeshy] Loaded {fileName}");
    }
}
