
using UnityEngine;
using UnityEngine.Rendering;

public class QuestPointCloudBillboards : MonoBehaviour
{
    public Material material;
    public float pointSizeMeters = 1.0f;

    /// <summary>
    /// The length of fade distance from lit to unlit before the DistToUnlit distance.
    /// </summary>
    public float LightFadeBuffer = 1;
    /// <summary>
    /// How far away the points should be to stop being lit properly
    /// </summary>
    public float DistToUnlit = 7.0f;
    /// <summary>
    /// How far the fade off to no points should be from. Will be no points after this distance and fading between DistToUnlit and here.
    /// </summary>
    public float DistToNone = 20.0f;

    public bool autoCreateTestPoint = true;

    [HideInInspector] // Hide in inspector due to lag loading this when inspecting object to change point size etc.
    public Vector3[] positions;
    [HideInInspector]
    public Color32[] colors;

    ComputeBuffer _posBuffer;
    ComputeBuffer _colBuffer;
    int _count;

    static readonly int CamFwdId = Shader.PropertyToID("_CamForward");
    static readonly int PosId = Shader.PropertyToID("_Positions");
    static readonly int ColId = Shader.PropertyToID("_Colors");
    static readonly int CountId = Shader.PropertyToID("_Count");
    static readonly int SizeId = Shader.PropertyToID("_PointSize");
    static readonly int CamRightId = Shader.PropertyToID("_CamRight");
    static readonly int CamUpId = Shader.PropertyToID("_CamUp");
    static readonly int CamPos = Shader.PropertyToID("_CamPos");
    static readonly int LitFadeBuff = Shader.PropertyToID("_LitFadeBuff");
    static readonly int UnlitStart = Shader.PropertyToID("_UnlitStart");
    static readonly int UnlitEnd = Shader.PropertyToID("_UnlitEnd");

    void OnEnable()
    {
        if (material == null)
        {
            Debug.LogError("Missing material.");
            enabled = false;
            return;
        }

        if (autoCreateTestPoint && (positions == null || positions.Length == 0))
        {
            positions = new[] { Vector3.zero };
            colors = new[] { new Color32(255, 0, 0, 255) };
        }

        if (positions == null || colors == null || positions.Length == 0)
        {
            Debug.LogError("positions/colors not set.");
            enabled = false;
            return;
        }

        Debug.LogWarning(positions);
        Debug.LogWarning(colors);

        _count = Mathf.Min(positions.Length, colors.Length);

        _posBuffer = new ComputeBuffer(_count, sizeof(float) * 3);
        _colBuffer = new ComputeBuffer(_count, sizeof(uint));

        _posBuffer.SetData(positions);

        uint[] packed = new uint[_count];
        for (int i = 0; i < _count; i++)
        {
            Color32 c = colors[i];
            packed[i] = (uint)(c.r | (c.g << 8) | (c.b << 16) | (c.a << 24));
        }
        _colBuffer.SetData(packed);

        material.SetBuffer(PosId, _posBuffer);
        material.SetBuffer(ColId, _colBuffer);
        material.SetInt(CountId, _count);

        RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;

        Debug.Log($"PointCloudBillboardPerCamera enabled. Count={_count}");
    }

    void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;

        _posBuffer?.Release();
        _colBuffer?.Release();
        _posBuffer = null;
        _colBuffer = null;
    }

    public void EnableScript()
    {
        this.enabled = true; // Enables this script
    }

    public void DisableScript()
    {
        this.enabled = false; // Disables this script
    }

    void OnBeginCameraRendering(ScriptableRenderContext context, Camera cam)
    {
        if (material == null || _count == 0) return;

        // Optional: ignore Scene view camera if you want
#if UNITY_EDITOR
        if (cam.cameraType == CameraType.SceneView) return;
#endif

        // Make sure this camera can see this object's layer
        if ((cam.cullingMask & (1 << gameObject.layer)) == 0) return;

        material.SetVector(CamFwdId, cam.transform.forward);
        material.SetFloat(SizeId, pointSizeMeters);
        material.SetVector(CamRightId, cam.transform.right);
        material.SetVector(CamUpId, cam.transform.up);
        material.SetVector(CamPos, cam.transform.position);
        material.SetFloat(LitFadeBuff, LightFadeBuffer);
        material.SetFloat(UnlitStart, DistToUnlit);
        material.SetFloat(UnlitEnd, DistToNone);


        // Very large bounds to avoid culling issues
        var bounds = new Bounds(Vector3.zero, Vector3.one * 10000f);
        Graphics.DrawProcedural(
            material, bounds, MeshTopology.Triangles,
            6 * _count, 1
            );
        //Graphics.DrawProcedural(
        //    material,
        //    bounds,
        //    MeshTopology.Triangles,
        //    6,
        //    _count,
        //    null,
        //    null,
        //    ShadowCastingMode.Off,
        //    false,
        //    gameObject.layer
        //);
    }
}