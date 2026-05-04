/*
 * Dither3D Common Include for s&box
 * Ported from Unity Dither3D by Rune Skovbo Johansen
 * 
 * This file contains the core dithering algorithm converted to s&box HLSL format.
 */

#ifndef DITHER3D_COMMON_HLSL
#define DITHER3D_COMMON_HLSL

// Texture resources - these will be bound via material parameters
Texture3D<float4> _DitherTex;
Texture2D<float4> _DitherRampTex;
SamplerState sampler_LinearClamp;
SamplerState sampler_PointClamp;

// Shader parameters - exposed to material/editor
cbuffer Dither3DParams : register(b10)
{
    float4 _DitherTex_TexelSize;  // x=1/width, y=1/height, z=width, w=height
    float _Scale;
    float _SizeVariability;
    float _Contrast;
    float _StretchSmoothness;
    float _InputExposure;
    float _InputOffset;
    int _DitherMode;
};

// Compile-time defines (set via material/shader permutations)
// #define INVERSE_DOTS
// #define RADIAL_COMPENSATION
// #define QUANTIZE_LAYERS
// #define DEBUG_FRACTAL
// #define DITHERCOL_GRAYSCALE
// #define DITHERCOL_RGB
// #define DITHERCOL_CMYK

// Helper function to get grayscale from color
float GetGrayscale(float4 color)
{
    return saturate(0.299 * color.r + 0.587 * color.g + 0.114 * color.b);
}

// CMYK conversion helpers
float3 CMYKtoRGB(float4 cmyk)
{
    float c = cmyk.x;
    float m = cmyk.y;
    float y = cmyk.z;
    float k = cmyk.w;

    float invK = 1.0 - k;
    float r = 1.0 - min(1.0, c * invK + k);
    float g = 1.0 - min(1.0, m * invK + k);
    float b = 1.0 - min(1.0, y * invK + k);
    return saturate(float3(r, g, b));
}

float4 RGBtoCMYK(float3 rgb)
{
    float r = rgb.r;
    float g = rgb.g;
    float b = rgb.b;
    float k = min(1.0 - r, min(1.0 - g, 1.0 - b));
    float3 cmy = 0.0;
    float invK = 1.0 - k;
    if (invK != 0.0)
    {
        cmy.x = (1.0 - r - k) / invK;
        cmy.y = (1.0 - g - k) / invK;
        cmy.z = (1.0 - b - k) / invK;
    }
    return saturate(float4(cmy, k));
}

// Rotate UV coordinates by a given direction
float2 RotateUV(float2 uv, float2 xUnitDir)
{
    return uv.x * xUnitDir + uv.y * float2(-xUnitDir.y, xUnitDir.x);
}

