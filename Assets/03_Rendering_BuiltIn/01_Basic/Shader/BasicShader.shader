// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Basic Shader"
{
	Properties
	{
		_Tint ("Tint",Color) = (1,1,1,1)
		_MainTex("MainText",2D ) = "white" {}

	}
	SubShader{

		Pass {
			CGPROGRAM
			#pragma vertex BasicVertexProgram
			#pragma fragment BasicFragmentProgram
			#include "UnityCG.cginc"

			float4 _Tint;
			sampler2D _MainTex;
			float4 _MainTex_ST;

			struct Interpolators {
				float4 position : SV_POSITION;
				float2 uv : TEXCOORD0;
			};
			struct VertexData{
				float4 position : POSITION;
				float2 uv : TEXCOORD0;
			};

			Interpolators BasicVertexProgram(VertexData v){
				Interpolators i;
				i.position = UnityObjectToClipPos(v.position);
				i.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return i;
			}

			float4 BasicFragmentProgram(Interpolators i) : SV_TARGET{
				float4 color = tex2D(_MainTex,i.uv)*_Tint;
				return color;
			}
			ENDCG
		}
	}
}