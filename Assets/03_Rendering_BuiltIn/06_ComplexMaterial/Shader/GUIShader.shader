// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/GUIShader"
{
	Properties
	{
		_Tint ("Tint",Color) = (1,1,1,1)
		_MainTex("MainText",2D ) = "white" {}
        [NoScaleOffset] _NormalMap ("Normals", 2D) = "bump" {}
        _BumpScale ("Bump Scale",  Range(0, 1)) = 1

        _DetailTex ("Detail Albedo", 2D) = "gray" {}
        [NoScaleOffset] _DetailNormalMap ("Detail Normals", 2D) = "bump" {}
        _DetailBumpScale ("Detail Bump Scale",  Range(0, 1)) = 1

        [NoScaleOffset] _MetallicMap ("Metallic", 2D) = "white" {}
		[Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
		_Smoothness ("Smoothness", Range(0, 1)) = 0.1

        [NoScaleOffset] _EmissionMap ("Emission", 2D) = "black" {}
        _Emission ("Emission", Color) = (0, 0, 0)

        [NoScaleOffset] _OcclusionMap ("_Occlusion",2d) = "White"{}
        _OcclusionStrength("Occlusion Strength",Range(0,1)) = 1

        [NoScaleOffset] _DetailMask ("Detail Mask", 2D) = "white" {}


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
            #pragma shader_feature _METALLIC_MAP
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            #pragma shader_feature _OCCLUSION_MAP
            #pragma shader_feature _EMISSION_MAP
            #pragma shader_feature _DETAIL_MASK
            #pragma shader_feature _NORMAL_MAP
            #pragma shader_feature _DETAIL_ALBEDO_MAP
            #pragma shader_feature _DETAIL_NORMAL_MAP
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
            #pragma shader_feature _METALLIC_MAP
            #pragma shader_feature _NORMAL_MAP
            #pragma shader_feature _DETAIL_MASK
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            #pragma shader_feature _DETAIL_ALBEDO_MAP
            #pragma shader_feature _DETAIL_NORMAL_MAP
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
    CustomEditor "MyLightingShaderGUI"
}