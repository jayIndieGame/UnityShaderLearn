Shader "Custom/Deferred Fog" {
    
    Properties {
        _MainTex ("Source", 2D) = "white" {}
    }

    SubShader {
        Cull Off
        ZTest Always
        ZWrite Off

    Pass {
        CGPROGRAM

        #pragma vertex VertexProgram
        #pragma fragment FragmentProgram

        #pragma multi_compile_fog
        #define FOG_DISTANCE
        //#define FOG_SKYBOX

        #include "UnityCG.cginc"

        sampler2D _MainTex, _CameraDepthTexture;
        float3 _FrustumCorners[4];//接收frustum的数据

        struct VertexData {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct Interpolators {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
            #if defined(FOG_DISTANCE)
                //获取摄像机到当前着色点的方向向量
                float3 ray : TEXCOORD1;
            #endif
        };

        Interpolators VertexProgram (VertexData v) {
            Interpolators i;
            i.pos = UnityObjectToClipPos(v.vertex);
            i.uv = v.uv;
            //根据左下、右下、左上、右上的顺序，左下是0对应UV(0,0),右下是1对应UV(1,0)
            //左上是2对应UV(0,1),右下是3对应UV(1,1),所以可以用u+2v来获取对应的index
            #if defined(FOG_DISTANCE)
                i.ray = _FrustumCorners[v.uv.x + 2 * v.uv.y];
            #endif
            return i;
        }

        float4 FragmentProgram (Interpolators i) : SV_Target {
            float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
            depth = Linear01Depth(depth);
            //inline float Linear01Depth( float z )
            //{
            //    return 1.0 / (_ZBufferParams.x * z + _ZBufferParams.y);
            //}
            // Values used to linearize the Z buffer
            // (http://www.humus.name/temp/Linearize%20depth.txt)
            // x = 1-far/near1
            // y = far/near
            // z = x/far
            // w = y/far
            //float4 _ZBufferParams;
            float viewDistance = depth * _ProjectionParams.z - _ProjectionParams.y;
            #if defined(FOG_DISTANCE)
                viewDistance = length(i.ray * depth);
            #endif

            UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
            unityFogFactor = saturate(unityFogFactor);
            #if !defined(FOG_SKYBOX)
                if (depth > 0.9999) {
                    unityFogFactor = 1;
                }
            #endif
            #if !defined(FOG_LINEAR) && !defined(FOG_EXP) && !defined(FOG_EXP2)
                unityFogFactor = 1;
            #endif
            float3 sourceColor = tex2D(_MainTex, i.uv).rgb;
            float3 foggedColor = lerp(unity_FogColor.rgb, sourceColor, unityFogFactor);
            return float4(foggedColor, 1);
        }

        ENDCG
        }       
    }
}