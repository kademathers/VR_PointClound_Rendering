using UnityEngine;

public class LoadPlyToBillboards : MonoBehaviour
{
    [Header("PLY file")]
    public string absolutePath; // simplest for test; later you can use StreamingAssets

    [Header("Downsampling")]
    public int stride = 1;      // 2 = half, 4 = quarter
    public int maxPoints = 0;   // 0 = unlimited

    [Header("Target renderer")]
    public QuestPointCloudBillboards rendererComponent;

    [Header("Scale & transform")]
    public float scale = 1.0f;
    public Vector3 offset = Vector3.zero;

    void Start()
    {
        if (rendererComponent == null)
            rendererComponent = GetComponent<QuestPointCloudBillboards>();

        if (rendererComponent == null)
        {
            Debug.LogError("Missing PointCloudBillboardPerCamera reference.");
            return;
        }

        if (string.IsNullOrEmpty(absolutePath))
        {
            Debug.LogError("absolutePath is empty.");
            return;
        }

        try
        {
            getPosCol(absolutePath, out var pos, out var col, maxPoints, stride);

            rendererComponent.positions = pos;
            rendererComponent.colors = col;

            // Rebuild buffers by re-enabling component
            rendererComponent.DisableScript();
            rendererComponent.EnableScript();

            Debug.Log($"Loaded PLY points: {pos.Length}");
        }
        catch (System.Exception e)
        {
            Debug.LogError($"PLY load failed: {e.Message}");
        }
    }

    /// <summary>
    /// Gets the positions and colors from an input point cloud
    /// </summary>
    /// <returns></returns>
    void getPosCol(string path, out Vector3[] positions, out Color32[] colors, int maxPoints = 0, int stride = 1){

        PlyAsciiLoader.Load(absolutePath, out var pos, out var col, maxPoints, stride);

        // Place points relative to parent transform
        Vector3 ParentPos = transform.parent.position;

        // Apply scale/offset
        for (int i = 0; i < pos.Length; i++)
            pos[i] = pos[i] * scale + ParentPos + offset;

        positions = pos;
        colors = col;
    }

    /// <summary>
    /// Button to apply any changes to scripts
    /// </summary>
    public bool Apply; //"run" or "generate" for example

    void Update()
    {
        if (Apply)
            ApplyButton();
        Apply = false;
    }

    void ApplyButton()
    {

        getPosCol(absolutePath, out var pos, out var col, maxPoints, stride);

        rendererComponent.positions = pos;
        rendererComponent.colors = col;

        // Rebuild buffers by re-enabling component
        rendererComponent.DisableScript();
        rendererComponent.EnableScript();
    }

}