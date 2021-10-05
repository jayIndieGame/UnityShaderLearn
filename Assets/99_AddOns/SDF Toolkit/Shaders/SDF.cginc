/*
 * Copyright 2015, Catlike Coding
 * http://catlikecoding.com
 */

#include "UnityCG.cginc"

// Added for BlendNormals in Unlit shader.
#include "UnityPBSLighting.cginc"

#include "SDFToolkit.hlsl"

sampler2D _MainTex, _AlbedoMap, _AlbedoMap2;
float4 _MainTex_ST, _AlbedoMap_ST, _AlbedoMap2_ST;
half _UVSet, _UVSet2;

half4 _Color, _Color2;

half _Cutoff;
half _Contour, _Contour2;
half _Smoothing, _Smoothing2;

sampler2D _MetallicGlossMap, _MetallicGlossMap2;
half _Metallic, _Metallic2;
sampler2D _SpecGlossMap, _SpecGlossMap2;
half3 _Specular, _Specular2;
half _Glossiness, _Glossiness2;

sampler2D _EmissionMap, _EmissionMap2;
half3 _EmissionColor, _EmissionColor2;

sampler2D _NormalMap, _NormalMap2;
half _NormalScale, _NormalScale2;

float _BevelScale;
float _BevelLow, _BevelHigh;
float _BevelLow2, _BevelHigh2;

float4 _MainTex_TexelSize;

#if defined(SDF_SPECULAR) || defined(SDF_METALLIC)
	#if defined(_NORMALMAP) || defined(_BEVEL_ON) || !defined(DIRLIGHTMAP_OFF)
		#define _TANGENT_TO_WORLD
	#endif
#endif

#if defined(SDF_META) || defined(SDF_SHADOW)
	// Meta and shadow passes don't use automatic smoothing, but manual smoothing does influence them.
	#if !defined(_SMOOTHINGMODE_AUTO)
		#define SDF_SMOOTHING_MANUAL
	#endif
#else
	#if defined(_SMOOTHINGMODE_AUTO) || defined(_SMOOTHINGMODE_MIXED)
		#define SDF_SMOOTHING_AUTO
	#endif
	#if !defined(_SMOOTHINGMODE_AUTO)
		#define SDF_SMOOTHING_MANUAL
	#endif
#endif

#if defined(_SUPERSAMPLE_ON)
	#define SDF_SUPERSAMPLE
#endif

#if defined(_VERTEXCOLOR_ON) || (defined(_CONTOUR2_ON) && defined (_VERTEXCOLOR2_ON))
	#define SDF_VERTEXCOLOR
#endif

// Albedo is either only tint, only map, or both. These keywords are shared by both contours.
#if defined(_ALBEDOMAP) || defined(_ALBEDOTINTMAP)
	#define SDF_ALBEDOMAP
	#define SDF_TEXTURED
#endif
#if !defined(_ALBEDOMAP)
	#define SDF_ALBEDOTINT
#endif

#if !defined(SDF_TEXTURED)
	// Determine whether UV coordinates are needed for materials.
	#if defined(_SPECGLOSSMAP) || defined(_SPECGLOSSMAP2)
		#define SDF_TEXTURED
	#elif defined(_METALLICGLOSSMAP) || defined(_METALLICGLOSSMAP2)
		#define SDF_TEXTURED
	#elif defined(_EMISSIONMAP) || defined(_NORMALMAP)
		#define SDF_TEXTURED
	#endif
#endif

#if defined(SDF_UI) && defined(SDF_TEXTURED)
	float4 _AlbedoMap_TexelSize, _AlbedoMap2_TexelSize;
#endif

struct VertexInput {
	float4 vertex : POSITION;
	
	#if defined(SDF_VERTEXCOLOR)
		half4 color : COLOR;
	#endif
	
	#if !defined(SDF_META) && !defined(SDF_UNLIT)
		half3 normal : NORMAL;
	#endif
	
	#if defined(_TANGENT_TO_WORLD)
		half4 tangent : TANGENT;
	#endif
	
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	#if defined(SDF_META) || defined(DYNAMICLIGHTMAP_ON)
		// Realtime GI uv.
		float2 uv2 : TEXCOORD2;
	#endif
	float2 uv3 : TEXCOORD3;
};

#if defined(SDF_SHADOW)
	struct v2fSDF {
		#if defined(SDF_VERTEXCOLOR)
			half4 color : COLOR;
		#endif
		
		V2F_SHADOW_CASTER_NOPOS
		
		float2 uvSDF : TEXCOORD1;
		#if defined(SDF_TEXTURED)
			float4 uvM : TEXCOORD2;
		#endif
	};
