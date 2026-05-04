# Dither3D Shaders for s&box

This document contains the converted s&box shader files based on the Unity Dither3D implementation.

## Key Conversion Notes

1. **Unity Surface Shaders → s&box Vertex/Pixel Shaders**: s&box uses separate vertex (.vrf) and pixel (.psf) shader functions in a single .shader file
2. **CG/HLSL → Pure HLSL**: Removed Unity-specific macros and CG semantics
3. **Texture Sampling**: Changed from `tex3D()` to `Texture3D.SampleLevel()` syntax
4. **Screen Position**: Use `SV_Position` and calculate UVs differently
5. **Material Parameters**: Defined as shader parameters instead of Unity Properties
6. **Shader Keywords**: Converted to preprocessor defines

## File Structure for s&box

```
code/
└── shaders/
    ├── dither3d_common.hlsl      (shared include file)
    ├── dither3d_opaque.shader    (main opaque shader)
    ├── dither3d_cutout.shader    (alpha test cutout shader)
    └── dither3d_particles.shader (additive particles)
materials/
└── dither3d/
    ├── opaque.vmat
    ├── cutout.vmat
    └── particles.vmat
textures/
└── dither3d/
    ├── Dither3D_8x8.vtex (3D texture - needs generation)
    └── Dither3D_Ramp.vtex (brightness ramp)
```
