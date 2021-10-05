Shader "Custom/Flow/Direction Flow"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        [NoScaleOffset] _MainTex ("Deriv (AG) Height (B)", 2D) = "white" {}
        [NoScaleOffset] _FlowMap ("Flow(RG,A noise)",2D) = "black" {}
        [Toggle(_DUAL_GRID)] _DualGrid ("Dual Grid", Int) = 0
        _Tiling ("Tiling，Constant",Float) = 1
        _TilingModulated ("Tiling, Modulated", Float) = 1
        _GridResolution("Grid Resolution",Float) = 10
        _Speed ("Speed",Float) = 1
        _FlowStrength("Flow Strength",Float) = 1
        _HeightScale("Height Scale,Modulated",Float) = 0.25
        _HeightScaleModulated("Height Scale,Modulated",Float) = 0.75
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows
        #pragma target 3.0
        #pragma shader_feature _DUAL_GRID
        #include "../Flow.cginc" 

        sampler2D _MainTex,_FlowMap;
        float _Tiling,_TilingModulated,_Speed,_FlowStrength,_HeightScale,_HeightScaleModulated,_GridResolution;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        float3 UnpackDerivativeHeight(float4 textureData){
            float3 dh = textureData.agb;
            dh.xy = dh.xy * 2 - 1;
            return dh;
        }

        float3 FlowCell(float2 uv,float2 offset,float time,float gridB)
        {
            float2 shift = 1 - offset;//对A移动到左下的中心 对B竖直移动取中心....
            shift *= 0;
            offset *= 0.5;
            if (gridB) {
                offset += 0.25;
                shift -= 0.25;
            }
            float2x2 derivRotation;
            float2 uvTiled = (floor(uv * _GridResolution + offset)+ shift) /_GridResolution;//分了个格子，并且

            float3 flow = tex2D(_FlowMap, uvTiled).rgb;//根据格子在水流图上采样
            flow.xy = flow.xy * 2 - 1;
            flow.z *= _FlowStrength;
            float tiling = flow.z * _TilingModulated + _Tiling;//根据水流强度取不同个数的Tile
            float2 uvFlow = DirectionFlowUV(uv + offset,flow,tiling,time,derivRotation);//获得会动的uv
            float3 dh = UnpackDerivativeHeight(tex2D(_MainTex,uvFlow));//根据动态的uv获得动态的导数图
            dh.xy = mul(derivRotation, dh.xy);//将导数正确的旋转。
            dh *= flow.z * _HeightScaleModulated + _HeightScale; //引入水流强度
            return dh;
        }

        float3 FlowGrid (float2 uv, float time,bool gridB) {
            //四方向采样。
            float3 dhA = FlowCell(uv, float2(0, 0), time,gridB);
            float3 dhB = FlowCell(uv, float2(1, 0), time,gridB);
            float3 dhC = FlowCell(uv, float2(0, 1), time,gridB);
            float3 dhD = FlowCell(uv, float2(1, 1), time,gridB);
            //计算权重，越靠近右上的grid，t在该方向的分量越大，远离右上则取更多的自身。
            float2 t = abs(2 * frac(uv * _GridResolution) - 1);
            float wA = (1 - t.x) * (1 - t.y);//自身融合系数
            float wB = t.x * (1-t.y);//右1融合系数
            float wC = (1 - t.x) * t.y;//上1融合系数
            float wD = t.x * t.y;//右上融合系数

            return dhA * wA + dhB * wB + dhC * wC + dhD * wD;
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            //float2 uv = IN.uv_MainTex * _Tiling;
            float time = _Time.y * _Speed;
            float2 uv = IN.uv_MainTex;

            float3 dh = FlowGrid(uv,time,false);
            #if defined(_DUAL_GRID)
                dh = (dh + FlowGrid(uv, time, true)) * 0.5;
            #endif
            fixed4 c = dh.z * dh.z *_Color;
        
            //fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            o.Normal = normalize(float3(-dh.xy,1));
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
