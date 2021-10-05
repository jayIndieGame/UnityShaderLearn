/*
 * Copyright 2015, Catlike Coding
 * http://catlikecoding.com
 */

#include "SDF.cginc"

SDF_DECLARE_CLIP_RECT;

v2fSDF vert (VertexInput v) {
	v2fSDF o = CreateV2FSDF(v);
	o.pos = UnityObjectToClipPos(v.vertex);
	SDF_UI_RECT_CLIP_TRANSFER(o,v)
	return o;
}

float4 frag (v2fSDF f) : SV_Target {
	SDF_UI_RECT_CLIP(f)

	bool outline = false;
	#if defined(_CONTOUR2_ON)
		outline = true;
	#endif
	
	SDFData d = FillData(f);
	SDFResult r = sampleSurface(d, getBlendFactors(d, d.distance), outline);
	#if defined(SDF_SUPERSAMPLE)
		supersample(d, r, outline);
	#endif
	#if defined(_ALPHATEST_ON)
		clip(r.alpha - _Cutoff);
		r.alpha = 1;
	#endif
	return float4(r.albedo, r.alpha);
}
