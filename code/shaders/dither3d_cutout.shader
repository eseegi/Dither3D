//=========================================================================================================================
// Dither3D Cutout Shader for s&box
// Ported from Unity Dither3D by Rune Skovbo Johansen
// For foliage, leaves, grass, and other alpha-tested surfaces
//=========================================================================================================================

HEADER
{
    Description = "Dither3D Cutout - Surface-stable fractal dithering with alpha testing";
}

//=========================================================================================================================

FEATURES
{
    #include "common/features.hlsl"
    
    Feature( F_ALPHA_TEST, 0..1, "Rendering" );
    Feature( F_DITHERCOL_GRAYSCALE, 0..1, "Dither Color Mode" );
    Feature( F_DITHERCOL_RGB, 0..1, "Dither Color Mode" );
    Feature( F_DITHERCOL_CMYK, 0..1, "Dither Color Mode" );
    Feature( F_INVERSE_DOTS, 0..1, "Dither Settings" );
    Feature( F_RADIAL_COMPENSATION, 0..1, "Dither Settings" );
    Feature( F_QUANTIZE_LAYERS, 0..1, "Dither Settings" );
}

//=========================================================================================================================

MODES
{
    Forward();
    Depth( S_MODE_DEPTH );
    ToolsShadingComplexity( "tools_shading_complexity.shader" );
}

//=========================================================================================================================

COMMON
{
    #include "common/shared.hlsl"
    #include "dither3d_common.hlsl"
}

//=========================================================================================================================

struct VertexInput
{
    #include "common/vertexinput.hlsl"
    
    float2 vTexCoord0           : TEXCOORD0 < Semantic( TexCoord0 ); >;
};

//=========================================================================================================================

struct PixelInput
{
    #include "common/pixelinput.hlsl"
    
    float2 vTexCoord0           : TEXCOORD0;
    float4 vScreenPos           : TEXCOORD3;
};

//=========================================================================================================================

VS
{
    #include "common/vertex.hlsl"
    
    StaticCombo( S_ALPHA_TEST, F_ALPHA_TEST, Sys( ALL ) );
    StaticCombo( S_DITHERCOL_GRAYSCALE, F_DITHERCOL_GRAYSCALE, Sys( ALL ) );
    StaticCombo( S_DITHERCOL_RGB, F_DITHERCOL_RGB, Sys( ALL ) );
    StaticCombo( S_DITHERCOL_CMYK, F_DITHERCOL_CMYK, Sys( ALL ) );
    
    // Alpha test parameters
    float g_flCutoff < Default( 0.5 ); Range( 0, 1 ); UiGroup( "Alpha Test" ); >;
    
    RenderState( CullMode, DEFAULT );
    
    PixelInput MainVs( VertexInput i )
    {
        PixelInput o = ProcessVertex( i );
        
        o.vTexCoord0 = i.vTexCoord0;
        o.vScreenPos = ComputeScreenPos( o.vPositionPs );
        
        return FinalizeVertex( o );
    }
}

//=========================================================================================================================

