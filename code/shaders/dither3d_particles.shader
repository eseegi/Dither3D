//=========================================================================================================================
// Dither3D Particles Additive Shader for s&box
// Ported from Unity Dither3D by Rune Skovbo Johansen
// For particle effects with additive blending
//=========================================================================================================================

HEADER
{
    Description = "Dither3D Particles - Fractal dithering for additive particle effects";
}

//=========================================================================================================================

FEATURES
{
    #include "common/features.hlsl"
    
    Feature( F_SOFT_PARTICLES, 0..1, "Particles" );
    Feature( F_INVERSE_DOTS, 0..1, "Dither Settings" );
    Feature( F_RADIAL_COMPENSATION, 0..1, "Dither Settings" );
    Feature( F_QUANTIZE_LAYERS, 0..1, "Dither Settings" );
    Feature( F_DEBUG_FRACTAL, 0..1, "Debug" );
}

//=========================================================================================================================

MODES
{
    Forward();
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
    float4 vPositionOs          : POSITION < Semantic( Position ); >;
    float4 vColor               : COLOR0 < Semantic( Color ); >;
    float2 vTexCoord0           : TEXCOORD0 < Semantic( TexCoord0 ); >;
    uint nInstanceTransformID   : INSTANCE_TRANSFORM_ID < Semantic( InstanceTransformID ); Optional(); >;
};

//=========================================================================================================================

struct PixelInput
{
    #include "common/pixelinput.hlsl"
    
    float4 vColor               : COLOR0;
    float2 vTexCoord0           : TEXCOORD0;
    float4 vScreenPos           : TEXCOORD3;
    
#if S_SOFT_PARTICLES
    float4 vProjPos             : TEXCOORD4;
#endif
};

//=========================================================================================================================

VS
{
    #include "common/vertex.hlsl"
    
    StaticCombo( S_SOFT_PARTICLES, F_SOFT_PARTICLES, Sys( ALL ) );
    
    // Particle color tint
    float4 g_vTintColor < Default( 0.5, 0.5, 0.5, 0.5 ); Srgb( true ); UiGroup( "Particles" ); >;
    float g_flInvFade < Default( 1.0 ); Range( 0.01, 3.0 ); UiGroup( "Soft Particles" ); >;
    
    PixelInput MainVs( VertexInput i )
    {
        PixelInput o;
        
        float4x4 matObjectToWorld = GetTransformMatrix( i.nInstanceTransformID );
        float4 vPositionWs = mul( matObjectToWorld, i.vPositionOs );
        o.vPositionPs = Position3WsToPs( vPositionWs.xyz );
        
        o.vColor = i.vColor * g_vTintColor;
        o.vTexCoord0 = i.vTexCoord0;
        o.vScreenPos = ComputeScreenPos( o.vPositionPs );
        
#if S_SOFT_PARTICLES
        o.vProjPos = o.vPositionPs;
        o.vProjPos.z = o.vPositionPs.w; // Eye depth
#endif
        
        return FinalizeVertex( o );
    }
}

//=========================================================================================================================

PS
{
    #include "common/utils/Material.CommonInputs.hlsl"
    #include "common/pixel.hlsl"
    
    StaticCombo( S_SOFT_PARTICLES, F_SOFT_PARTICLES, Sys( ALL ) );
    StaticCombo( S_INVERSE_DOTS, F_INVERSE_DOTS, Sys( ALL ) );
    StaticCombo( S_RADIAL_COMPENSATION, F_RADIAL_COMPENSATION, Sys( ALL ) );
    StaticCombo( S_QUANTIZE_LAYERS, F_QUANTIZE_LAYERS, Sys( ALL ) );
    StaticCombo( S_DEBUG_FRACTAL, F_DEBUG_FRACTAL, Sys( ALL ) );
    
    // Render state for additive blending
    RenderState( BlendEnable, true );
    RenderState( BlendOp, ADD );
    RenderState( SrcBlend, SRC_ALPHA );
    RenderState( DestBlend, ONE );
    RenderState( ColorWriteEnable, DEFAULT );
    RenderState( CullMode, NONE );
    RenderState( DepthWriteEnable, false );
    
    // Particle texture
    CreateInputTexture2D( TextureParticle, Srgb, 8, "", "_color", "Material,10/10", Default3( 1.0, 1.0, 1.0 ) );
    Texture2D g_tParticle < Channel( RGBA, Box( TextureParticle ), Srgb ); OutputFormat( BC7 ); SrgbRead( true ); >;
    
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
    
    // Soft particles
    float g_flInvFade < Default( 1.0 ); Range( 0.01, 3.0 ); UiGroup( "Soft Particles" ); >;
    
#if S_SOFT_PARTICLES
    TextureDepth2D g_tDepth < SrgbRead( false ); >;
#endif
    
    float4 MainPs( PixelInput i ) : SV_Target0
    {
        // Sample particle texture
        float4 col = g_tParticle.Sample( TextureFiltering, i.vTexCoord0 );
        col *= i.vColor;
        
        // Soft particle fade
#if S_SOFT_PARTICLES
        float sceneZ = SAMPLE_DEPTH_TEXTURE_PROJ( g_tDepth, i.vProjPos ).x;
        sceneZ = LinearizeDepth( sceneZ );
        float partZ = i.vProjPos.w;
        float fade = saturate( g_flInvFade * ( sceneZ - partZ ) );
        col.a *= fade;
#endif
        
        // Clamp alpha for HDR behavior
        col.a = saturate( col.a );
        
        // Convert to premultiplied alpha for additive blending
        float3 ditherInput = col.rgb * col.a;
        float brightness = GetGrayscale( float4( ditherInput, 1.0 ) );
        
        // Apply dithering
        float dithered = GetDither3D( i.vTexCoord0, i.vScreenPos, brightness );
        
        // Output with dithered brightness
        float4 output = float4( ditherInput * dither / max( brightness, 0.001 ), 1.0 );
        
        return output;
    }
}
