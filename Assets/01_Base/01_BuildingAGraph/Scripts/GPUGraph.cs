using System;
using System.Collections;
using System.Collections.Generic;
using System.Security.Cryptography;
using UnityEngine;

public class GPUGraph : MonoBehaviour
{
    const int maxResolution = 1000;
    [SerializeField,Range(10, maxResolution)]
    public int resolution;

    [SerializeField]
    public GraphLibrary.FunctionName FunctionName;
    private ComputeBuffer positionsBuffer;
    public enum TransitionMode { Cycle, Random }

    [SerializeField]
    Material material;

    [SerializeField]
    Mesh mesh;

    [SerializeField]
    ComputeShader computeShader;
    [SerializeField]
    TransitionMode transitionMode;

    [SerializeField, Min(0f)]
    float functionDuration = 1f, transitionDuration = 1f;
    bool transitioning;
    GraphLibrary.FunctionName transitionFunction;
    float duration;

    static readonly int
        positionsId = Shader.PropertyToID("_Positions"),
        resolutionId = Shader.PropertyToID("_Resolution"),
        stepId = Shader.PropertyToID("_Step"),
        timeId = Shader.PropertyToID("_Time"),
        transitionProgressId = Shader.PropertyToID("_TransitionProgress");

    private void OnEnable()
    {
        positionsBuffer = new ComputeBuffer(maxResolution * maxResolution, 3*4);//ÿ��vector��3��float������3*4byte
    }
    private void OnDisable()
    {
        positionsBuffer.Dispose();
        positionsBuffer = null;
    }
    void UpdateFunctionOnGPU ()
    {
		float step = 2f / resolution;
		computeShader.SetInt(resolutionId, resolution);
		computeShader.SetFloat(stepId, step);
		computeShader.SetFloat(timeId, Time.time);
        if (transitioning)
        {
            computeShader.SetFloat(
                transitionProgressId,
                Mathf.SmoothStep(0f, 1f, duration / transitionDuration)
            );
        }

        //computeShader.SetBuffer(0, positionsId, positionsBuffer);
        var kernelIndex = (int)FunctionName + (int)(transitioning ? transitionFunction : FunctionName) * GraphLibrary.FunctionCount;//�����������������ںϡ�
        computeShader.SetBuffer(kernelIndex, positionsId, positionsBuffer);//�����kernalIndexһ��Ҫ��hlsl�е�һһ��Ӧ��

        int groups = Mathf.CeilToInt(resolution / 8f);
        computeShader.Dispatch(kernelIndex, groups, groups, 1);

        material.SetBuffer(positionsId, positionsBuffer);
        material.SetFloat(stepId, step);

        var bounds = new Bounds(Vector3.zero, Vector3.one * (2f + 2f / resolution));
        Graphics.DrawMeshInstancedProcedural(mesh, 0, material, bounds, resolution* resolution);

    }
    private void Update()
    {
        UpdateFunctionOnGPU();
        duration += Time.deltaTime;
        if (transitioning)
        {
            if (duration >= transitionDuration)
            {
                duration -= transitionDuration;
                transitioning = false;
            }
        }
        else if (duration >= functionDuration)
        {
            duration -= functionDuration;
            transitioning = true;
            transitionFunction = FunctionName;
            PickNextFunction();
        }
    }
    void PickNextFunction()
    {
        FunctionName = transitionMode == TransitionMode.Cycle ?
            GraphLibrary.GetNextFunctionName(FunctionName) :
            GraphLibrary.GetRandomFunctionNameOtherThan(FunctionName);
    }
}