PS
{
    #include "common/utils/Material.CommonInputs.hlsl"
    #include "common/pixel.hlsl"
    #include "common/classes/Light.hlsl"
    
    StaticCombo( S_ALPHA_TEST, F_ALPHA_TEST, Sys( ALL ) );
    StaticCombo( S_DITHERCOL_GRAYSCALE, F_DITHERCOL_GRAYSCALE, Sys( ALL ) );
    StaticCombo( S_DITHERCOL_RGB, F_DITHERCOL_RGB, Sys( ALL ) );
    StaticCombo( S_DITHERCOL_CMYK, F_DITHERCOL_CMYK, Sys( ALL ) );
    StaticCombo( S_INVERSE_DOTS, F_INVERSE_DOTS, Sys( ALL ) );
    StaticCombo( S_RADIAL_COMPENSATION, F_RADIAL_COMPENSATION, Sys( ALL ) );
    StaticCombo( S_QUANTIZE_LAYERS, F_QUANTIZE_LAYERS, Sys( ALL ) );
    
    RenderState( CullMode, DEFAULT );
    
    #if ( S_MODE_DEPTH == 0 )
        RenderState( DepthFunc, LESS_EQUAL );
    #endif
    
    // Textures
    CreateInputTexture2D( TextureAlbedo, Srgb, 8, "", "_color", "Material,10/10", Default3( 1.0, 1.0, 1.0 ) );
    Texture2D g_tAlbedo < Channel( RGBA, Box( TextureAlbedo ), Srgb ); OutputFormat( BC7 ); SrgbRead( true ); >;
    
    CreateInputTexture2D( TextureNormalMap, Linear, 8, "", "_normal", "Material,10/20", Default3( 0.5, 0.5, 1.0 ) );
    Texture2D g_tNormal < Channel( RGB, Unorm8, Box( TextureNormalMap ), Linear ); OutputFormat( BC5 ); SrgbRead( false ); >;
    
    CreateInputScalar( InputRoughness, Linear, 8, "", "_roughness", "Material,10/50", Default1( 0.5 ) );
    Texture2D g_tRoughness < Channel( R, Unorm8, Box( InputRoughness ), Linear ); OutputFormat( R8 ); SrgbRead( false ); >;
    
    CreateInputScalar( InputMetallic, Linear, 8, "", "_metallic", "Material,10/50", Default1( 0.0 ) );
    Texture2D g_tMetallic < Channel( R, Unorm8, Box( InputMetallic ), Linear ); OutputFormat( R8 ); SrgbRead( false ); >;
    
    // Dither textures
    Texture3D g_tDither3D < Channel( R, Unorm8 ); Srgb( false ); >;
    Texture2D g_tDitherRamp < Channel( R, Unorm8 ); Srgb( true ); >;
    
    // Dither parameters
    float g_flDitherScale < Default( 5.0 ); Range( 2, 10 ); UiGroup( "Dither Settings" ); >;
    float g_flSizeVariability < Default( 0.0 ); Range( 0, 1 ); UiGroup( "Dither Settings" ); >;
    float g_flContrast < Default( 1.0 ); Range( 0, 2 ); UiGroup( "Dither Settings" ); >;
    float g_flStretchSmoothness < Default( 1.0 ); Range( 0, 2 ); UiGroup( "Dither Settings" ); >;
    float g_flInputExposure < Default( 1.0 ); Range( 0, 5 ); UiGroup( "Dither Input Brightness" ); >;
    float g_flInputOffset < Default( 0.0 ); Range( -1, 1 ); UiGroup( "Dither Input Brightness" ); >;
    float4 g_vDitherTex_TexelSize < Default( 0.00390625, 0.00390625, 256, 256 ); >;
    
    // Alpha test
    float g_flCutoff < Default( 0.5 ); Range( 0, 1 ); UiGroup( "Alpha Test" ); >;
    float g_flAlphaDistanceStart < Default( 500.0 ); Range( 0.0, 5000.0 ); UiGroup( "Alpha Test" ); >;
    float g_flAlphaDistanceEnd < Default( 2000.0 ); Range( 0.0, 10000.0 ); UiGroup( "Alpha Test" ); >;
    
    #if S_ALPHA_TEST
    float CalcMipLevel( float2 vTexCoord )
    {
        float2 dx = ddx( vTexCoord );
        float2 dy = ddy( vTexCoord );
        float delta = max( dot( dx, dx ), dot( dy, dy ) );
        return max( 0.0, 0.5 * log2( delta ) );
    }
    
    float ApplyAlphaToCoverage( float opacity, float dist, float2 vTexCoord )
    {
        clip( opacity - ( 1.0 / 255.0 ) );
        
        int2 vTexDim = TextureDimensions2DS( g_tAlbedo, 0 );
        float mipLevel = CalcMipLevel( vTexCoord * float2( vTexDim ) );
        opacity *= 1.0 + mipLevel * 0.25;
        
        float distFactor = saturate( ( dist - g_flAlphaDistanceStart ) / max( g_flAlphaDistanceEnd - g_flAlphaDistanceStart, 0.001 ) );
        float alphaRef = lerp( g_flCutoff, 0.1, distFactor );
        
        return saturate( ( opacity - alphaRef ) / max( fwidth( opacity ), 0.0001 ) + 0.5 );
    }
    #endif
    
    #if ( S_MODE_DEPTH == 0 )
        [earlydepthstencil]
    #endif
    
    float4 MainPs( PixelInput i ) : SV_Target0
    {
        Material m = Material::From( i );
        
        // Sample albedo with alpha
        float4 albedoSample = g_tAlbedo.Sample( TextureFiltering, i.vTexCoord0 );
        m.Albedo = albedoSample.rgb;
        float alpha = albedoSample.a;
        
        // Alpha test
#if S_ALPHA_TEST
        if ( g_nMSAASampleCount == 1 )
        {
            clip( alpha - g_flCutoff );
            alpha = 1.0;
        }
#endif
        
        // Normal map
        float3 normalSample = g_tNormal.Sample( TextureFiltering, i.vTexCoord0 ).rgb * 2.0 - 1.0;
        m.Normal = normalize( mul( float3x3( m.WorldTangentU, m.WorldTangentV, m.Normal ), normalSample ) );
        
        // Roughness and metallic
        m.Roughness = g_tRoughness.Sample( TextureFiltering, i.vTexCoord0 ).r;
        m.Metallic = g_tMetallic.Sample( TextureFiltering, i.vTexCoord0 ).r;
        
        // Apply dithering
        float4 ditheredColor;
        float dist = length( i.vPositionWithOffsetWs.xyz );
        
#if S_DITHERCOL_GRAYSCALE
        ditheredColor = GetDither3DColor_Grayscale( i.vTexCoord0, i.vScreenPos, float4( m.Albedo, 1.0 ) );
#elif S_DITHERCOL_RGB
        ditheredColor = GetDither3DColor_RGB( i.vTexCoord0, i.vScreenPos, float4( m.Albedo, 1.0 ) );
#elif S_DITHERCOL_CMYK
        ditheredColor = GetDither3DColor_CMYK( i.vTexCoord0, i.vScreenPos, float4( m.Albedo, 1.0 ) );
#else
        ditheredColor = GetDither3DColor_Grayscale( i.vTexCoord0, i.vScreenPos, float4( m.Albedo, 1.0 ) );
#endif
        
        m.Albedo = ditheredColor.rgb;
        
        float4 output = ShadingModelStandard::Shade( i, m );
        
#if S_ALPHA_TEST
        output.a = ApplyAlphaToCoverage( alpha, dist, i.vTexCoord0 );
#endif
        
        return output;
    }
}
