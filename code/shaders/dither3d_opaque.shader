//=========================================================================================================================
// Dither3D Opaque Shader for s&box
// Ported from Unity Dither3D by Rune Skovbo Johansen
//=========================================================================================================================

HEADER
{
    Description = "Dither3D Opaque - Surface-stable fractal dithering for opaque surfaces";
}

//=========================================================================================================================

FEATURES
{
    #include "common/features.hlsl"
    
    // Color mode selection
    Feature( F_DITHERCOL_GRAYSCALE, 0..1, "Dither Color Mode" );
    Feature( F_DITHERCOL_RGB, 0..1, "Dither Color Mode" );
    Feature( F_DITHERCOL_CMYK, 0..1, "Dither Color Mode" );
    
    // Dither options
    Feature( F_INVERSE_DOTS, 0..1, "Dither Settings" );
    Feature( F_RADIAL_COMPENSATION, 0..1, "Dither Settings" );
    Feature( F_QUANTIZE_LAYERS, 0..1, "Dither Settings" );
    Feature( F_DEBUG_FRACTAL, 0..1, "Debug" );
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
    
    StaticCombo( S_DITHERCOL_GRAYSCALE, F_DITHERCOL_GRAYSCALE, Sys( ALL ) );
    StaticCombo( S_DITHERCOL_RGB, F_DITHERCOL_RGB, Sys( ALL ) );
    StaticCombo( S_DITHERCOL_CMYK, F_DITHERCOL_CMYK, Sys( ALL ) );
    
    // Main vertex shader
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
    
    // Static combos for feature branching
    StaticCombo( S_DITHERCOL_GRAYSCALE, F_DITHERCOL_GRAYSCALE, Sys( ALL ) );
    StaticCombo( S_DITHERCOL_RGB, F_DITHERCOL_RGB, Sys( ALL ) );
    StaticCombo( S_DITHERCOL_CMYK, F_DITHERCOL_CMYK, Sys( ALL ) );
    StaticCombo( S_INVERSE_DOTS, F_INVERSE_DOTS, Sys( ALL ) );
    StaticCombo( S_RADIAL_COMPENSATION, F_RADIAL_COMPENSATION, Sys( ALL ) );
    StaticCombo( S_QUANTIZE_LAYERS, F_QUANTIZE_LAYERS, Sys( ALL ) );
    StaticCombo( S_DEBUG_FRACTAL, F_DEBUG_FRACTAL, Sys( ALL ) );
    
    // Textures
    CreateInputTexture2D( TextureAlbedo, Srgb, 8, "", "_color", "Material,10/10", Default3( 1.0, 1.0, 1.0 ) );
    Texture2D g_tAlbedo < Channel( RGB, Box( TextureAlbedo ), Srgb ); OutputFormat( BC7 ); SrgbRead( true ); >;
    
    CreateInputTexture2D( TextureNormalMap, Linear, 8, "", "_normal", "Material,10/20", Default3( 0.5, 0.5, 1.0 ) );
    Texture2D g_tNormal < Channel( RGB, Unorm8, Box( TextureNormalMap ), Linear ); OutputFormat( BC5 ); SrgbRead( false ); >;
    
    CreateInputTexture2D( TextureEmissive, Srgb, 8, "", "_emissive", "Material,10/40", Default3( 0.0, 0.0, 0.0 ) );
    Texture2D g_tEmissive < Channel( RGB, Unorm8, Box( TextureEmissive ), Srgb ); OutputFormat( BC7 ); SrgbRead( true ); >;
    
    CreateInputScalar( InputRoughness, Linear, 8, "", "_roughness", "Material,10/50", Default1( 0.5 ) );
    Texture2D g_tRoughness < Channel( R, Unorm8, Box( InputRoughness ), Linear ); OutputFormat( R8 ); SrgbRead( false ); >;
    
    CreateInputScalar( InputMetallic, Linear, 8, "", "_metallic", "Material,10/50", Default1( 0.0 ) );
    Texture2D g_tMetallic < Channel( R, Unorm8, Box( InputMetallic ), Linear ); OutputFormat( R8 ); SrgbRead( false ); >;
    
    // Dither 3D textures (must be set via material/script)
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
    
    // Force early-z for better performance
    #if ( S_MODE_DEPTH == 0 )
        [earlydepthstencil]
    #endif
    
    float4 MainPs( PixelInput i ) : SV_Target0
    {
        Material m = Material::From( i );
        
        // Sample albedo texture
        float4 albedo = g_tAlbedo.Sample( TextureFiltering, i.vTexCoord0 );
        m.Albedo = albedo.rgb;
        
        // Sample normal map
        float3 normalSample = g_tNormal.Sample( TextureFiltering, i.vTexCoord0 ).rgb * 2.0 - 1.0;
        m.Normal = normalize( mul( float3x3( m.WorldTangentU, m.WorldTangentV, m.Normal ), normalSample ) );
        
        // Sample emissive
        float3 emissive = g_tEmissive.Sample( TextureFiltering, i.vTexCoord0 ).rgb;
        m.Emission += emissive;
        
        // Sample roughness and metallic
        m.Roughness = g_tRoughness.Sample( TextureFiltering, i.vTexCoord0 ).r;
        m.Metallic = g_tMetallic.Sample( TextureFiltering, i.vTexCoord0 ).r;
        
        // Apply dithering based on color mode
        float4 ditheredColor;
        
#if S_DITHERCOL_GRAYSCALE
        ditheredColor = GetDither3DColor_Grayscale( i.vTexCoord0, i.vScreenPos, float4( m.Albedo, 1.0 ) );
#elif S_DITHERCOL_RGB
        ditheredColor = GetDither3DColor_RGB( i.vTexCoord0, i.vScreenPos, float4( m.Albedo, 1.0 ) );
#elif S_DITHERCOL_CMYK
        ditheredColor = GetDither3DColor_CMYK( i.vTexCoord0, i.vScreenPos, float4( m.Albedo, 1.0 ) );
#else
        // Default: grayscale
        ditheredColor = GetDither3DColor_Grayscale( i.vTexCoord0, i.vScreenPos, float4( m.Albedo, 1.0 ) );
#endif
        
        m.Albedo = ditheredColor.rgb;
        
        // Shade with standard PBR
        float4 output = ShadingModelStandard::Shade( i, m );
        
        return output;
    }
}
