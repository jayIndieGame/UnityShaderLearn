using System;
using UnityEngine;

[ExecuteInEditMode]
public class DeferredFogEffect : MonoBehaviour
{
    [NonSerialized]
    Camera deferredCamera;

    [NonSerialized]
    Vector3[] frustumCorners;

    public Shader deferredFog;

    [NonSerialized]
    Vector4[] vectorArray;

    [NonSerialized]
    Material fogMaterial;
    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (fogMaterial == null)
        {
            deferredCamera = GetComponent<Camera>();
            frustumCorners = new Vector3[4];
            vectorArray = new Vector4[4];
            fogMaterial = new Material(deferredFog);
        }
        //计算FrustumCorners
        deferredCamera.CalculateFrustumCorners(
            new Rect(0f, 0f, 1f, 1f),//裁剪空间就是宽高为1的正方形
            deferredCamera.farClipPlane,//获取远平面
            deferredCamera.stereoActiveEye,
            frustumCorners
        );
        //CalculateFrustumCorners按左下、左上、右上、右下顺序排列。
        //然而，用于渲染图像效果的四边形的角顶点是按左下角、右下角、左上角、右上角顺序排列的。 
        vectorArray[0] = frustumCorners[0];
        vectorArray[1] = frustumCorners[3];
        vectorArray[2] = frustumCorners[1];
        vectorArray[3] = frustumCorners[2];

        foreach (var arr in frustumCorners)
        {
            Debug.Log(arr);
        }

        fogMaterial.SetVectorArray("_FrustumCorners", vectorArray);


        Graphics.Blit(source, destination, fogMaterial);
    }
}