#elif defined(SDF_META) || defined(SDF_UNLIT)
	struct v2fSDF {
		float4 pos : SV_POSITION;
		
		#if defined(SDF_VERTEXCOLOR)
			half4 color : COLOR;
		#endif
		
		float2 uvSDF : TEXCOORD0;
		#if defined(SDF_TEXTURED)
			float4 uvM : TEXCOORD1;
		#endif
		
		#if defined(UNITY_UI_CLIP_RECT) && defined(SDF_UNLIT)
			float2 uiClipXY : TEXCOORD2;
		#endif
	};
#elif defined(SDF_SPECULAR) || defined(SDF_METALLIC)
	struct v2fSDF {
		float4 pos : SV_POSITION;
		
		#if defined(SDF_VERTEXCOLOR)
			half4 color : COLOR;
		#endif
		
		float3 uvSDF : TEXCOORD0; // Added room for fog.
		#if defined(SDF_TEXTURED)
			float4 uvM : TEXCOORD1;
		#endif
		
		half3 eyeVec : TEXCOORD2;
		
		#if defined(SDF_FORWARD_BASE)
			half4 tangentToWorldAndParallax[3] : TEXCOORD3; // [3x3:tangentToWorld | 1x3:viewDirForParallax]
			half4 ambientOrLightmapUV : TEXCOORD6; // SH or Lightmap UV
			SHADOW_COORDS(7)
			
			// next ones would not fit into SM2.0 limits, but they are always for SM3.0+
			#if UNITY_SPECCUBE_BOX_PROJECTION
				float3 posWorld : TEXCOORD8;
			#endif
		#elif defined(SDF_DEFERRED)
			half4 tangentToWorldAndParallax[3] : TEXCOORD3; // [3x3:tangentToWorld | 1x3:viewDirForParallax]
			half4 ambientOrLightmapUV : TEXCOORD6; // SH or Lightmap UV
			#if UNITY_SPECCUBE_BOX_PROJECTION
				float3 posWorld : TEXCOORD7;
			#endif
		#elif defined(SDF_FORWARD_ADD)
			half4 tangentToWorldAndLightDir[3] : TEXCOORD3; // [3x3:tangentToWorld | 1x3:lightDir]
			LIGHTING_COORDS(6,7)
		#endif

		#if defined(UNITY_UI_CLIP_RECT)
			float2 uiClipXY : UI_CLIP_XY;
		#endif
	};
#endif

#if defined(UNITY_UI_CLIP_RECT)
	#define SDF_DECLARE_CLIP_RECT float4 _ClipRect
	#define SDF_UI_RECT_CLIP_TRANSFER(o,v) o.uiClipXY = v.vertex.xy;
	#define SDF_UI_RECT_CLIP(i) \
	float2 uiInside = step(_ClipRect.xy, i.uiClipXY.xy) * step(i.uiClipXY.xy, _ClipRect.zw); \
	clip(uiInside.x * uiInside.y - 0.001);
#else
	#define SDF_DECLARE_CLIP_RECT
	#define SDF_UI_RECT_CLIP_TRANSFER(o,v)
	#define SDF_UI_RECT_CLIP(i)
#endif

// Pass SDF texture uv and color data from vertex to fragment.
v2fSDF CreateV2FSDF (VertexInput v) {
	v2fSDF o;
	UNITY_INITIALIZE_OUTPUT(v2fSDF, o);
	o.uvSDF.xy = TRANSFORM_TEX(v.uv0, _MainTex);
	
	#if defined(SDF_TEXTURED)
		// Branch on uniform variables instead of using more keywords.
		#if defined(SDF_UI)
			float2 uvM1 = _UVSet == 0 ? v.uv0 : (_UVSet == 1 ? v.uv1 : (v.uv1 * _AlbedoMap_TexelSize.xy));
		#else
			float2 uvM1 = _UVSet == 0 ? v.uv0 : (_UVSet == 1 ? v.uv1 : v.uv3);
		#endif
		o.uvM.xy = TRANSFORM_TEX(uvM1, _AlbedoMap);
		
		#if defined(_CONTOUR2_ON)
			#if defined(SDF_UI)
				float2 uvM2 = _UVSet2 == 0 ? v.uv0 : (_UVSet2 == 1 ? v.uv1 : (v.uv1 * _AlbedoMap2_TexelSize.xy));
			#else
				float2 uvM2 = _UVSet2 == 0 ? v.uv0 : (_UVSet2 == 1 ? v.uv1 : v.uv3);
			#endif
			o.uvM.zw = TRANSFORM_TEX(uvM2, _AlbedoMap2);
		#endif
	#endif
	
	#if defined(SDF_VERTEXCOLOR)
		o.color = v.color;
	#endif
	return o;
}

