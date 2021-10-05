/*
 * Copyright 2020, Catlike Coding
 * http://catlikecoding.com
 */

#ifndef SDF_TOOLKIT_INCLUDED
#define SDF_TOOLKIT_INCLUDED

// Define the below macro before including this file to overrule the sampling function.
#if !defined(SDF_TOOLKIT_SAMPLE_DISTANCE)
	#define SDF_TOOLKIT_SAMPLE_DISTANCE SDFToolkitSampleDistance
#endif

#if !defined(SAMPLE_TEXTURE2D)
	// If SAMPLE_TEXTURE2D is not defined assume GLSLPROGRAM.
	// Define own texture macros, same as GLES2.hlsl of Core RP Library.
	#define SAMPLE_TEXTURE2D(textureName, samplerName, coord2) tex2D(textureName, coord2)
	#define TEXTURE2D_PARAM(textureName, samplerName) sampler2D textureName
	#define TEXTURE2D_ARGS(textureName, samplerName) textureName
	#if (SHADER_TARGET >= 30)
		#define SAMPLE_TEXTURE2D_LOD(textureName, samplerName, coord2, lod)\
			tex2Dlod(textureName, float4(coord2, 0, lod))
	#else
		// No tex2Dlod support. Texture should not have mipmaps.
		#define SAMPLE_TEXTURE2D_LOD(textureName, samplerName, coord2, lod)\
			tex2D(textureName, coord2)
	#endif
#endif

// Sample SDF texture to get a distance measure. Can be overruled.
float SDFToolkitSampleDistance (
	TEXTURE2D_PARAM(sdfTexture, sdfSampler), float2 uv, bool supersample
) {
	if (supersample) {
		// Shouldn't use mipmaps when supersampling.
		return SAMPLE_TEXTURE2D_LOD(sdfTexture, sdfSampler, uv, 0).a;
	}
	else {
		return SAMPLE_TEXTURE2D(sdfTexture, sdfSampler, uv).a;
	}
}

float4 SDFToolkitSupersampleDistances (
	TEXTURE2D_PARAM(sdfTexture, sdfSampler), float2 uv
) {
	float2 deltaUV = 0.3535534 * (ddx(uv) + ddy(uv));
	float4 boxUV = float4(uv + deltaUV, uv - deltaUV);
	return float4(
		SDF_TOOLKIT_SAMPLE_DISTANCE(TEXTURE2D_ARGS(sdfTexture, sdfSampler), boxUV.xy, true),
		SDF_TOOLKIT_SAMPLE_DISTANCE(TEXTURE2D_ARGS(sdfTexture, sdfSampler), boxUV.xw, true),
		SDF_TOOLKIT_SAMPLE_DISTANCE(TEXTURE2D_ARGS(sdfTexture, sdfSampler), boxUV.zy, true),
		SDF_TOOLKIT_SAMPLE_DISTANCE(TEXTURE2D_ARGS(sdfTexture, sdfSampler), boxUV.zw, true)
	);
}

// Compute contour blend factors from SDF data and a distance.
half2 SDFToolkitBlendFactors (half4 ranges, half distance, bool smooth) {
	half2 bf;
	if (smooth) {
		bf.x = smoothstep(ranges.x, ranges.y, distance);
		bf.y = smoothstep(ranges.z, ranges.w, distance);
	}
	else {
		bf.x = step(ranges.x, distance);
		bf.y = step(ranges.z, distance);
	}
	return bf;
}

half4 SDFToolkitBlend(half4 inner, half4 outer, half2 t, bool outline) {
	return outline ? lerp(outer, inner, t.x) : inner;
}

half3 SDFToolkitBlend(half3 inner, half3 outer, half2 t, bool outline) {
	return outline ? lerp(outer, inner, t.x) : inner;
}

half2 SDFToolkitBlend(half2 inner, half2 outer, half2 t, bool outline) {
	return outline ? lerp(outer, inner, t.x) : inner;
}

half SDFToolkitBlend(half inner, half outer, half2 t, bool outline) {
	return outline ? lerp(outer, inner, t.x) : inner;
}

half SDFToolkitBlendAlpha(half inner, half outer, half2 t, bool outline) {
	return outline ? lerp(outer, inner, t.x) * t.y : inner * t.x;
}

float3 SDFToolkitBlendNormal(float3 inner, float3 outer, half2 t, bool outline) {
	return outline ? lerp(outer, inner, t.x) : inner;
}

bool SDFToolkitIsShaderGraphShadow () {
	#if defined(UNITY_PASS_SHADOWCASTER)
		return true;
	#else
		return false;
	#endif
}


float3 SDFToolkitBevel (
	TEXTURE2D_PARAM(sdfTexture, sdfSampler), float2 sdfTexelSize, float2 uv,
	float bevelScale, float bevelLow, float bevelHigh, float bevelLow2, float bevelHigh2
) {
	// Using 2-pixel offset to smooth out precision terracing due to 8-bit precision of texture samples.
	float3 uvOffset = float3(sdfTexelSize.x, sdfTexelSize.y, 0) * 2;
	float4 uvA = uv.xyxy - uvOffset.xzzy;
	float4 uvB = uv.xyxy + uvOffset.xzzy;
	float4 crossSamples = float4(
		SDF_TOOLKIT_SAMPLE_DISTANCE(TEXTURE2D_ARGS(sdfTexture, sdfSampler), uvA.xy, false), // left
		SDF_TOOLKIT_SAMPLE_DISTANCE(TEXTURE2D_ARGS(sdfTexture, sdfSampler), uvB.xy, false), // right
		SDF_TOOLKIT_SAMPLE_DISTANCE(TEXTURE2D_ARGS(sdfTexture, sdfSampler), uvA.zw, false), // bottom
		SDF_TOOLKIT_SAMPLE_DISTANCE(TEXTURE2D_ARGS(sdfTexture, sdfSampler), uvB.zw, false) // top
	);
		
	// Perform manual smoothstep.
	float4 heights = saturate((crossSamples - bevelLow) / (bevelHigh - bevelLow));
	heights = heights * heights * (3.0 - (2.0 * heights));
	
	if (bevelLow2 != bevelHigh2) {
		float4 heights2 = saturate((crossSamples - bevelLow2) / (bevelHigh2 - bevelLow2));
		heights += heights2 * heights2 * (3.0 - (2.0 * heights2));
	}
		
	float2 heightData = (heights.xz - heights.yw) * bevelScale * sdfTexelSize.yx;
		
	// Derivation of bevel normal computation.
		
	// lhs = (sdfTexelSize.x, 0, heights.y - heights.x)
	// rhs = (0, sdfTexelSize.y, heights.w - heights.z)
		
	// cross product
	// lhs.y * rhs.z - lhs.z * rhs.y,
	// lhs.z * rhs.x - lhs.x * rhs.z,
	// lhs.x * rhs.y - lhs.y * rhs.x
		
	// 0 * (heights.w - heights.z) - (heights.y - heights.x) * sdfTexelSize.y,
	// (heights.y - heights.x) * 0 - sdfTexelSize.x * (heights.w - heights.z),
	// _MainTex_TexelSize.x * _MainTex_TexelSize.y - 0 * 0
		
	// (heights.x - heights.y) * sdfTexelSize.y,
	// (heights.z - heights.w) * sdfTexelSize.x,
	// sdfTexelSize.x * sdfTexelSize.y
		
	return normalize(float3(heightData.x, heightData.y, sdfTexelSize.x * sdfTexelSize.y * 4.0));
}

#endif