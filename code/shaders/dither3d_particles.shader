/*
 * Dither3D Particle Additive Shader for s&box
 * Ported from Unity Dither3D by Rune Skovbo Johansen
 * 
 * This shader applies surface-stable fractal dithering to additive particles.
 * Uses additive blending for glowing particle effects.
 * 
 * SHADER PERMUTATIONS (define these when compiling):
 * - DITHERCOL_GRAYSCALE: Convert to grayscale dithering
 * - DITHERCOL_RGB: Separate RGB channel dithering
 * - INVERSE_DOTS: Invert the dot pattern
 * - RADIAL_COMPENSATION: Compensate for radial distortion at screen edges
 */

#include "dither3d_common.hlsl"

// Material parameters
Texture2D<float4> _MainTex;
SamplerState sampler_MainTex;

cbuffer MaterialParams : register(b0)
{
    float4 _Color;              // Tint color
    float _InvFade;             // Softness factor (1/softness)
};

// Vertex shader input structure
struct VertexInput
{
    float4 vertex : POSITION;
    float2 uv0 : TEXCOORD0;
    float4 color : COLOR;
};

// Vertex shader output / Pixel shader input
struct PixelInput
{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
    float4 screenPos : TEXCOORD1;
};

// Vertex Shader
PixelInput VertexShader(VertexInput input)
{
    PixelInput output = (PixelInput)0;
    
    // Transform vertex to clip space
    // NOTE: Replace UNITY_MATRIX_MVP with s&box's transformation system
    output.position = mul(UNITY_MATRIX_MVP, input.vertex);
    
    // Pass through UVs and color
    output.uv = input.uv0;
    output.color = input.color * _Color;
    
    // Calculate screen position for dithering
    output.screenPos = output.position;
    
    return output;
}

// Pixel Shader
float4 PixelShader(PixelInput input) : SV_Target
{
    // Sample particle texture
    float4 tex = _MainTex.Sample(sampler_MainTex, input.uv);
    
    // Apply vertex color
    float4 col = tex * input.color;
    
    // Soft particle fade (optional - distance-based)
    // This is simplified - full implementation would need camera depth
    
    // Apply dithering to the particle color
    // For particles, we typically use RGB or grayscale mode
    float4 ditheredColor = GetDither3DColor(input.uv, input.screenPos, col);
    
    // Return with original alpha for blending
    return float4(ditheredColor.rgb, col.a);
}

// Technique for additive particle rendering
technique11 RenderParticlesAdd
{
    pass P0
    {
        SetVertexShader(CompileShader(VertexShader));
        SetPixelShader(CompileShader(PixelShader));
        
        // Render state settings for additive particles
        SetBlendState(BlendState(Additive));
        SetDepthStencilState(DepthStencilState(LessEqual), 0);
        SetRasterizerState(RasterizerState(CullNone));
    }
}
