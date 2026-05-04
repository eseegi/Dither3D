/*
 * Dither3D Cutout Shader for s&box
 * Ported from Unity Dither3D by Rune Skovbo Johansen
 * 
 * This shader applies surface-stable fractal dithering to cutout (alpha-tested) surfaces.
 * Similar to the opaque shader but with alpha testing for transparent textures like foliage.
 * 
 * SHADER PERMUTATIONS (define these when compiling):
 * - DITHERCOL_GRAYSCALE: Convert to grayscale dithering
 * - DITHERCOL_RGB: Separate RGB channel dithering
 * - DITHERCOL_CMYK: CMYK printing-style dithering with angled screens
 * - INVERSE_DOTS: Invert the dot pattern
 * - RADIAL_COMPENSATION: Compensate for radial distortion at screen edges
 * - QUANTIZE_LAYERS: Use discrete layers instead of interpolated
 * - DEBUG_FRACTAL: Visualize the fractal UV coordinates
 */

#include "dither3d_common.hlsl"

// Material parameters
Texture2D<float4> _MainTex;
Texture2D<float4> _BumpMap;
Texture2D<float4> _EmissionMap;
SamplerState sampler_MainTex;
SamplerState sampler_BumpMap;

cbuffer MaterialParams : register(b0)
{
    float4 _Color;              // Tint color
    float4 _EmissionColor;      // Emission color
    float _Glossiness;          // Smoothness (0-1)
    float _Metallic;            // Metallic (0-1)
    float _Cutoff;              // Alpha cutoff threshold (0-1)
};

// Vertex shader input structure
struct VertexInput
{
    float4 vertex : POSITION;
    float2 uv0 : TEXCOORD0;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
};

// Vertex shader output / Pixel shader input
struct PixelInput
{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 uv_emission : TEXCOORD1;
    float2 uv_normal : TEXCOORD2;
    float4 screenPos : TEXCOORD3;
    float3 worldNormal : TEXCOORD4;
    float3 worldPosition : TEXCOORD5;
};

// Vertex Shader
PixelInput VertexShader(VertexInput input)
{
    PixelInput output = (PixelInput)0;
    
    // Transform vertex to clip space
    // NOTE: Replace UNITY_MATRIX_MVP with s&box's transformation system
    output.position = mul(UNITY_MATRIX_MVP, input.vertex);
    
    // Pass through UVs
    output.uv = input.uv0;
    output.uv_emission = input.uv0;
    output.uv_normal = input.uv0;
    
    // Calculate screen position for dithering
    output.screenPos = output.position;
    
    // Transform normal to world space
    // NOTE: Replace UNITY_MATRIX_IT_MV with s&box equivalent
    output.worldNormal = normalize(mul((float3x3)UNITY_MATRIX_IT_MV, input.normal));
    
    // World position
    // NOTE: Replace UNITY_MATRIX_M with s&box equivalent
    output.worldPosition = mul(UNITY_MATRIX_M, input.vertex).xyz;
    
    return output;
}

// Pixel Shader
float4 PixelShader(PixelInput input) : SV_Target
{
    // Sample base texture
    float4 albedo = _MainTex.Sample(sampler_MainTex, input.uv) * _Color;
    
    // Alpha test - discard pixels below cutoff threshold
    clip(albedo.a - _Cutoff);
    
    // Sample other textures
    float3 normal = _BumpMap.Sample(sampler_BumpMap, input.uv_normal).xyz * 2 - 1;
    float4 emission = _EmissionMap.Sample(sampler_MainTex, input.uv_emission) * _EmissionColor;
    
    // Build final color
    float3 albedoRGB = albedo.rgb;
    float3 finalColor = albedoRGB + emission.rgb;
    
    // Apply dithering
    float4 ditheredColor = GetDither3DColor(input.uv, input.screenPos, float4(finalColor, albedo.a));
    
    return float4(ditheredColor.rgb, albedo.a);
}

// Technique for cutout rendering
technique11 RenderCutout
{
    pass P0
    {
        SetVertexShader(CompileShader(VertexShader));
        SetPixelShader(CompileShader(PixelShader));
        
        // Render state settings for cutout
        SetBlendState(BlendState(Opaque));
        SetDepthStencilState(DepthStencilState(LessEqual), 0);
        SetRasterizerState(RasterizerState(CullBack));
    }
}
