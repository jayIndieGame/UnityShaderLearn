// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Deferred"
{
	Properties
	{
		_Tint ("Tint",Color) = (1,1,1,1)
		_MainTex("Albedo",2D ) = "white" {}
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

        _AlphaClip("Alpha Clip",Range(0,1)) = 1
        [HideInInspector] _SrcBlend("_SrcBlend",Float) = 1
        [HideInInspector] _DstBlend("_DstBlend",Float) = 0
        [HideInInspector] _ZWrite ("_ZWrite", Float) = 1

	}
	SubShader
    {
        Pass
        {
            Tags {
                "LightMode" = "ForwardBase"
            }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
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
            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
            #pragma vertex LightingVertex
            #pragma fragment LightingFragment


            #define FORWARD_BASE_PASS
            #define BINORMAL_PER_FRAGMENT
            
            #include "../03_Bumpiness/Shader/My Lighting Include Bumpiness.cginc"

            ENDCG
        }

        Pass {
            Tags {
                "LightMode" = "ForwardAdd"
            }
            Blend [_SrcBlend] One
            ZWrite Off
            CGPROGRAM

            #pragma target 3.0
            
            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
            #pragma shader_feature _METALLIC_MAP
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            
            #pragma shader_feature _NORMAL_MAP
            #pragma shader_feature _DETAIL_MASK
            #pragma shader_feature _DETAIL_ALBEDO_MAP
            #pragma shader_feature _DETAIL_NORMAL_MAP
            #pragma multi_compile_fwdadd_fullshadows
            #pragma vertex LightingVertex
            #pragma fragment LightingFragment

            #include "../03_Bumpiness/Shader/My Lighting Include Bumpiness.cginc"

            ENDCG
        }


        Pass {
            Tags {
                "LightMode" = "ShadowCaster"
            }

            CGPROGRAM

            #pragma target 3.0
            #pragma multi_compile_shadowcaster
            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
            #pragma shader_feature _SMOOTHNESS_ALBEDO
            #pragma vertex ShadowVertexProgram
            #pragma fragment ShadowFragmentProgram

            #include "../04_Shadow/Shader/My Lighting Include Shadow.cginc"

            ENDCG
        }
        Pass
        {
            Tags{
                "LightMode" = "Deferred"
            }

            CGPROGRAM

            #pragma target 3.0
            #pragma exclude_renderers nomrt
            #pragma shader_feature _ _RENDERING_CUTOUT
            #pragma shader_feature _METALLIC_MAP
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            #pragma shader_feature _NORMAL_MAP
            #pragma shader_feature _OCCLUSION_MAP
            #pragma shader_feature _EMISSION_MAP
            #pragma shader_feature _DETAIL_MASK
            #pragma shader_feature _DETAIL_ALBEDO_MAP
            #pragma shader_feature _DETAIL_NORMAL_MAP
            #pragma multi_compile _ UNITY_HDR_ON

            #pragma vertex LightingVertex
            #pragma fragment LightingFragment

            #define DEFERRED_PASS

            #include "../03_Bumpiness/Shader/My Lighting Include Bumpiness.cginc"

            ENDCG
        }
    }
    CustomEditor "MyLightingShaderGUI"
}