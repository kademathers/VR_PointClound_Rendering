using System;
using System.Globalization;
using System.IO;
using UnityEngine;

public static class PlyAsciiLoader
{
    public static void Load(
        string path,
        out Vector3[] positions,
        out Color32[] colors,
        int maxPoints = 0,          // 0 = no limit
        int stride = 1              // 1 = keep all, 2 = every 2nd point, etc.
    )
    {
        positions = Array.Empty<Vector3>();
        colors = Array.Empty<Color32>();

        if (!File.Exists(path))
            throw new FileNotFoundException(path);

        using var sr = new StreamReader(path);

        // --- Parse header ---
        string line;
        int vertexCount = 0;
        bool inHeader = true;

        // We'll assume property order is x y z r g b (common case).
        // This is "minimal" on purpose.
        while (inHeader && (line = sr.ReadLine()) != null)
        {
            line = line.Trim();

            if (line.StartsWith("element vertex"))
            {
                var parts = line.Split(' ');
                vertexCount = int.Parse(parts[^1]);
            }
            else if (line == "end_header")
            {
                inHeader = false;
                break;
            }
        }

        if (vertexCount <= 0)
            throw new Exception("PLY header missing or vertex count <= 0.");

        // Apply stride + maxPoints
        int effectiveCount = vertexCount;
        if (stride > 1) effectiveCount = (vertexCount + stride - 1) / stride;
        if (maxPoints > 0) effectiveCount = Mathf.Min(effectiveCount, maxPoints);

        positions = new Vector3[effectiveCount];
        colors = new Color32[effectiveCount];

        // --- Read vertices ---
        int writeIndex = 0;
        int readIndex = 0;

        var ci = CultureInfo.InvariantCulture;

        while (writeIndex < effectiveCount && (line = sr.ReadLine()) != null)
        {
            if (string.IsNullOrWhiteSpace(line)) continue;

            // stride skip
            if (stride > 1 && (readIndex % stride) != 0)
            {
                readIndex++;
                continue;
            }

            var p = line.Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            if (p.Length < 6)
            {
                readIndex++;
                continue;
            }

            //float x = float.Parse(p[0], ci);
            //float y = float.Parse(p[1], ci);
            //float z = float.Parse(p[2], ci);

            float x = float.Parse(p[0], ci);
            float z = float.Parse(p[1], ci);
            float y = float.Parse(p[2], ci);

            byte r = byte.Parse(p[3], ci);
            byte g = byte.Parse(p[4], ci);
            byte b = byte.Parse(p[5], ci);

            positions[writeIndex] = new Vector3(x, y, z);
            colors[writeIndex] = new Color32(r, g, b, 255);

            writeIndex++;
            readIndex++;
        }
    }
}