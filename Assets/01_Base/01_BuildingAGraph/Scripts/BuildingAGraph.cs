using System;
using System.Collections;
using System.Collections.Generic;
using System.Security.Cryptography;
using UnityEngine;

public class BuildingAGraph : MonoBehaviour
{
    [SerializeField]
    public Transform cube;

    [SerializeField,Range(10,200)]
    public int resolution;

    [SerializeField]
    public GraphLibrary.FunctionName FunctionName;

    public enum TransitionMode { Cycle, Random }
    [SerializeField]
    TransitionMode transitionMode;

    [SerializeField, Min(0f)]
    float functionDuration = 1f, transitionDuration = 1f;

    bool transitioning;

    GraphLibrary.FunctionName transitionFunction;
    private Transform[] points;
    float duration;
    private void Awake()
    {
        float step = 2f / resolution;
        var scale = Vector3.one * step;
        points = new Transform[resolution * resolution];
        for (int i = 0; i < points.Length; i++)
        {
            Transform point = Instantiate(cube);
            point.localScale = scale;
            point.SetParent(transform, false);
            points[i] = point;
        }
    }

    private void Update()
    {
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
        if (transitioning)
        {
            UpdateFunctionTransition();
        }
        else
        {
            UpdateFunction();
        }
    }
    void PickNextFunction()
    {
        FunctionName = transitionMode == TransitionMode.Cycle ?
            GraphLibrary.GetNextFunctionName(FunctionName) :
            GraphLibrary.GetRandomFunctionNameOtherThan(FunctionName);
    }
    void UpdateFunction()
    {
        GraphLibrary.Function f = GraphLibrary.GetFunction(FunctionName);
        float time = Time.time;
        float step = 2f / resolution;
        for (int i = 0, x = 0, z = 0; i < points.Length; i++, x++)
        {
            if (x == resolution)
            {
                x = 0;
                z += 1;
            }
            float u = (x + 0.5f) * step - 1f;
            float v = (z + 0.5f) * step - 1f;
            points[i].localPosition = f(u, v, time);
        }
    }
    void UpdateFunctionTransition()
    {
        GraphLibrary.Function
            from = GraphLibrary.GetFunction(transitionFunction),
            to = GraphLibrary.GetFunction(FunctionName);
        float progress = duration / transitionDuration;
        float time = Time.time;
        float step = 2f / resolution;
        for (int i = 0, x = 0, z = 0; i < points.Length; i++, x++)
        {
            if (x == resolution)
            {
                x = 0;
                z += 1;
            }
            float u = (x + 0.5f) * step - 1f;
            float v = (z + 0.5f) * step - 1f;
            points[i].localPosition = GraphLibrary.Morph(
                u, v, time, from, to, progress
            );
        }
    }
}
