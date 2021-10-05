#if !defined(MY_LIGHTING_INCLUDED_BUMPINESS)
#define MY_LIGHTING_INCLUDED_BUMPINESS

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    #if !defined(FOG_DISTANCE)
        #define FOG_DEPTH 1
    #endif
    #define FOG_ON 1
#endif

float4 _Tint;//自身颜色
float _AlphaClip;

sampler2D _MainTex,_DetailTex, _DetailMask;//主纹理
float4 _MainTex_ST,_DetailTex_ST;//主纹理平移缩放

sampler2D _NormalMap,_DetailNormalMap;
float _BumpScale,_DetailBumpScale;

float _Metallic;//金属度
float _Smoothness;//平滑程度
sampler2D _MetallicMap;

sampler2D _EmissionMap;
float3 _Emission;

sampler2D _OcclusionMap;
float _OcclusionStrength;

//顶点着色器使用的入参
struct VertexData
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0; 
};

//片元着色器使用的入参
struct Interpolators
{
    float4 pos : SV_POSITION;
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;

    #if defined(BINORMAL_PER_FRAGMENT)
    float4 tangent : TEXCOORD2;
    #else
    float3 tangent : TEXTCOORD2;
    float3 binormal : TEXTCOORD3;
    #endif
    #if FOG_DEPTH
        float4 worldPos : TEXCOORD4;
    #else
        float3 worldPos : TEXCOORD4;
    #endif

    SHADOW_COORDS(5)

    #if defined(VERTEXLIGHT_ON)
        float3 vertexLightColor : TEXCOORD6;
    #endif
};


struct FragmentOutput {
    #if defined(DEFERRED_PASS)
        float4 gBuffer0 : SV_TARGET0;
        float4 gBuffer1 : SV_TARGET1;
        float4 gBuffer2 : SV_TARGET2;
        float4 gBuffer3 : SV_TARGET3;
    #else
        float4 color : SV_TARGET;
    #endif
};

//获得金属贴图R通道
float GetMetallic (Interpolators i) {
    #if defined(_METALLIC_MAP)
        return tex2D(_MetallicMap, i.uv.xy).r;
    #else
        return _Metallic;
    #endif
}

//从金属贴图中获得平滑度a通道
float GetSmoothness (Interpolators i) {
    float smoothness = 1;
    #if defined(_SMOOTHNESS_ALBEDO)
        smoothness = tex2D(_MainTex, i.uv.xy).a;
    #elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)
        smoothness = tex2D(_MetallicMap, i.uv.xy).a;
    #endif
    return smoothness * _Smoothness;
}


float GetOcclusion(Interpolators i)
{
    #if defined(_OCCLUSION_MAP)
        return lerp(1, tex2D(_OcclusionMap, i.uv.xy).g, _OcclusionStrength);
    #else
        return 1;
    #endif
}

//添加自发光
float3 GetEmission (Interpolators i) {
    #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
        #if defined(_EMISSION_MAP)
            return tex2D(_EmissionMap, i.uv.xy) * _Emission;
        #else
            return _Emission;
        #endif
    #else
        return 0;
    #endif
}

//添加Alpha
float GetAlpha (Interpolators i) {
    float alpha = _Tint.a;
    #if !defined(_SMOOTHNESS_ALBEDO)
        alpha *= tex2D(_MainTex,i.uv.xy).a;
    #endif
    return alpha;
}

//添加Mask
float GetDetailMask (Interpolators i) {
    #if defined (_DETAIL_MASK)
        return tex2D(_DetailMask, i.uv.xy).a;
    #else
        return 1;
    #endif
}

float3 GetAlbedo (Interpolators i) {
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
    #if defined (_DETAIL_ALBEDO_MAP)
    float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
    albedo = lerp(albedo, albedo * details, GetDetailMask(i));
    #endif
    return albedo;
}

float3 GetTangentSpaceNormal (Interpolators i) {
    float3 normal = float3(0, 0, 1);
    #if defined(_NORMAL_MAP)
        normal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
    #endif
    #if defined(_DETAIL_NORMAL_MAP)
        float3 detailNormal =
            UnpackScaleNormal(
                tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale
            );
        detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));
        normal = BlendNormals(normal, detailNormal);
    #endif
    return normal;
}

