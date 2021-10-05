// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Bumpiness"
{
	Properties
	{
		_Tint ("Tint",Color) = (1,1,1,1)
		_MainTex("MainText",2D ) = "white" {}
        [NoScaleOffset] _NormalMap ("Normals", 2D) = "bump" {}
        _BumpScale ("Bump Scale",  Range(0, 1)) = 1

        _DetailTex ("Detail Texture", 2D) = "gray" {}
        [NoScaleOffset] _DetailNormalMap ("Detail Normals", 2D) = "bump" {}
        _DetailBumpScale ("Detail Bump Scale",  Range(0, 1)) = 1

		[Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
		_Smoothness ("Smoothness", Range(0, 1)) = 0.1

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
            #define BINORMAL_PER_FRAGMENT
            
            #include "My Lighting Include Bumpiness.cginc"

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

            #include "My Lighting Include Bumpiness.cginc"

            ENDCG
        }
    }
}