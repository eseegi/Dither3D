/*
 * Dither3D Common Include for s&box
 * Ported from Unity Dither3D by Rune Skovbo Johansen
 * 
 * Core fractal dithering algorithm - include this in your shaders
 */

#ifndef DITHER3D_COMMON_HLSL
#define DITHER3D_COMMON_HLSL

//=========================================================================================================================
// TEXTURE DECLARATIONS
//=========================================================================================================================

// 3D dither texture and 2D ramp texture
Texture3D g_tDither3D < Channel( R, Unorm8 ); Srgb( false ); >;
Texture2D g_tDitherRamp < Channel( R, Unorm8 ); Srgb( true ); >;

// Samplers
SamplerState g_sDither3D_Point < Filter( MIN_MAG_MIP_POINT ); AddressU( CLAMP ); AddressV( CLAMP ); AddressW( CLAMP ); >;
SamplerState g_sDitherRamp_Linear < Filter( MIN_MAG_MIP_LINEAR ); AddressU( CLAMP ); AddressV( CLAMP ); >;

//=========================================================================================================================
// MATERIAL PARAMETERS
//=========================================================================================================================

float g_flDitherScale < Default( 5.0 ); Range( 2, 10 ); UiGroup( "Dither Settings,1" ); >;
float g_flSizeVariability < Default( 0.0 ); Range( 0, 1 ); UiGroup( "Dither Settings,2" ); >;
float g_flContrast < Default( 1.0 ); Range( 0, 2 ); UiGroup( "Dither Settings,3" ); >;
float g_flStretchSmoothness < Default( 1.0 ); Range( 0, 2 ); UiGroup( "Dither Settings,4" ); >;
float g_flInputExposure < Default( 1.0 ); Range( 0, 5 ); UiGroup( "Dither Input Brightness,1" ); >;
float g_flInputOffset < Default( 0.0 ); Range( -1, 1 ); UiGroup( "Dither Input Brightness,2" ); >;

// Texel size info (set from material/script: x=1/width, y=1/height, z=width, w=height)
float4 g_vDitherTex_TexelSize < Default( 0.00390625, 0.00390625, 256, 256 ); >;

//=========================================================================================================================
// HELPER FUNCTIONS
//=========================================================================================================================

// Get grayscale from color
float GetGrayscale( float4 color )
{
    return saturate( 0.299 * color.r + 0.587 * color.g + 0.114 * color.b );
}

// RGB to CMYK conversion
float4 RGBtoCMYK( float3 rgb )
{
    float r = rgb.r;
    float g = rgb.g;
    float b = rgb.b;
    float k = min( 1.0 - r, min( 1.0 - g, 1.0 - b ) );
    float3 cmy = 0.0;
    float invK = 1.0 - k;
    
    if ( invK != 0.0 )
    {
        cmy.x = ( 1.0 - r - k ) / invK;
        cmy.y = ( 1.0 - g - k ) / invK;
        cmy.z = ( 1.0 - b - k ) / invK;
    }
    
    return saturate( float4( cmy, k ) );
}

// CMYK to RGB conversion
float3 CMYKtoRGB( float4 cmyk )
{
    float c = cmyk.x;
    float m = cmyk.y;
    float y = cmyk.z;
    float k = cmyk.w;
    
    float invK = 1.0 - k;
    float r = 1.0 - min( 1.0, c * invK + k );
    float g = 1.0 - min( 1.0, m * invK + k );
    float b = 1.0 - min( 1.0, y * invK + k );
    
    return saturate( float3( r, g, b ) );
}

// Rotate UV coordinates by a direction vector
float2 RotateUV( float2 uv, float2 xUnitDir )
{
    return uv.x * xUnitDir + uv.y * float2( -xUnitDir.y, xUnitDir.x );
}

//=========================================================================================================================
// CORE DITHERING FUNCTION
//=========================================================================================================================

