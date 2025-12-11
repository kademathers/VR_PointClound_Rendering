
// Now is radially centered on camera position and the shadows are also based on camera position making them appear like real spheres
Shader "Custom/PC_Shader"
{
    Properties
    {
        _PointSize("Point Size (meters)", Float) = 0.01
        _Cutoff("Alpha Cutoff", Range(0,1)) = 0.01
    }

        SubShader
    {
        Tags
        {
            "RenderType" = "TransparentCutout"
            "Queue" = "AlphaTest"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "Forward"
            Tags { "LightMode" = "UniversalForward" }

            
        Cull Off

        HLSLPROGRAM
        #pragma vertex vert
        #pragma fragment frag
        #pragma target 3.0

        #pragma multi_compile _ _STEREO_INSTANCING _STEREO_MULTIVIEW

        // XR / instancing friendly
        //#pragma multi_compile_instancing
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _ADDITIONAL_LIGHTS

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        StructuredBuffer<float3> _Positions;
        StructuredBuffer<uint> _Colors;

        int _Count;
        float _PointSize;
        float _Cutoff;
        float _LitFadeBuff;
        float _UnlitStart;
        float _UnlitEnd;

        float3 _CamPos;

        struct Attributes
        {
            uint vertexID   : SV_VertexID;   // 0..5
            //uint instanceID : SV_InstanceID; // 0.._Count-1
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float3 centerWS   : TEXCOORD0;
            float2 uv         : TEXCOORD1; // -1..1 quad space
            float4 color      : TEXCOORD2;

            float3 viewDirWS  : TEXCOORD3; // point -> camera
            float3 rightWS    : TEXCOORD4; // per-point tangent
            float3 upWS       : TEXCOORD5; // per-point bitangent

            //UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        };

        float4 UnpackColor(uint c)
        {
            float r = (c & 0xFF) / 255.0;
            float g = ((c >> 8) & 0xFF) / 255.0;
            float b = ((c >> 16) & 0xFF) / 255.0;
            float a = ((c >> 24) & 0xFF) / 255.0;
            return float4(r, g, b, a);
        }

        // 6-vertex quad (two triangles)
        static const float2 kCorners[6] =
        {
            float2(-1,-1),
            float2(1,-1),
            float2(1, 1),
            float2(-1,-1),
            float2(1, 1),
            float2(-1, 1)
        };

        Varyings vert(Attributes IN)
        {
            Varyings OUT;
            UNITY_SETUP_INSTANCE_ID(IN);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

            //uint cornerIndex = IN.vertexID;     // 0..5
            //uint pointIndex = IN.instanceID;   // per-point instance
            uint vid = IN.vertexID;
            uint pointIndex = vid / 6;
            uint cornerIndex = vid % 6;

            // Safety
            pointIndex = min(pointIndex, (uint)(_Count - 1));

            float3 centerWS = _Positions[pointIndex];
            float4 col = UnpackColor(_Colors[pointIndex]);

            // --- build per-point radial basis ---

            // direction from point to camera
            float3 toCam = normalize(_WorldSpaceCameraPos - centerWS);

            // pick an "up" that is not parallel to toCam
            float3 worldUp = float3(0, 1, 0);
            if (abs(dot(worldUp, toCam)) > 0.99)
            {
                worldUp = float3(1, 0, 0);
            }

            float3 right = normalize(cross(worldUp, toCam));
            float3 up = cross(toCam, right);

            // --- use that basis to place the quad ---

            float2 corner = kCorners[cornerIndex];
            float  halfSize = _PointSize * 0.5;

            float3 offsetWS = (corner.x * right + corner.y * up) * halfSize;
            float3 posWS = centerWS + offsetWS;

            OUT.centerWS = centerWS;
            OUT.uv = corner;
            OUT.color = col;

            OUT.viewDirWS = toCam;
            OUT.rightWS = right;
            OUT.upWS = up;

            OUT.positionCS = TransformWorldToHClip(posWS);
            return OUT;
        }

        half4 frag(Varyings IN) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);


        float dist = distance(IN.centerWS, _WorldSpaceCameraPos);
        float t = 1.0; // Value for lit buffer fading

        if (dist > _UnlitStart) // far points will be unlit
        {
            // do circle mask same as before
            float2 uv = IN.uv;
            float r2 = dot(uv, uv);
            if (r2 > 1.0) discard;

            // simple unlit color (or maybe slight fog/fade)
            half4 col = IN.color;
            col.a *= saturate((_UnlitEnd - dist) / (_UnlitEnd - _UnlitStart));
            clip(col.a - _Cutoff);
            return col;
        }
        else if (dist > _UnlitStart - _LitFadeBuff) {
            t = saturate((_UnlitStart - dist) / (_LitFadeBuff));
        }

        // Circle mask
        float2 uv = IN.uv;
        float  r2 = dot(uv, uv);
        if (r2 > 1.0) discard;

        // Fake sphere normal in world space, but *radial* around point -> camera
        float z = sqrt(saturate(1.0 - r2));

        float3 nWS = normalize(
            uv.x * IN.rightWS +
            uv.y * IN.upWS +
            z * IN.viewDirWS
        );

        // URP lighting
        InputData inputData;
        ZERO_INITIALIZE(InputData, inputData);
        inputData.positionWS = IN.centerWS;
        inputData.normalWS = nWS;
        // viewDirectionWS is "camera - point", so same as toCam,
        // URP expects viewDir *from* pixel *towards* camera:
        inputData.viewDirectionWS = normalize(_WorldSpaceCameraPos - IN.centerWS);
        inputData.shadowCoord = TransformWorldToShadowCoord(IN.centerWS);

        SurfaceData surface;
        ZERO_INITIALIZE(SurfaceData, surface);
        surface.albedo = IN.color.rgb;
        surface.alpha = IN.color.a;
        surface.metallic = 0;
        surface.smoothness = 0.1;
        surface.normalTS = float3(0,0,1);
        surface.occlusion = 1;
        surface.emission = 0;

        half4 lit = UniversalFragmentPBR(inputData, surface);
        half4 unlitCol = IN.color;
        // Blend between them
        half4 finalCol = lerp(unlitCol, lit, t);

        clip(finalCol.a - _Cutoff);
        return finalCol;
    }
    ENDHLSL
}
    }
}