//计算顶点光照，参数是顶点着色器中返回的参数。
void ComputeVertexLightColor (inout Interpolators i) {
    #if defined(VERTEXLIGHT_ON)
        i.vertexLightColor = Shade4PointLights(
            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
            unity_LightColor[0].rgb, unity_LightColor[1].rgb,
            unity_LightColor[2].rgb, unity_LightColor[3].rgb,
            unity_4LightAtten0, i.worldPos, i.normal
        );
    #endif
}

float3 BoxProjection (float3 direction, float3 position,float4 cubemapPosition, float3 boxMin, float3 boxMax) {
#if UNITY_SPECCUBE_BOX_PROJECTION
    UNITY_BRANCH
    if (cubemapPosition.w > 0) {
        float3 factors =
            ((direction > 0 ? boxMax : boxMin) - position) / direction;
        float scalar = min(min(factors.x, factors.y), factors.z);
        direction = direction * scalar + (position - cubemapPosition);
    }
#endif
    return direction;
}



//计算副法线
float3 CreateBinormal (float3 normal, float3 tangent, float binormalSign) {
    return cross(normal, tangent.xyz) *
        (binormalSign * unity_WorldTransformParams.w);
}

//初始化片元法线
void InitializeFragmentNormal(inout Interpolators i) {
    float3 tangentSpaceNormal = GetTangentSpaceNormal(i);

    #if defined(BINORMAL_PER_FRAGMENT)
        float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
    #else
        float3 binormal = i.binormal;
    #endif

    i.normal = normalize(
        tangentSpaceNormal.x * i.tangent +
        tangentSpaceNormal.y * binormal +
        tangentSpaceNormal.z * i.normal
    );
}

//根据凹凸贴图更改法线
//void InitializeFragmentNormalFromHeight(inout Interpolators i)
//{
//    float2 du = float2(_HeightMap_TexelSize.x * 0.5, 0);
//    float u1 = tex2D(_HeightMap, i.uv - du);
//    float u2 = tex2D(_HeightMap, i.uv + du);
//
//    float2 dv = float2(0, _HeightMap_TexelSize.y * 0.5);
//    float v1 = tex2D(_HeightMap, i.uv - dv);
//    float v2 = tex2D(_HeightMap, i.uv + dv);
//
//    i.normal = float3(u1 - u2, 1, v1 - v2);
//
//    i.normal = normalize(i.normal);
//}

float4 ApplyFog (float4 color, Interpolators i) {
    #if FOG_ON
    float viewDistance = length(_WorldSpaceCameraPos - i.worldPos);
    #if FOG_DEPTH
        viewDistance = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.worldPos.w);
    #endif
    UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
    float3 fogColor = 0;
    #if defined(FORWARD_BASE_PASS)
        fogColor = unity_FogColor.rgb;
    #endif
    color.rgb = lerp(fogColor, color.rgb, saturate(unityFogFactor));
    #endif
    return color;
}

//创建直接光。参数是顶点着色器中返回的参数，其中只定义了POINT和SPOT，如果需要Cooik需要手动添加
UnityLight CreateLight(Interpolators i){
    UnityLight light;
    #if defined(DEFERRED_PASS)
        light.dir = float3(0, 1, 0);
        light.color = 0;
    #else
        #if defined(POINT) || defined(SPOT)
            light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
        #else
            light.dir = _WorldSpaceLightPos0.xyz;
        #endif

        #if defined(SHADOWS_SCREEN)
            float attenuation = SHADOW_ATTENUATION(i);
        #else
            UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
        #endif
    
        light.color = _LightColor0.rgb * attenuation;
    #endif
    //light.ndotl = DotClamped(i.normal, light.dir);//这个写不写无所谓，实时算的
    return light;
}