// Core dithering function - internal version with explicit derivatives
// dx, dy are the screen-space derivatives of the UV coordinates
float4 GetDither3D_Internal(float2 uv_DitherTex, float4 screenPos, float2 dx, float2 dy, float brightness)
{
#if INVERSE_DOTS
    brightness = 1.0 - brightness;
#endif

    // Get texture X resolution (width) based on texel size
    float xRes = _DitherTex_TexelSize.z;
    float invXres = _DitherTex_TexelSize.x;

    // The relationship between X resolution, dots per side, and total number of
    // dots - which is also the Z resolution - is hardcoded in the script that
    // creates the 3D texture.
    float dotsPerSide = xRes / 16.0;
    float dotsTotal = pow(dotsPerSide, 2); // Could also have been named zRes
    float invZres = 1.0 / dotsTotal;

    // Lookup brightness to make dither output have correct output
    // brightness at different input brightness values.
    float2 lookup = float2((0.5 * invXres + (1 - invXres) * brightness), 0.5);
    float brightnessCurve = _DitherRampTex.SampleLevel(sampler_LinearClamp, lookup, 0).r;

#if RADIAL_COMPENSATION
    // Make screenPos have 0,0 in the center of the screen.
    float2 screenP = (screenPos.xy / screenPos.w - 0.5) * 2.0;
    
    // Note: In s&box, we don't have UNITY_MATRIX_P directly
    // You may need to pass projection matrix as a parameter or calculate differently
    // For now, using a simplified approach
    float fovScale = 1.0; // Should be derived from projection matrix
    float2 viewDirProj = float2(screenP.x / fovScale, screenP.y / fovScale);
    
    // Calculate how much dots should be larger towards the edges of the screen.
    float radialCompensation = dot(viewDirProj, viewDirProj) + 1;
    dx *= radialCompensation;
    dy *= radialCompensation;
#endif

    // Get frequency based on singular value decomposition.
    float2x2 matr = { dx, dy };
    float4 vectorized = float4(dx, dy);
    float Q = dot(vectorized, vectorized);
    float R = determinant(matr);
    float discriminantSqr = max(0, Q*Q - 4*R*R);
    float discriminant = sqrt(discriminantSqr);

    // freq means rate of change of the UV coordinates on the screen.
    // (max-freq, min-freq)
    float2 freq = sqrt(float2(Q + discriminant, Q - discriminant) / 2);

    // We define a spacing variable which linearly correlates with
    // the average distance between dots.
    float spacing = freq.y;

    // Scale the spacing by the specified input (power of two) scale.
    float scaleExp = exp2(_Scale);
    spacing *= scaleExp;

    // We keep the spacing the same regardless of whether we're using
    // a pattern with more or less dots in it.
    spacing *= dotsPerSide * 0.125;

    // Size variability control
    float brightnessSpacingMultiplier = pow(brightnessCurve * 2 + 0.001, -(1 - _SizeVariability));
    spacing *= brightnessSpacingMultiplier;

    // Find the power-of-two level that corresponds to the dot spacing.
    float spacingLog = log2(spacing);
    int patternScaleLevel = floor(spacingLog); // Fractal level.
    float f = spacingLog - patternScaleLevel; // Fractional part.

    // Get the UV coordinates in the current fractal level.
    float2 uv = uv_DitherTex / exp2(patternScaleLevel);

    // Get the third coordinate for the 3D texture lookup.
    float subLayer = lerp(0.25 * dotsTotal, dotsTotal, 1 - f);

#if QUANTIZE_LAYERS
    float origSubLayer = subLayer;
    subLayer = floor(subLayer + 0.5);
    float thresholdTweak = sqrt(subLayer / origSubLayer);
#endif

    // Normalize to the 0-1 range
    subLayer = (subLayer - 0.5) * invZres;

    // Sample the 3D texture.
    float pattern = _DitherTex.SampleLevel(sampler_LinearClamp, float3(uv, subLayer), 0).r;

    // Create sharp dots from radial gradients by increasing contrast.
    float contrast = _Contrast * scaleExp * brightnessSpacingMultiplier * 0.1;

    // Contrast compensation for stretching
    contrast *= pow(freq.y / freq.x, _StretchSmoothness);

    // Base value for contrast scaling
    float baseVal = lerp(0.5, brightness, saturate(1.05 / (1 + contrast)));

    // Threshold calculation
#if QUANTIZE_LAYERS
    float threshold = 1 - brightnessCurve * thresholdTweak;
#else
    float threshold = 1 - brightnessCurve;
#endif

    // Apply contrast and threshold to get final black/white value
    float bw = saturate((pattern - threshold) * contrast + baseVal);

#if INVERSE_DOTS
    bw = 1.0 - bw;
#endif

    return float4(bw, frac(uv.x), frac(uv.y), subLayer);
}

// Simplified version using automatic derivatives
float GetDither3D(float2 uv_DitherTex, float4 screenPos, float brightness)
{
    float2 dx = ddx(uv_DitherTex);
    float2 dy = ddy(uv_DitherTex);
    return GetDither3D_Internal(uv_DitherTex, screenPos, dx, dy, brightness).x;
}

