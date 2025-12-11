Shader "Custom/GPT3"
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

        float3 _CamRight;
        float3 _CamUp;
        float3 _CamForward;

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

            float2 corner = kCorners[cornerIndex];
            float halfSize = _PointSize * 0.5;

            float3 offsetWS = (corner.x * _CamRight + corner.y * _CamUp) * halfSize;
            float3 posWS = centerWS + offsetWS;

            OUT.centerWS = centerWS;
            OUT.uv = corner; // -1..1
            OUT.color = col;
            OUT.positionCS = TransformWorldToHClip(posWS);
            return OUT;
        }

        half4 frag(Varyings IN) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

        // Circle mask
        float2 uv = IN.uv;
        float r2 = dot(uv, uv);
        if (r2 > 1.0) discard;

        // Sphere impostor normal in world space
        float z = sqrt(saturate(1.0 - r2));
        float3 nWS = normalize(uv.x * _CamRight + uv.y * _CamUp + z * _CamForward);

        // URP lighting (main light + optional additional)
        InputData inputData;
        ZERO_INITIALIZE(InputData, inputData);
        inputData.positionWS = IN.centerWS;
        inputData.normalWS = nWS;
        inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.centerWS);
        inputData.shadowCoord = TransformWorldToShadowCoord(IN.centerWS);

        // Simple lit color using URP helper
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

        // Alpha test optional
        clip(lit.a - _Cutoff);
        return lit;
    }
    ENDHLSL
}
    }
}