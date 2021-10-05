#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

float4 _Tint;
sampler2D _MainTex;
float4 _MainTex_ST;

float _Metallic;
float _Smoothness;

struct VertexData
{
    float4 position : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0; 
};
struct Interpolators
{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;
    float3 worldPos : TEXCOORD2;

    #if defined(VERTEXLIGHT_ON)
        float3 vertexLightColor : TEXCOORD3;
    #endif
};
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
UnityIndirect CreateIndirectLight (Interpolators i) {
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    #if defined(VERTEXLIGHT_ON)
        indirectLight.diffuse = i.vertexLightColor;
    #endif
    #if defined(FORWARD_BASE_PASS)
        indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
    #endif
    return indirectLight;
}
UnityLight CreateLight(Interpolators i){
    UnityLight light;
    #if defined(POINT) || defined(SPOT)
        light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
    #else
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif
    UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos);
    light.color = _LightColor0.rgb * attenuation;
    light.ndotl = DotClamped(i.normal, light.dir);
    return light;
}
Interpolators LightingVertex(VertexData v)
{
    Interpolators i;
    i.uv = TRANSFORM_TEX(v.uv,_MainTex);
    i.position = UnityObjectToClipPos(v.position);
    i.worldPos = mul(unity_ObjectToWorld, v.position);
    i.normal = UnityObjectToWorldNormal(v.normal);
    ComputeVertexLightColor(i);
    return i; 
}

float4 LightingFragment(Interpolators i) : SV_TARGET
{
    i.normal = normalize(i.normal);
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);//相机坐标-着色点坐标
    float3 albedo = tex2D(_MainTex, i.uv).rgb;//反照颜色
    float3 specularTint = albedo * _Metallic;
    float oneMinusReflectivity = 1 - _Metallic;
    albedo = DiffuseAndSpecularFromMetallic(
        albedo, _Metallic, specularTint, oneMinusReflectivity
    );

    return UNITY_BRDF_PBS(albedo, specularTint,
        oneMinusReflectivity, _Smoothness,
        i.normal, viewDir,CreateLight(i),CreateIndirectLight(i));
}


#endif