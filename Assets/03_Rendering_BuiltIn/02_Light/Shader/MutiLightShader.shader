Shader "Custom/MutiLightShader"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" {}
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
    }
    SubShader
    {
        Pass
        {
            Tags {
                "LightMode" = "ForwardBase"
            }

            CGPROGRAM

            #pragma target 3.0
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma vertex LightingVertex
            #pragma fragment LightingFragment

            #define FORWARD_BASE_PASS
            
            #include "My Lighting Include.cginc"

            ENDCG
        }

        Pass {
            Tags {
                "LightMode" = "ForwardAdd"
            }
            Blend One One
            ZWrite Off
            CGPROGRAM

            #pragma target 3.0
            #pragma multi_compile_fwdadd
            #pragma vertex LightingVertex
            #pragma fragment LightingFragment

            #include "My Lighting Include.cginc"

            ENDCG
        }
    }
}