//创建间接光，参数是顶点着色器中返回的参数。其中包含球谐函数和顶点光照着色
UnityIndirect CreateIndirectLight (Interpolators i,float3 viewDir) {
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    #if defined(VERTEXLIGHT_ON)
        indirectLight.diffuse = i.vertexLightColor;
    #endif
    #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
        indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
        float3 reflectionDir = reflect(-viewDir,i.normal);
        Unity_GlossyEnvironmentData envData;
        envData.roughness = 1 - GetSmoothness(i);
        envData.reflUVW = BoxProjection(
            reflectionDir, i.worldPos,
            unity_SpecCube0_ProbePosition,
            unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
        );
        float3 probe0 = Unity_GlossyEnvironment(
            UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
        );
        envData.reflUVW = BoxProjection(
            reflectionDir, i.worldPos,
            unity_SpecCube1_ProbePosition,
            unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
        );
        #if UNITY_SPECCUBE_BLENDING
            float interpolator = unity_SpecCube0_BoxMin.w;
            UNITY_BRANCH
            if (interpolator < 0.99999) {
                float3 probe1 = Unity_GlossyEnvironment(
                UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0), unity_SpecCube1_HDR, envData);
                indirectLight.specular = lerp(probe1, probe0, interpolator);
             }
            else {
                indirectLight.specular = probe0;
            }
        #else
            #if defined(DEFERRED_PASS) && UNITY_ENABLE_REFLECTION_BUFFERS
                indirectLight.specular = 0;
            #endif
        #endif
        float occlusion = GetOcclusion(i);
        indirectLight.diffuse *= occlusion;
        indirectLight.specular *= occlusion;
    #endif

    return indirectLight;
}

//顶点着色器，基本变量计算
Interpolators LightingVertex(VertexData v)
{
    Interpolators i;
    i.uv.xy = TRANSFORM_TEX(v.uv,_MainTex);
    i.uv.zw = TRANSFORM_TEX(v.uv,_DetailTex);
    i.pos = UnityObjectToClipPos(v.vertex);
    i.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);
    #if FOG_DEPTH
        i.worldPos.w = i.pos.z;
    #endif
    i.normal = UnityObjectToWorldNormal(v.normal);
    
    #if defined(BINORMAL_PER_FRAGMENT)
    i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
    #else
    i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
    i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
    #endif
    
    TRANSFER_SHADOW(i);
    
    ComputeVertexLightColor(i);
    return i; 
}

//片元着色器，应用BRDF计算。
FragmentOutput LightingFragment(Interpolators i)
{
    float alpha = GetAlpha(i);
    #if defined(_RENDERING_CUTOUT)
        clip(alpha - _AlphaClip);
    #endif

    InitializeFragmentNormal(i);

    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);//相机坐标-着色点坐标

    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb;//反照颜色
    albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
    
    float3 specularTint = albedo * _Metallic;//高光着色

    float oneMinusReflectivity = 1 - _Metallic;
    albedo = DiffuseAndSpecularFromMetallic(
        GetAlbedo(i), GetMetallic(i), specularTint, oneMinusReflectivity
    );//漫反射着色
    #if defined(_RENDERING_TRANSPARENT)
        albedo *= alpha;
        alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
    #endif
    float4 color = UNITY_BRDF_PBS(albedo, specularTint,
        oneMinusReflectivity, GetSmoothness(i),
        i.normal, viewDir,CreateLight(i),CreateIndirectLight(i,viewDir));
    color.rgb += GetEmission(i);//添加自发光
    #if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
        color.a = alpha;
    #endif
    FragmentOutput output;
    #if defined(DEFERRED_PASS)
        #if !defined(UNITY_HDR_ON)
            color.rgb = exp2(-color.rgb);
        #endif
        output.gBuffer0.rgb = albedo;
        output.gBuffer0.a = GetOcclusion(i);
        output.gBuffer1.rgb = specularTint;
        output.gBuffer1.a = GetSmoothness(i);
        output.gBuffer2 = float4(i.normal * 0.5 + 0.5, 1);
        output.gBuffer3 = color;
    #else
        output.color = ApplyFog(color, i);
    #endif
    return output;
}


#endif