// Main dithering function - internal version with explicit derivatives
float GetDither3D_Internal( float2 uv_DitherTex, float4 screenPos, float2 dx, float2 dy, float brightness, 
                            bool inverseDots, bool radialCompensation, bool quantizeLayers, bool debugFractal )
{
#if ( INVERSE_DOTS || inverseDots )
    brightness = 1.0 - brightness;
#endif
    
    // Get texture resolution from texel size
    float xRes = g_vDitherTex_TexelSize.z;
    float invXres = g_vDitherTex_TexelSize.x;
    
    // Calculate dots per side and total dots (hardcoded relationship from texture generation)
    float dotsPerSide = xRes / 16.0;
    float dotsTotal = pow( dotsPerSide, 2 ); // Also known as zRes
    float invZres = 1.0 / dotsTotal;
    
    // Lookup brightness curve from ramp texture
    float2 lookup = float2( ( 0.5 * invXres + ( 1 - invXres ) * brightness ), 0.5 );
    float brightnessCurve = g_tDitherRamp.SampleLevel( g_sDitherRamp_Linear, lookup, 0 ).r;
    
#if ( RADIAL_COMPENSATION || radialCompensation )
    // Make screenPos have 0,0 in center of screen
    float2 screenP = ( screenPos.xy / screenPos.w - 0.5 ) * 2.0;
    
    // Calculate view direction projected onto camera plane
    // Note: In s&box, use g_mProjection or similar instead of UNITY_MATRIX_P
    float2 viewDirProj = float2(
        screenP.x / 1.0,  // Replace with actual projection matrix values
        screenP.y / 1.0 );
    
    // Radial compensation for screen edges
    float radialCompensation = dot( viewDirProj, viewDirProj ) + 1;
    dx *= radialCompensation;
    dy *= radialCompensation;
#endif
    
    // Singular value decomposition for accurate frequency calculation
    float2x2 matr = { dx, dy };
    float4 vectorized = float4( dx, dy );
    float Q = dot( vectorized, vectorized );
    float R = determinant( matr );
    float discriminantSqr = max( 0, Q * Q - 4 * R * R );
    float discriminant = sqrt( discriminantSqr );
    
    // freq = (max_freq, min_freq)
    float2 freq = sqrt( float2( Q + discriminant, Q - discriminant ) / 2 );
    
    // Use smaller frequency (larger stretching) for spacing
    float spacing = freq.y;
    
    // Apply scale
    float scaleExp = exp2( g_flDitherScale );
    spacing *= scaleExp;
    
    // Normalize by pattern size
    spacing *= dotsPerSide * 0.125;
    
    // Size variability control
    float brightnessSpacingMultiplier = pow( brightnessCurve * 2 + 0.001, -( 1 - g_flSizeVariability ) );
    spacing *= brightnessSpacingMultiplier;
    
    // Calculate fractal level
    float spacingLog = log2( spacing );
    int patternScaleLevel = floor( spacingLog );
    float f = spacingLog - patternScaleLevel;
    
    // Get UV at current fractal level
    float2 uv = uv_DitherTex / exp2( patternScaleLevel );
    
    // Calculate third coordinate for 3D texture
    float subLayer = lerp( 0.25 * dotsTotal, dotsTotal, 1 - f );
    
#if ( QUANTIZE_LAYERS || quantizeLayers )
    float origSubLayer = subLayer;
    subLayer = floor( subLayer + 0.5 );
    float thresholdTweak = sqrt( subLayer / origSubLayer );
#endif
    
    // Normalize and offset for texel sampling
    subLayer = ( subLayer - 0.5 ) * invZres;
    
    // Sample 3D dither texture
    float pattern = g_tDither3D.SampleLevel( g_sDither3D_Point, float3( uv, subLayer ), 0 ).r;
    
    // Calculate contrast
    float contrast = g_flContrast * scaleExp * brightnessSpacingMultiplier * 0.1;
    contrast *= pow( freq.y / freq.x, g_flStretchSmoothness );
    
    // Base value for contrast scaling
    float baseVal = lerp( 0.5, brightness, saturate( 1.05 / ( 1 + contrast ) ) );
    
    // Threshold calculation
#if ( QUANTIZE_LAYERS || quantizeLayers )
    float threshold = 1 - brightnessCurve * thresholdTweak;
#else
    float threshold = 1 - brightnessCurve;
#endif
    
    // Apply contrast and get final black/white value
    float bw = saturate( ( pattern - threshold ) * contrast + baseVal );
    
#if ( INVERSE_DOTS || inverseDots )
    bw = 1.0 - bw;
#endif
    
#if ( DEBUG_FRACTAL || debugFractal )
    // Debug visualization shows UV and layer info
    return bw;
#else
    return bw;
#endif
}

// Simplified interface - uses automatic derivatives
float GetDither3D( float2 uv_DitherTex, float4 screenPos, float brightness )
{
    float2 dx = ddx( uv_DitherTex );
    float2 dy = ddy( uv_DitherTex );
    return GetDither3D_Internal( uv_DitherTex, screenPos, dx, dy, brightness, false, false, false, false );
}

// Alternative UV version for seam removal
float GetDither3D_AltUV( float2 uv_DitherTex, float2 uv_DitherTexAlt, float4 screenPos, float brightness )
{
    float2 dxA = ddx( uv_DitherTex );
    float2 dyA = ddy( uv_DitherTex );
    float2 dxB = ddx( uv_DitherTexAlt );
    float2 dyB = ddy( uv_DitherTexAlt );
    
    float2 dx = dot( dxA, dxA ) < dot( dxB, dxB ) ? dxA : dxB;
    float2 dy = dot( dyA, dyA ) < dot( dyB, dyB ) ? dyA : dyB;
    
    return GetDither3D_Internal( uv_DitherTex, screenPos, dx, dy, brightness, false, false, false, false );
}

