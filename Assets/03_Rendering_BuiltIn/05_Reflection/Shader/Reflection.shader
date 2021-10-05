// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Reflection"
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
            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ VERTEXLIGHT_ON

            #pragma vertex LightingVertex
            #pragma fragment LightingFragment

            #define FORWARD_BASE_PASS
            #define BINORMAL_PER_FRAGMENT
            
            #include "../../03_Bumpiness/Shader/My Lighting Include Bumpiness.cginc"

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
            #pragma multi_compile_fwdadd_fullshadows
            #pragma vertex LightingVertex
            #pragma fragment LightingFragment

            #include "../../03_Bumpiness/Shader/My Lighting Include Bumpiness.cginc"

            ENDCG
        }


        Pass {
            Tags {
                "LightMode" = "ShadowCaster"
            }

            CGPROGRAM

            #pragma target 3.0
            #pragma multi_compile_shadowcaster
            #pragma vertex ShadowVertexProgram
            #pragma fragment ShadowFragmentProgram

            #include "../../04_Shadow/Shader/My Lighting Include Shadow.cginc"

            ENDCG
        }
    }
}