// Version with alternative UVs for seam removal
float GetDither3DAltUV(float2 uv_DitherTex, float2 uv_DitherTexAlt, float4 screenPos, float brightness)
{
    float2 dxA = ddx(uv_DitherTex);
    float2 dyA = ddy(uv_DitherTex);
    float2 dxB = ddx(uv_DitherTexAlt);
    float2 dyB = ddy(uv_DitherTexAlt);
    float2 dx = dot(dxA, dxA) < dot(dxB, dxB) ? dxA : dxB;
    float2 dy = dot(dyA, dyA) < dot(dyB, dyB) ? dyA : dyB;
    return GetDither3D_Internal(uv_DitherTex, screenPos, dx, dy, brightness).x;
}

// Color dithering function - internal version
float4 GetDither3DColor_Internal(float2 uv_DitherTex, float4 screenPos, float2 dx, float2 dy, float4 color)
{
    // Adjust brightness according to shader exposure and offset properties.
    color.rgb = saturate(color.rgb * _InputExposure + _InputOffset);

#ifdef DITHERCOL_GRAYSCALE
    float4 dither = GetDither3D_Internal(uv_DitherTex, screenPos, dx, dy, GetGrayscale(color));
    color.rgb = dither.x;
#if DEBUG_FRACTAL
    float3 uvVis = dither.yzw;
    color.rgb = lerp(color.rgb, uvVis, 0.7);
#endif

#elif DITHERCOL_RGB
    color.r = GetDither3D_Internal(uv_DitherTex, screenPos, dx, dy, color.r).x;
    color.g = GetDither3D_Internal(uv_DitherTex, screenPos, dx, dy, color.g).x;
    color.b = GetDither3D_Internal(uv_DitherTex, screenPos, dx, dy, color.b).x;

#elif DITHERCOL_CMYK
    float4 cmyk = RGBtoCMYK(color.rgb);
    // Get dither pattern for C, M, Y, K with angles 15, 75, 0, 45 degrees
    cmyk.x = GetDither3D_Internal(RotateUV(uv_DitherTex, float2(0.966, 0.259)), screenPos, dx, dy, cmyk.x).x;
    cmyk.y = GetDither3D_Internal(RotateUV(uv_DitherTex, float2(0.259, 0.966)), screenPos, dx, dy, cmyk.y).x;
    cmyk.z = GetDither3D_Internal(RotateUV(uv_DitherTex, float2(1.000, 0.000)), screenPos, dx, dy, cmyk.z).x;
    cmyk.w = GetDither3D_Internal(RotateUV(uv_DitherTex, float2(0.707, 0.707)), screenPos, dx, dy, cmyk.w).x;
    color.rgb = CMYKtoRGB(cmyk);
#endif

    return color;
}

// Simplified color dithering using automatic derivatives
float4 GetDither3DColor(float2 uv_DitherTex, float4 screenPos, float4 color)
{
    float2 dx = ddx(uv_DitherTex);
    float2 dy = ddy(uv_DitherTex);
    return GetDither3DColor_Internal(uv_DitherTex, screenPos, dx, dy, color);
}

// Color dithering with alternative UVs
float4 GetDither3DColorAltUV(float2 uv_DitherTex, float2 uv_DitherTexAlt, float4 screenPos, float4 color)
{
    float2 dxA = ddx(uv_DitherTex);
    float2 dyA = ddy(uv_DitherTex);
    float2 dxB = ddx(uv_DitherTexAlt);
    float2 dyB = ddy(uv_DitherTexAlt);
    float2 dx = dot(dxA, dxA) < dot(dxB, dxB) ? dxA : dxB;
    float2 dy = dot(dyA, dyA) < dot(dyB, dyB) ? dyA : dyB;
    return GetDither3DColor_Internal(uv_DitherTex, screenPos, dx, dy, color);
}

#endif // DITHER3D_COMMON_HLSL