//=========================================================================================================================
// COLOR DITHERING FUNCTIONS
//=========================================================================================================================

float4 GetDither3DColor_Internal( float2 uv_DitherTex, float4 screenPos, float2 dx, float2 dy, float4 color,
                                  bool inverseDots, bool radialCompensation, bool quantizeLayers, bool debugFractal,
                                  int colorMode )
{
    // Adjust brightness according to exposure and offset
    color.rgb = saturate( color.rgb * g_flInputExposure + g_flInputOffset );
    
    // Grayscale mode
    if ( colorMode == 1 ) // DITHERCOL_GRAYSCALE
    {
        float dither = GetDither3D_Internal( uv_DitherTex, screenPos, dx, dy, GetGrayscale( color ), 
                                             inverseDots, radialCompensation, quantizeLayers, debugFractal );
        color.rgb = dither;
        
#if ( DEBUG_FRACTAL || debugFractal )
        // Would need to return debug info differently
#endif
    }
    // RGB mode
    else if ( colorMode == 2 ) // DITHERCOL_RGB
    {
        color.r = GetDither3D_Internal( uv_DitherTex, screenPos, dx, dy, color.r, 
                                        inverseDots, radialCompensation, quantizeLayers, false );
        color.g = GetDither3D_Internal( uv_DitherTex, screenPos, dx, dy, color.g, 
                                        inverseDots, radialCompensation, quantizeLayers, false );
        color.b = GetDither3D_Internal( uv_DitherTex, screenPos, dx, dy, color.b, 
                                        inverseDots, radialCompensation, quantizeLayers, false );
    }
    // CMYK mode
    else if ( colorMode == 3 ) // DITHERCOL_CMYK
    {
        float4 cmyk = RGBtoCMYK( color.rgb );
        
        // Apply dithering with different angles for each channel
        cmyk.x = GetDither3D_Internal( RotateUV( uv_DitherTex, float2( 0.966, 0.259 ) ), screenPos, dx, dy, cmyk.x,
                                       inverseDots, radialCompensation, quantizeLayers, false );
        cmyk.y = GetDither3D_Internal( RotateUV( uv_DitherTex, float2( 0.259, 0.966 ) ), screenPos, dx, dy, cmyk.y,
                                       inverseDots, radialCompensation, quantizeLayers, false );
        cmyk.z = GetDither3D_Internal( RotateUV( uv_DitherTex, float2( 1.000, 0.000 ) ), screenPos, dx, dy, cmyk.z,
                                       inverseDots, radialCompensation, quantizeLayers, false );
        cmyk.w = GetDither3D_Internal( RotateUV( uv_DitherTex, float2( 0.707, 0.707 ) ), screenPos, dx, dy, cmyk.w,
                                       inverseDots, radialCompensation, quantizeLayers, false );
        
        color.rgb = CMYKtoRGB( cmyk );
    }
    
    return color;
}

// Main color dithering function
float4 GetDither3DColor( float2 uv_DitherTex, float4 screenPos, float4 color )
{
    float2 dx = ddx( uv_DitherTex );
    float2 dy = ddy( uv_DitherTex );
    return GetDither3DColor_Internal( uv_DitherTex, screenPos, dx, dy, color, false, false, false, false, 0 );
}

// Grayscale helper
float4 GetDither3DColor_Grayscale( float2 uv_DitherTex, float4 screenPos, float4 color )
{
    float2 dx = ddx( uv_DitherTex );
    float2 dy = ddy( uv_DitherTex );
    return GetDither3DColor_Internal( uv_DitherTex, screenPos, dx, dy, color, false, false, false, false, 1 );
}

// RGB helper
float4 GetDither3DColor_RGB( float2 uv_DitherTex, float4 screenPos, float4 color )
{
    float2 dx = ddx( uv_DitherTex );
    float2 dy = ddy( uv_DitherTex );
    return GetDither3DColor_Internal( uv_DitherTex, screenPos, dx, dy, color, false, false, false, false, 2 );
}

// CMYK helper
float4 GetDither3DColor_CMYK( float2 uv_DitherTex, float4 screenPos, float4 color )
{
    float2 dx = ddx( uv_DitherTex );
    float2 dy = ddy( uv_DitherTex );
    return GetDither3DColor_Internal( uv_DitherTex, screenPos, dx, dy, color, false, false, false, false, 3 );
}

#endif // DITHER3D_COMMON_HLSL
