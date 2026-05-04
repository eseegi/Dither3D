# Dither3D to s&box Migration Research

## Key Differences Between Unity and s&box

### 1. Shader Language
- **Unity**: Uses CG/HLSL with Unity-specific macros and surface shaders
- **s&box**: Uses pure HLSL with Source 2's shader system (similar to CS2)

### 2. Texture Handling
- **Unity**: 3D textures via `sampler3D`, automatic UV scaling
- **s&box**: Supports 3D textures but requires different sampling approach

### 3. Render Pipeline
- **Unity**: Built-in/URP/HDRP with surface shaders or vertex/fragment
- **s&box**: Source 2 render pipeline with custom VRF (Vertex Rendering Function) and PSF (Pixel Shader Function)

### 4. Shader Keywords/Multi-compile
- **Unity**: `#pragma multi_compile` for shader variants
- **s&box**: Preprocessor defines and material parameters

### 5. Screen-space derivatives
- **Unity**: `ddx()`, `ddy()` built-in functions
- **s&box**: `dndx()`, `dndy()` or equivalent HLSL `ddx()`, `ddy()`

### 6. Global Properties
- **Unity**: `Shader.EnableKeyword()`, material property iteration
- **s&box**: Material parameters, scene rendering context

## Migration Strategy

### Phase 1: Core Shader Translation
1. Convert `Dither3DInclude.cginc` to s&box HLSL include
2. Translate Unity-specific functions to Source 2 equivalents
3. Handle 3D texture sampling properly

### Phase 2: Material System
1. Create s&box material definitions
2. Port shader parameters (Scale, SizeVariability, Contrast, etc.)
3. Implement color modes (Grayscale, RGB, CMYK)

### Phase 3: 3D Texture Generation
1. Port `Dither3DTextureMaker.cs` to C# for s&box
2. Generate Bayer pattern 3D textures
3. Create ramp textures for brightness correction

### Phase 4: Integration
1. Create component/system for global properties
2. Implement screen-space scaling
3. Add debug visualization

## Critical Unity-to-s&box Conversions

### Shader Structure
```hlsl
// Unity Surface Shader
#pragma surface surf Standard finalcolor:mycolor

// s&box Equivalent
// Use vrf.psfh pattern with custom pixel shader
```

### Texture Sampling
```hlsl
// Unity
sampler3D _DitherTex;
fixed pattern = tex3D(_DitherTex, float3(uv, subLayer)).r;

// s&box (similar but may need texture declaration changes)
Texture3D<float4> _DitherTex;
SamplerState _DitherTex_sampler;
float pattern = _DitherTex.SampleLevel(_DitherTex_sampler, float3(uv, subLayer), 0).r;
```

### Screen Position
```hlsl
// Unity
float4 screenPos; // from VERTEX semantic
UNITY_MATRIX_P   // projection matrix

// s&box
// Use GetScreenPosition() or similar
// Projection matrix from SceneContext
```

### Derivatives
```hlsl
// Unity
float2 dx = ddx(uv_DitherTex);
float2 dy = ddy(uv_DitherTex);

// s&box (same HLSL functions work)
float2 dx = ddx(uv_DitherTex);
float2 dy = ddy(uv_DitherTex);
```

## File Structure for s&box

```
/code/
  Dither3D/
    Dither3D.vfx (or .shader)
    Dither3D_Include.hlsl
    Dither3DTextureGenerator.cs
    Dither3DComponent.cs
/resources/
  materials/
    dither3d_opaque.vmat
    dither3d_cutout.vmat
    dither3d_particles.vmat
  textures/
    Dither3D_8x8.vtex (3D texture)
    Dither3D_Ramp.vtex
```

## Implementation Notes

1. **Bayer Matrix Pattern**: The core algorithm uses Bayer matrices' fractal property
2. **3D Texture Layout**: Layers contain progressively more dots (1 to N²)
3. **Fractal Level Selection**: Based on screen-space frequency analysis
4. **Anti-aliasing**: Achieved through contrast adjustment based on frequency

## Potential Challenges

1. **3D Texture Creation**: s&box may require different format or generation method
2. **Material Parameter System**: Different from Unity's material property blocks
3. **Render Queue**: Need to understand s&box's render order system
4. **Performance**: May need optimization for Source 2's rendering architecture

## Next Steps

1. Review s&box shader documentation
2. Test basic 3D texture sampling in s&box
3. Create minimal working example
4. Incrementally port features
