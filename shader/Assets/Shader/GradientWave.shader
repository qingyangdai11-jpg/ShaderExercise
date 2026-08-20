Shader "Unlit/GradientWave"
{
    Properties
    {
        _TopColor("Top Color",Color)=(1,0.5,0,1)
        _BottomColor("Bottom Color",Color) = (1,0.9,0.2,1)
        _Speed("Wave Speed",Range(0,10))=2.0
        _Alpha("Transparency",Range(0,1))=0.85
        _Ficker("Flicker Intensity",Range(0,1))=0.15

        _ScaleNum("Scale Density",Range(5,50))=15.0
        _ScaleThickness("Scale Thickness",Range(0.01,0.2))=0.05
        _ScaleOpacity("Scale Opacity",Range(0,1))=0.8

        // --- 顶点风吹微动 ---
        _WindSpeed("Wind Speed (风吹节奏)", Range(0, 20)) = 5.0
        _WindIntensity("Wind Intensity (鼓动幅度)", Range(0, 0.2)) = 0.02

        _NoiseScale("Paper Grain Scale (纸张颗粒密度)", Range(100, 1000)) = 500.0
        _NoiseIntensity("Paper Grain Intensity (颗粒明显度)", Range(0, 0.3)) = 0.08

        _RimColor("Rim Color (边缘发光颜色)", Color) = (1, 0.9, 0.5, 1)
        _RimPower("Rim Power (边缘发光范围)", Range(0.5, 8.0)) = 3.0
        _RimIntensity("Rim Intensity (边缘发光强度)", Range(0, 2.0)) = 0.8
    }
    SubShader
    {
        Tags {"Queue"="Transparent" "RenderType"="Transparent" }
        LOD 100
        
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float localY : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
            };

            fixed4 _TopColor;
            fixed4 _BottomColor;
            float _Speed;
            float _Alpha;
            float _Ficker;
            float _ScaleNum;
            float _ScaleThickness;
            float _ScaleOpacity;
            float _WindSpeed;
            float _WindIntensity;
            float _NoiseScale;
            float _NoiseIntensity;
            fixed4 _RimColor;
            float _RimPower;
            float _RimIntensity;

// 这是一个图形学界极其经典的伪随机数生成器
float random(float2 uv)
{
    return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453123);
}

v2f vert (appdata v)
            {
                v2f o;

                // 顶点物理形变逻辑保持不变
                float wind = sin(_Time.y * _WindSpeed + v.vertex.x * 5.0 + v.vertex.z * 3.0);
                float windMask = saturate(1.0 - abs(v.vertex.y * 2.0));
                v.vertex.xyz += v.normal * wind * _WindIntensity * windMask;
                o.pos = UnityObjectToClipPos(v.vertex);

                o.localY = v.vertex.y;
                o.uv=v.uv;

                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.viewDir = WorldSpaceViewDir(v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float normalizedY =i.localY+0.5;
                float wave = sin(_Time.y*_Speed-normalizedY*5.0)*0.5+0.5;
                fixed3 baseColor=lerp(_BottomColor.rgb, _TopColor.rgb, wave);

                float fickerNoise = sin(_Time.y*15.0)+sin(_Time.y*33.0)*0.5;
                float brightnessMultiplier =1.0-(fickerNoise*0.5+0.5)*_Ficker;
                fixed3 glowingColor = baseColor * brightnessMultiplier;

                float2 uv_scaled=i.uv * _ScaleNum;
                float2 uv1 = frac(uv_scaled) - 0.5;
                float2 uv2 = frac(uv_scaled + float2(0.5, 0.5)) - 0.5;
                
                float d1 = length(uv1);
                float d2 = length(uv2);

                float edge1 = abs(d1 - 0.5);
                float edge2 = abs(d2 - 0.5);

                float scaleMask = smoothstep(_ScaleThickness * 0.5, _ScaleThickness, min(edge1, edge2));

                fixed3 skeletonColor = baseColor * 0.4;
                fixed3 finalColor = lerp(skeletonColor, glowingColor, scaleMask);
                finalColor = lerp(glowingColor, finalColor, _ScaleOpacity);

                float grain = random(i.uv * _NoiseScale);
                finalColor *= (1.0 - grain * _NoiseIntensity);

                float3 N = normalize(i.worldNormal);
                float3 V = normalize(i.viewDir);
                float rim = 1.0 - saturate(dot(V, N));
                float rimPower = pow(rim, _RimPower);
                
                // 混合边缘光颜色并叠加到最终色彩上
                fixed3 rimLight = _RimColor.rgb * rimPower * _RimIntensity;
                finalColor += rimLight;

                return fixed4(finalColor,_Alpha);
            }
            ENDCG
        }
    }
}
