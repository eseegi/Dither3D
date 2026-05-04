# Dither3D s&box Shader Implementation Guide

## What Has Been Created

I've created the core shader files for porting Dither3D to s&box:

### Files Created in `/workspace/code/shaders/`:

1. **dither3d_common.hlsl** - Core dithering algorithm include file
2. **dither3d_opaque.shader** - Main opaque surface shader
3. **dither3d_cutout.shader** - Alpha-tested cutout shader (for foliage, etc.)
4. **dither3d_particles.shader** - Additive particle shader

## Important Notes About s&box Shaders

### Current Status: TEMPLATE FILES

The shader files I created are **HLSL templates** that need adaptation for s&box's specific shader system. Here's what you need to know:

### 1. s&box Uses .shader Files BUT...

s&box does use `.shader` files, but they follow Source 2's shader format which is different from Unity's:

- **Unity**: Surface shaders with `#pragma surface`, CG/HLSL macros
- **s&box/Source 2**: Vertex/Pixel shader functions with techniques and passes

### 2. Key Changes Needed for s&box

#### A. Matrix Transformations
The current shaders use Unity matrix names that need replacement:
```hlsl
// CURRENT (Unity):
output.position = mul(UNITY_MATRIX_MVP, input.vertex);

// NEEDED (s&box):
// You'll need to use s&box's built-in transformation system
// This might be through automatic semantics or different variable names
```

#### B. Texture Binding
s&box may require different texture binding syntax:
```hlsl
// Current HLSL (should work but may need adjustment):
Texture3D<float4> _DitherTex;
_DitherTex.SampleLevel(sampler_LinearClamp, uv, 0);
```

#### C. Material Parameters
s&box materials use `.vmat` files to define shader parameters. You'll need to create material definition files.

### 3. Next Steps to Complete the Port

#### Step 1: Check s&box's Actual Shader Format

Open s&box editor and:
1. Find an existing shader in the editor
2. Export or view its source code
3. Compare with the templates I created
4. Adjust syntax as needed

#### Step 2: Generate 3D Textures

The Dither3D system requires 3D textures. In Unity, these were created by `Dither3DTextureMaker.cs`. For s&box:

**Option A**: Use a C# script to generate textures at runtime
**Option B**: Pre-generate textures externally and import as `.vtex` files
**Option C**: Use s&box's texture creation tools

I can help create a texture generation script if needed.

#### Step 3: Create Material Files (.vmat)

For each shader, you'll need a corresponding material file:

```
materials/dither3d/opaque.vmat
materials/dither3d/cutout.vmat
materials/dither3d/particles.vmat
```

#### Step 4: Test and Iterate

1. Import shaders into s&box project
2. Create test materials
3. Apply to simple geometry
4. Debug any compilation errors
5. Adjust based on s&box's specific requirements

## Shader Permutations

The shaders support compile-time permutations via `#define` statements:

| Define | Effect |
|--------|--------|
| `DITHERCOL_GRAYSCALE` | Single-channel grayscale dithering |
| `DITHERCOL_RGB` | Separate RGB channel dithering |
| `DITHERCOL_CMYK` | CMYK printing-style with angled screens |
| `INVERSE_DOTS` | Invert the dot pattern |
| `RADIAL_COMPENSATION` | Compensate for screen edge distortion |
| `QUANTIZE_LAYERS` | Use discrete layers (no interpolation) |
| `DEBUG_FRACTAL` | Visualize fractal UV coordinates |

In s&box, you'll create separate shader permutations or material variants for each combination you need.

## File Structure for Your s&box Project

```
your-sbox-project/
├── code/
│   └── shaders/
│       ├── dither3d_common.hlsl      ← Core algorithm
│       ├── dither3d_opaque.shader    ← Opaque surfaces
│       ├── dither3d_cutout.shader    ← Alpha-tested surfaces  
│       └── dither3d_particles.shader ← Particles
├── materials/
│   └── dither3d/
│       ├── opaque.vmat               ← Material definitions
│       ├── cutout.vmat
│       └── particles.vmat
└── textures/
    └── dither3d/
        ├── Dither3D_8x8.vtex         ← 3D dither texture
        └── Dither3D_Ramp.vtex        ← Brightness ramp
```

## Common Issues & Solutions

### Issue: Shader won't compile
**Solution**: Check s&box's shader documentation for correct syntax. The templates use standard HLSL but s&box may have specific requirements.

### Issue: 3D textures not working
**Solution**: Ensure textures are imported as 3D textures (not 2D arrays). May need special import settings.

### Issue: Screen position incorrect
**Solution**: s&box may calculate screen coordinates differently. Check how other shaders access screen position.

### Issue: Matrix transformations wrong
**Solution**: Replace Unity matrices with s&box equivalents. Look at existing s&box shaders for examples.

## Resources

- **s&box Wiki**: https://wiki.sbox.game/
- **Dither3D Original**: https://github.com/runevision/Dither3D
- **Your Unity Dither3D**: `/workspace/Assets/Dither3D/`

## Need Help?

Ask me to:
1. Create a 3D texture generation script
2. Create material definition files (.vmat format)
3. Adapt shaders once you know s&box's exact requirements
4. Create a C# component to manage dithering properties
