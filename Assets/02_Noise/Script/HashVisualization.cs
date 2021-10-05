using System.Collections;
using System.Collections.Generic;
using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;
using UnityEngine;
using static  Unity.Mathematics.math;


public class HashVisualization : MonoBehaviour
{
    static Shapes.ScheduleDelegate[] shapeJobs = {
        Shapes.Job<Shapes.Plane>.ScheduleParallel,
        Shapes.Job<Shapes.Sphere>.ScheduleParallel,
        Shapes.Job<Shapes.Torus>.ScheduleParallel
    };

    [SerializeField]
    Shape shape;

    private static int
        hashesId = Shader.PropertyToID("_Hashes"),
        positionsId = Shader.PropertyToID("_Positions"),
        normalsId = Shader.PropertyToID("_Normals"),
        configId = Shader.PropertyToID("_Config");


    [SerializeField]
    Mesh instanceMesh;

    [SerializeField]
    Material material;

    [SerializeField, Range(1, 512)]
    int resolution = 16;

    public int seed;
    NativeArray<uint4> hashes;
    NativeArray<float3x4> positions, normals;
    bool isDirty;

    //[SerializeField, Range(-2f, 2f)]
    //float verticalOffset = 1f;

    [SerializeField, Range(-0.5f, 0.5f)]
    float displacement = 0.1f;

    [SerializeField]
    SpaceTRS domain = new SpaceTRS
    {
        scale = 8f
    };
    [SerializeField, Range(0.1f, 10f)]
    float instanceScale = 2f;

    ComputeBuffer hashesBuffer, positionsBuffer, normalsBuffer;

    MaterialPropertyBlock propertyBlock;
    Bounds bounds;
    void OnEnable()
    {
        isDirty = true;
        int length = resolution * resolution;
        length = length / 4 + (length & 1);
        hashes = new NativeArray<uint4>(length, Allocator.Persistent);
        positions = new NativeArray<float3x4>(length, Allocator.Persistent);
        normals = new NativeArray<float3x4>(length, Allocator.Persistent);
        hashesBuffer = new ComputeBuffer(length * 4, 4);
        positionsBuffer = new ComputeBuffer(length * 4, 3 * 4);
        normalsBuffer = new ComputeBuffer(length * 4, 3 * 4);
        //JobHandle handle = Shapes.Job.ScheduleParallel(positions, resolution, transform.localToWorldMatrix, default);
        //new HashJob
        //{
        //    hash = SmallXXHash.Seed(seed),
        //    hashes = hashes,
        //    domainTRS = domain.Matrix,
        //    positions = positions
        //}.ScheduleParallel(hashes.Length, resolution,  handle).Complete();

        //hashesBuffer.SetData(hashes);//每个ID不再是0-res*res而是个hash值。hlsl中的右移24位保证了剩下一个0-8位的数字即0-256之间
        //positionsBuffer.SetData(positions);
        propertyBlock ??= new MaterialPropertyBlock();

        propertyBlock.SetBuffer(hashesId, hashesBuffer);
        propertyBlock.SetBuffer(positionsId, positionsBuffer);
        propertyBlock.SetBuffer(normalsId, normalsBuffer);
        propertyBlock.SetVector(configId, new Vector4(resolution, instanceScale / resolution, displacement));//z为整体位移的比例

    }
    void OnDisable()
    {
        hashes.Dispose();
        positions.Dispose();
        normals.Dispose();
        hashesBuffer.Release();
        positionsBuffer.Release();
        normalsBuffer.Release();
        hashesBuffer = null;
        positionsBuffer = null;
        normalsBuffer.Release();
    }
    void OnValidate()
    {
        if (hashesBuffer != null && enabled)
        {
            OnDisable();
            OnEnable();
        }
    }
    void Update()
    {
        if (isDirty || transform.hasChanged)
        {
            isDirty = false;
            transform.hasChanged = false;
            JobHandle handle = shapeJobs[(int)shape](
                positions, normals,resolution, transform.localToWorldMatrix, default
            );//算position的

            new HashJob
            {
                positions = positions,
                hashes = hashes,
                hash = SmallXXHash.Seed(seed),
                domainTRS = domain.Matrix
            }.ScheduleParallel(hashes.Length, resolution, handle).Complete();//计算散列的，保证一块儿区域下得到同一个散列

            hashesBuffer.SetData(hashes.Reinterpret<uint>(4 * 4));
            positionsBuffer.SetData(positions.Reinterpret<float3>(3*4*4));
            normalsBuffer.SetData(normals.Reinterpret<float3>(3*4*4));
        }

        bounds = new Bounds(
            transform.position,
            float3(2f * cmax(abs(transform.lossyScale)) + displacement)
        );
        Graphics.DrawMeshInstancedProcedural(instanceMesh, 0, material, bounds, resolution * resolution, propertyBlock);
    }

    [BurstCompile(FloatPrecision.Standard, FloatMode.Fast, CompileSynchronously = true)]
    struct HashJob : IJobFor
    {
        //public int resolution;
        public SmallXXHash4 hash;
        //public float invResolution;
        public float3x4 domainTRS;
        [WriteOnly]
        public NativeArray<uint4> hashes;
        [ReadOnly]
        public NativeArray<float3x4> positions;