struct SDFData {
	float2 uvSDF;
	half distance;
	half2 range, range2;
	half3 albedo, albedo2;
	half alpha, alpha2;
	half4 specGloss, specGloss2;
	half2 metallicGloss, metallicGloss2;
	half3 emission, emission2;
	half3 normal, normal2;
};

// Create SDF data structure and initialize with sane defaults.
SDFData CreateSDFData () {
	SDFData d;
	d.uvSDF = 0;
	d.distance = 0;
	d.range = float2(0, 0);
	d.range2 = d.range;
	d.albedo = half3(0, 0, 0);
	d.albedo2 = d.albedo;
	d.alpha = 1;
	d.alpha2 = d.alpha;
	d.specGloss = half4(1, 1, 1, 1);
	d.specGloss2 = d.specGloss;
	d.metallicGloss = half2(0, 0);
	d.metallicGloss2 = d.metallicGloss;
	d.emission = half3(0, 0, 0);
	d.emission2 = d.emission;
	d.normal = half3(0, 0, 1);
	d.normal2 = d.normal;
	return d;
}

// Sample SDF texture to get a distance measure.
half sampleDistance (float2 uv, bool supersample) {
	return SDF_TOOLKIT_SAMPLE_DISTANCE(TEXTURE2D_ARGS(_MainTex, 0), uv, supersample);
}

// Extract SDF data from shader variables and vertex input.
SDFData FillData(v2fSDF i) {
	bool supersample = false;
	#if defined(SDF_SUPERSAMPLE)
		supersample = true;
	#endif

	SDFData d = CreateSDFData();
	
	d.uvSDF = i.uvSDF;
	d.distance = sampleDistance(d.uvSDF, supersample);
	
	half smoothing = 0;
	#if defined(SDF_SMOOTHING_AUTO)
		smoothing = fwidth(d.distance);
	#endif
	half smoothing2 = smoothing;
	
	#if defined(SDF_SMOOTHING_MANUAL)
		smoothing += _Smoothing;
		smoothing2 += _Smoothing2;
	#endif
	
	d.range = half2(_Contour - smoothing, _Contour + smoothing);
	d.range2 = half2(_Contour2 - smoothing2, _Contour2 + smoothing2);
	
	half4 color1 = half4(1, 1, 1, 1);
	half4 color2 = color1;
	
	#if defined(SDF_ALBEDOTINT)
		color1 = _Color;
	#endif
	#if defined(SDF_VERTEXCOLOR) && defined(_VERTEXCOLOR_ON)
		color1 *= i.color;
	#endif
	
	#if defined(SDF_TEXTURED)
		float2 uvM1 = i.uvM.xy;
		float2 uvM2 = i.uvM.zw;
	#endif
	
	#if defined(SDF_ALBEDOMAP)
		half4 m1AlbedoAlpha = tex2D(_AlbedoMap, uvM1) * color1;
		d.albedo = m1AlbedoAlpha.rgb;
		d.alpha = m1AlbedoAlpha.a;
	#else
		d.albedo = color1.rgb;
		d.alpha = color1.a;
	#endif
	
	#if defined(SDF_SPECULAR)
		#if defined(_SPECGLOSSMAP)
			d.specGloss = tex2D(_SpecGlossMap, uvM1);
		#else
			d.specGloss = half4(_Specular, _Glossiness);
		#endif
	#elif defined(SDF_METALLIC)
		#if defined(_METALLICGLOSSMAP)
			d.metallicGloss = tex2D(_MetallicGlossMap, uvM1).ra;
		#else
			d.metallicGloss = half2(_Metallic, _Glossiness);
		#endif
	#endif
	
	#if defined(_EMISSION) || defined(_EMISSIONMAP)
		d.emission = _EmissionColor;
		#if defined(_EMISSIONMAP)
			d.emission *= tex2D(_EmissionMap, uvM1);
		#endif
	#endif
	
	#if defined(_NORMALMAP)
		d.normal = UnpackScaleNormal(tex2D(_NormalMap, uvM1), _NormalScale);
	#endif
	
	#if defined(_CONTOUR2_ON)
		#if defined(SDF_ALBEDOTINT)
			color2 = _Color2;
		#endif
		#if defined(SDF_VERTEXCOLOR) && defined(_VERTEXCOLOR2_ON)
			color2 *= i.color;
		#endif
		
		#if defined(SDF_ALBEDOMAP)
			half4 m2AlbedoAlpha = tex2D(_AlbedoMap2, uvM2) * color2;
			d.albedo2 = m2AlbedoAlpha.rgb;
			d.alpha2 = m2AlbedoAlpha.a;
		#else
			d.albedo2 = color2.rgb;
			d.alpha2 = color2.a;
		#endif
		
		#if defined(SDF_SPECULAR)
			#if defined(_SPECGLOSSMAP2)
				d.specGloss2 = tex2D(_SpecGlossMap2, uvM2);
			#else
				d.specGloss2 = half4(_Specular2, _Glossiness2);
			#endif
		#elif defined(SDF_METALLIC)
			#if defined(_METALLICGLOSSMAP2)
				d.metallicGloss2 = tex2D(_MetallicGlossMap2, uvM2).ra;
			#else
				d.metallicGloss2 = half2(_Metallic2, _Glossiness2);
			#endif
		#endif
		
		#if defined(_EMISSION) || defined(_EMISSIONMAP)
			d.emission2 = _EmissionColor2;
			#if defined(_EMISSIONMAP)
				d.emission2 *= tex2D(_EmissionMap2, uvM2);
			#endif
		#endif
		
		#if defined(_NORMALMAP)
			d.normal2 = UnpackScaleNormal(tex2D(_NormalMap2, uvM2), _NormalScale2);
		#endif
	#endif
	
	return d;
}

