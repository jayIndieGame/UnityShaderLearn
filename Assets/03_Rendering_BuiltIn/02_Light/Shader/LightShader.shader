Shader "Custom/Light Shader"
{
    Properties
    {
        //_Tint ("Tint",Color) = (1,1,1,1)
        _MainTex ("Albedo", 2D) = "white" {}
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        //_SpecularTint ("Specular", Color) = (0.5, 0.5, 0.5)
        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
    }
    SubShader 
    {
        Pass 
        {
            CGPROGRAM
            #pragma target 3.0

            #pragma vertex LightingVertex
            #pragma fragment LightingFragment

            #include "UnityPBSLighting.cginc"

            //float4 _Tint;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            //float4 _SpecularTint;
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
            };

            Interpolators LightingVertex(VertexData v)
            {
                Interpolators i;
                i.uv = TRANSFORM_TEX(v.uv,_MainTex);
                i.position = UnityObjectToClipPos(v.position);
                i.worldPos = mul(unity_ObjectToWorld, v.position);
                i.normal = UnityObjectToWorldNormal(v.normal);
                return i; 
            }

            float4 LightingFragment(Interpolators i) : SV_TARGET
            {
                i.normal = normalize(i.normal);
                float3 lightDir = _WorldSpaceLightPos0.xyz;//光线方向
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);//相机坐标-着色点坐标
                //float3 halfVector = normalize(lightDir + viewDir);//半程向量
                float3 lightColor = _LightColor0.rgb;//光颜色

                float3 albedo = tex2D(_MainTex, i.uv).rgb;//反照颜色
                float3 specularTint = albedo * _Metallic;
                float oneMinusReflectivity = 1 - _Metallic;
                albedo = DiffuseAndSpecularFromMetallic(
                    albedo, _Metallic, specularTint, oneMinusReflectivity
                );

                //float3 diffuse = albedo * lightColor * saturate(dot(lightDir, i.normal));//漫反射项

                //float3 specular = specularTint * lightColor *
                //pow(saturate(dot(halfVector, i.normal)),_Smoothness * 100);//高光反射想
                //return float4(diffuse + specular , 1);
                UnityLight light;
                light.color = lightColor;
                light.dir = lightDir;
                light.ndotl = DotClamped(i.normal, lightDir);

                UnityIndirect indirectLight;
                indirectLight.diffuse = 0;
                indirectLight.specular = 0;


                return UNITY_BRDF_PBS(albedo, specularTint,
                    oneMinusReflectivity, _Smoothness,
                    i.normal, viewDir,light,indirectLight);
            }

            ENDCG

        }

    }
}