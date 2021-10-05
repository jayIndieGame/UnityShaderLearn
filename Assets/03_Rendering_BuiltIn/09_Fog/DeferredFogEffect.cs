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
        //����FrustumCorners
        deferredCamera.CalculateFrustumCorners(
            new Rect(0f, 0f, 1f, 1f),//�ü��ռ���ǿ��Ϊ1��������
            deferredCamera.farClipPlane,//��ȡԶƽ��
            deferredCamera.stereoActiveEye,
            frustumCorners
        );
        //CalculateFrustumCorners�����¡����ϡ����ϡ�����˳�����С�
        //Ȼ����������Ⱦͼ��Ч�����ı��εĽǶ����ǰ����½ǡ����½ǡ����Ͻǡ����Ͻ�˳�����еġ� 
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