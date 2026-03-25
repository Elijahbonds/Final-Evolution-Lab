# Fascial Spiral Line — HLSL / Material Snippet (UE5)

Use this for a **Fascial Spiral Line** (Anatomy Trains–style) visualization: emissive flow along a spiral path with Fresnel rim and time-based pulse. Drop into a **Material Custom Expression** (HLSL) or adapt for a **Material Function** in Unreal Engine 5.

---

## 1. Custom Expression HLSL (single scalar output: Emissive intensity)

Create a **Material** (or Material Function), add a **Custom** node, set **Output Type** to **CMOT Float 1**, and paste the code below. Drive **Emissive** by multiplying your base color with this output.

```hlsl
// FascialSpiralLine_Emissive.hlsl
// Inputs (connect from Material): SpiralUV (float2), Time (float), Fresnel (float), PulseSpeed (float), FlowSharpness (float)

void FascialSpiralLine_Emissive(
    float2 SpiralUV,   // UV along spiral path (0..1 along length, 0..1 around)
    float Time,
    float Fresnel,     // 0 at center, 1 at rim (from Fresnel node)
    float PulseSpeed,  // e.g. 1.0
    float FlowSharpness, // e.g. 4.0 – how sharp the traveling wave
    out float OutEmissive
)
{
    // Traveling wave along spiral (neural signal flow)
    float flow = frac(SpiralUV.x - Time * PulseSpeed);
    float wave = pow(saturate(1.0 - abs(flow - 0.5) * 2.0), FlowSharpness);

    // Fresnel: stronger at rim (tissue boundary)
    float rim = pow(saturate(Fresnel), 1.5);

    // Combine: flow visibility + rim highlight
    OutEmissive = saturate(wave * 0.85 + rim * 0.4);
}
```

**Material setup (high level):**
- **SpiralUV**: from a **TextureCoordinate** or a **Panner** along your spiral mesh UVs (U = along path, V = around).
- **Time**: **Time** node.
- **Fresnel**: **Fresnel** material node (defaults fine; Exponent ~2).
- **PulseSpeed**: **ScalarParameter** (default 1.0).
- **FlowSharpness**: **ScalarParameter** (default 4.0).
- Multiply **OutEmissive** by your **Emissive Color** (e.g. cyan/blue for neural), then plug into **Emissive**.

---

## 2. Inline version (no Custom node): approximate in material graph

If you prefer not to use Custom HLSL:

1. **Fresnel** → Power (1.5) → multiply by 0.4 → **A**.
2. **Flow**: from **SpiralUV.x** subtract **Time × PulseSpeed**, then **Frac**. Subtract 0.5, absolute, multiply by 2, **OneMinus**, saturate, **Power** (4) → multiply by 0.85 → **B**.
3. **Add A + B** → saturate → multiply by **Emissive Color** → **Emissive**.

---

## 3. Optional: RGB flow tint (separate R/G/B for “signal type”)

For multiple spiral lines or signal types (e.g. parasympathetic vs sympathetic), use a **float3** output and drive R, G, B by different phases:

```hlsl
void FascialSpiralLine_EmissiveRGB(
    float2 SpiralUV,
    float Time,
    float Fresnel,
    float PulseSpeed,
    float3 TintR, float3 TintG, float3 TintB,  // e.g. (1,0,0), (0,1,0), (0,0,1)
    out float3 OutEmissiveRGB
)
{
    float flow = frac(SpiralUV.x - Time * PulseSpeed);
    float wave = pow(saturate(1.0 - abs(flow - 0.5) * 2.0), 4.0);
    float rim = pow(saturate(Fresnel), 1.5);
    float base = saturate(wave * 0.85 + rim * 0.4);

    // Phase offsets for R/G/B (0, 0.33, 0.66) give a traveling rainbow-style pulse
    float r = frac(flow);
    float g = frac(flow + 0.33);
    float b = frac(flow + 0.66);
    OutEmissiveRGB = base * (TintR * r + TintG * g + TintB * b);
}
```

Use **CMOT Float 3** and plug **OutEmissiveRGB** into **Emissive**.

---

## 4. Mesh / spline usage

- **Spline mesh**: Build the spiral path with a **Spline** in the level; use **Spline Mesh** or **Niagara Ribbon** to render the line. UVs should be set so **U** = 0→1 along the spline length.
- **Static mesh**: If the spiral is a static mesh, author UVs so **U** runs along the spiral and **V** around the tube; use the same **SpiralUV** in the material.

---

## 5. Niagara (alternative)

For a **particle ribbon** instead of a mesh:

- **Spawn**: along the same spiral spline (sample position at **U**).
- **Ribbon** renderer; **Color** and **Dynamic Material** driven by **Normalized Age** (0→1) and **Time** to replicate the same wave + Fresnel look in a particle material.

---

*UnrealStarter — Fascial Spiral Line shader for Vertical Velocity Academy / PS3-era visual pipeline.*