struct SDFResult {
	half3 albedo;
	half alpha;
	half4 specGloss;
	half2 metallicGloss;
	half3 emission;
	half3 normal;
};

// Compute contour blend factors from SDF data and a distance.
half2 getBlendFactors (SDFData d, half distance) {
	bool smooth = true;
	#if (defined(SDF_META) || defined(SDF_SHADOW)) && !defined(SDF_SMOOTHING_MANUAL)
		smooth = false;
	#endif
	return SDFToolkitBlendFactors(float4(d.range, d.range2), distance, smooth);
}

// Interpolate SDF data.
SDFResult sampleColor (SDFData d, half2 t, bool outline) {
	SDFResult r;
	UNITY_INITIALIZE_OUTPUT(SDFResult, r);
	
	r.albedo = SDFToolkitBlend(d.albedo, d.albedo2, t, outline);
	r.alpha = SDFToolkitBlendAlpha(d.alpha, d.alpha2, t, outline);
	r.specGloss = SDFToolkitBlend(d.specGloss, d.specGloss2, t, outline);
	r.metallicGloss = SDFToolkitBlend(d.metallicGloss, d.metallicGloss2, t, outline);
	r.emission = SDFToolkitBlend(d.emission, d.emission2, t, outline);
	return r;
}

// Add another SDF result.
void AddSample (inout SDFResult r, SDFResult s, bool outline) {
	r.alpha += s.alpha;
	if (outline) {
		r.albedo += s.albedo;
		r.specGloss += s.specGloss;
		r.metallicGloss += s.metallicGloss;
		r.emission += s.emission;
	}
}

// Supersample SDF.
void supersample (SDFData d, inout SDFResult r, bool outline) {
	float4 distances = SDFToolkitSupersampleDistances(TEXTURE2D_ARGS(_MainTex, 0), d.uvSDF);
	
	// Blending entire samples produces much better results than only blending distance samples.
	AddSample(r, r, outline);
	AddSample(r, sampleColor(d, getBlendFactors(d, distances.x), outline), outline);
	AddSample(r, sampleColor(d, getBlendFactors(d, distances.y), outline), outline);
	AddSample(r, sampleColor(d, getBlendFactors(d, distances.z), outline), outline);
	AddSample(r, sampleColor(d, getBlendFactors(d, distances.w), outline), outline);
	
	half weight = 1.0 / 6.0;
	r.alpha *= weight;
	if (outline) {
		r.albedo *= weight;
		r.specGloss *= weight;
		r.metallicGloss *= weight;
		r.emission *= weight;
	}
}

SDFResult sampleSurface (SDFData d, half2 t, bool outline) {
	SDFResult r = sampleColor(d, t, outline);
	#if defined(SDF_SUPERSAMPLE)
		supersample(d, r, outline);
	#endif
	return r;
}

// Sample SDF normal data, including bevel.
void sampleNormal (SDFData d, inout SDFResult r, float2 t, bool outline, bool bevel) {
	r.normal = SDFToolkitBlendNormal(d.normal, d.normal2, t, outline);
	
	if (bevel) {
		float3 bevel = SDFToolkitBevel (
			TEXTURE2D_ARGS(_MainTex, 0), _MainTex_TexelSize.xy, d.uvSDF,
			_BevelScale, _BevelLow, _BevelHigh, _BevelLow2, _BevelHigh2
		);
		r.normal = BlendNormals(r.normal, bevel);
	}
}