        public void Execute(int i)
        {
            #region 以下代码如果直接做除法，会因为数据的精确度在4×4的范围内获得同一个值，从而取到同一个hash。最后显示起来就像分辨率/4了一样。
            //int v = (int)floor(invResolution * i + 0.00001f);
            //int u = i - resolution * v - resolution / 2;//仅仅是为了展示负数也能用
            //v -= resolution / 2;

            //v /= 4;
            //u /= 4;
            #endregion

            //float vf = math.floor(invResolution * i + 0.00001f);
            //float uf = invResolution * (i - resolution * vf + 0.5f) - 0.5f;
            //vf = invResolution * (vf + 0.5f) - 0.5f;

            //float3 p = math.mul(domainTRS, math.float4(positions[i], 1f)); ;//相当于给uf，vf这个矩阵调整基向量。

            float4x3 p = TransformPositions(domainTRS, transpose(positions[i]));

            int4 u = (int4)math.floor(p.c0);
            int4 v = (int4)math.floor(p.c1);
            int4 w = (int4)math.floor(p.c2);


            hashes[i] = hash.Eat(u).Eat(v).Eat(w);//指根据那些变量生成hash。如果两个方块具有相同的u，v，w则具有相同的hash
        }

        float4x3 TransformPositions(float3x4 trs, float4x3 p) => float4x3(
            trs.c0.x * p.c0 + trs.c1.x * p.c1 + trs.c2.x * p.c2 + trs.c3.x,
            trs.c0.y * p.c0 + trs.c1.y * p.c1 + trs.c2.y * p.c2 + trs.c3.y,
            trs.c0.z * p.c0 + trs.c1.z * p.c1 + trs.c2.z * p.c2 + trs.c3.z
        );
    }
    public readonly struct SmallXXHash//整体是xxhash的算法。
    {

        const uint primeA = 0b10011110001101110111100110110001;
        const uint primeB = 0b10000101111010111100101001110111;
        const uint primeC = 0b11000010101100101010111000111101;
        const uint primeD = 0b00100111110101001110101100101111;
        const uint primeE = 0b00010110010101100110011110110001;

        readonly uint accumulator;

        public SmallXXHash(uint accumulator)
        {
            this.accumulator = accumulator;
        }
        public static SmallXXHash Seed(int seed) => (uint)seed + primeE;
        public SmallXXHash Eat(int data) =>
            RotateLeft(accumulator + (uint)data * primeC, 17) * primeD;
        public SmallXXHash Eat(byte data) =>
            RotateLeft(accumulator + data * primeE, 11) * primeA;
        static uint RotateLeft(uint data, int steps) =>
            (data << steps) | (data >> 32 - steps);//就是超过32位能表示的最大数字后，会丢失数据，所以通过右移把数字补上

        public static implicit operator uint(SmallXXHash hash)
        {
            uint avalanche = hash.accumulator;
            avalanche ^= avalanche >> 15;
            avalanche *= primeB;
            avalanche ^= avalanche >> 13;
            avalanche *= primeC;
            avalanche ^= avalanche >> 16;
            return avalanche;
        }
        public static implicit operator SmallXXHash(uint accumulator) =>
            new SmallXXHash(accumulator);
        public static implicit operator SmallXXHash4(SmallXXHash hash) =>
            new SmallXXHash4(hash.accumulator);
    }

    public readonly struct SmallXXHash4 {
        const uint primeA = 0b10011110001101110111100110110001;
        const uint primeB = 0b10000101111010111100101001110111;
        const uint primeC = 0b11000010101100101010111000111101;
        const uint primeD = 0b00100111110101001110101100101111;
        const uint primeE = 0b00010110010101100110011110110001;

        readonly uint4 accumulator;

        public SmallXXHash4(uint4 accumulator)
        {
            this.accumulator = accumulator;
        }
        public static SmallXXHash4 Seed(int4 seed) => (uint4)seed + primeE;
        public SmallXXHash4 Eat(int4 data) =>
            RotateLeft(accumulator + (uint4)data * primeC, 17) * primeD;
        static uint4 RotateLeft(uint4 data, int steps) =>
            (data << steps) | (data >> 32 - steps);//就是超过32位能表示的最大数字后，会丢失数据，所以通过右移把数字补上

        public static implicit operator uint4(SmallXXHash4 hash)
        {
            uint4 avalanche = hash.accumulator;
            avalanche ^= avalanche >> 15;
            avalanche *= primeB;
            avalanche ^= avalanche >> 13;
            avalanche *= primeC;
            avalanche ^= avalanche >> 16;
            return avalanche;
        }

        public static implicit operator SmallXXHash4(uint4 accumulator) =>
            new SmallXXHash4(accumulator);

    }
    [System.Serializable]
    public struct SpaceTRS
    {
        public float3 translation, rotation, scale;

        public float3x4 Matrix
        {
            get
            {
                float4x4 m = Unity.Mathematics.float4x4.TRS(
                    translation, Unity.Mathematics.quaternion.EulerZXY(math.radians(rotation)), scale
                );
                return math.float3x4(m.c0.xyz, m.c1.xyz, m.c2.xyz, m.c3.xyz);
            }
        }
    }
}