# Dither3D Shaders for s&box - Implementation Complete

## What Was Created

I've ported the Unity Dither3D shaders to s&box format based on the foliage shader reference you provided. Here's what's now in `/workspace/code/shaders/`:

### Shader Files

1. **dither3d_common.hlsl** (9.5KB)
   - Core dithering algorithm include file
   - All fractal dithering logic from Unity's Dither3DInclude.cginc
   - Helper functions: GetGrayscale, RGBtoCMYK, CMYKtoRGB, RotateUV
   - Main functions: GetDither3D(), GetDither3DColor() with Grayscale/RGB/CMYK variants
   - Converted from Unity CG/HLSL to s&box shader syntax

2. **dither3d_opaque.shader** (6.2KB)
   - Standard opaque surface shader with PBR
   - Supports albedo, normal, roughness, metallic, emissive maps
   - Three color modes: Grayscale, RGB, CMYK dithering
   - Feature toggles for inverse dots, radial compensation, quantized layers

3. **dither3d_cutout.shader** (7.8KB)
   - Alpha-tested shader for foliage, grass, leaves
   - Mip-aware alpha-to-coverage (based on Ben Golus/Ignacio Castaño techniques)
   - Distance-based alpha fade to prevent popping
   - Same dithering features as opaque shader

4. **dither3d_particles.shader** (5.9KB)
   - Additive blending particle shader
   - Soft particles support with depth fade
   - Dithered particle brightness
   - Tint color control

## Key Differences from Unity Version

### Syntax Changes Made
- Unity `Surface` shaders → s&box Vertex/Pixel split
- Unity `#pragma multi_compile` → s&box `FEATURES` + `STATIC_COMBO`
- Unity `cbuffer` → s&box individual float parameters with `<Default()>` attributes
- Unity `tex2D/tex3D` → s&box `Texture2D/Texture3D.Sample()`
- Unity `UNITY_MATRIX_*` → Removed (radial compensation needs s&box projection matrix)
- Added `CreateInputTexture2D` for material texture inputs

### Features Preserved
✅ Fractal dithering algorithm (complete)
✅ Surface-stable dot placement
✅ Grayscale/RGB/CMYK color modes
✅ Dot scale, size variability, contrast controls
✅ Radial compensation (needs projection matrix values)
✅ Quantized layers option
✅ Inverse dots mode
✅ Debug fractal visualization

### What Needs Attention

1. **3D Textures**: The shaders expect g_tDither3D and g_tDitherRamp textures to be set. You mentioned preferring Option B (C# script generation). I can create a texture generator script next.

2. **Radial Compensation**: Currently uses placeholder values (1.0) for projection matrix. In s&box you'll need to use `g_mProjection` or equivalent to get proper values.

3. **Material Files (.vmat)**: You'll need to create material definition files in s&box that:
   - Reference these shaders
   - Set default texture values
   - Define UI parameter groups

4. **Testing**: Load shaders in s&box editor and verify:
   - Syntax compiles without errors
   - Parameters appear in material inspector
   - Dithering effect renders correctly

## Next Steps

1. **Copy shaders to s&box project**: Place in your addon's `shaders/` folder
2. **Generate 3D textures**: I can create a C# script to generate the fractal dither textures
3. **Create materials**: Make .vmat files or use editor to create materials with these shaders
4. **Test and iterate**: Adjust any s&box-specific syntax issues

Would you like me to:
- Create the 3D texture generation script (Option B)?
- Create example material definition files?
- Make any adjustments to the shader syntax based on what you see in the editor?
