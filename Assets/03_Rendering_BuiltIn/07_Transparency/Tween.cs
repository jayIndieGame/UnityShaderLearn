using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Tween : MonoBehaviour
{

    private MeshRenderer mr;

    private float alpha = 0;
    private Color red = Color.white;
    private bool upDown;
    // Start is called before the first frame update
    void Start()
    {
        upDown = true;
        mr = GetComponent<MeshRenderer>();
    }

    // Update is called once per frame
    void Update()
    {
        if (upDown)
        {
            alpha += Time.deltaTime * 0.5f;
            if(alpha>=1)
                upDown = !upDown;
        }
        else
        {
            alpha -= Time.deltaTime * 0.5f;
            if(alpha <= 0.0f)
                upDown = !upDown;
        }

        red.a = alpha;
        mr.material.SetColor("_Tint", red);
    }
}
