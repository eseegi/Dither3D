# Complete Guide: Migrating Dither3D to s&box

## Overview

This guide will help you migrate the Surface-Stable Fractal Dithering (Dither3D) from Unity to s&box so you can use it in your s&box games. The process involves converting shaders, textures, and C# scripts to work with s&box's Source 2-based engine.

---

## Table of Contents

1. [Understanding the Differences](#1-understanding-the-differences)
2. [Prerequisites](#2-prerequisites)
3. [Step-by-Step Migration](#3-step-by-step-migration)
4. [File Structure](#4-file-structure)
5. [Testing & Validation](#5-testing--validation)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Understanding the Differences

### Unity vs s&box Architecture

| Aspect | Unity | s&box (Source 2) |
|--------|-------|------------------|
| **Shader Language** | CG/HLSL with Unity macros | Pure HLSL |
| **Shader Model** | Surface shaders or Vertex/Fragment | VRF (Vertex) + PSF (Pixel) |
| **3D Textures** | `sampler3D`, `tex3D()` | `Texture3D<T>`, `.SampleLevel()` |
| **Material System** | Material properties & keywords | Material parameters & defines |
| **Scripting** | MonoBehaviour, Editor scripts | Component, Tool attributes |
| **Build Pipeline** | AssetDatabase, BuildPlayer | Resource compiler, vpk packaging |

### Key Dither3D Components to Port

1. **Dither3DInclude.cginc** - Core dithering algorithm (HLSL)
2. **Shader files** (.shader) - Need conversion to s&box shader format
3. **Dither3DTextureMaker.cs** - 3D texture generation (C#)
4. **Dither3DGlobalProperties.cs** - Global property management (C#)
5. **3D Textures** (.asset) - Need regeneration in s&box format

---

## 2. Prerequisites

### Required Tools & Knowledge

- **s&box installed** with latest updates
- **Visual Studio** or VS Code with C# support
- **Basic HLSL knowledge** (shaders, derivatives, texture sampling)
- **Understanding of s&box's**:
  - Shader compilation pipeline
  - Material system (.vmat files)
  - Component system
  - Resource types (.vtex, .vrf, .psf)

### Recommended Resources

- [s&box Documentation](https://wiki.sbox.game/)
- [s&box Shader Guide](https://wiki.sbox.game/shaders/introduction)
- [Source 2 Shader Examples](https://github.com/sbox-org/sbox-shaders)
- [Dither3D Original Repository](https://github.com/runevision/Dither3D)

---

## 3. Step-by-Step Migration

### Phase 1: Set Up Project Structure

Create the following folder structure in your s&box project:

```
your-sbox-project/
├── code/
│   └── Dither3D/
│       ├── Dither3D_Include.hlsl
│       ├── Dither3DTextureGenerator.cs
│       └── Dither3DComponent.cs
├── materials/
│   └── dither3d/
│       ├── dither3d_opaque.vmat
│       ├── dither3d_cutout.vmat
│       └── dither3d_particles.vmat
└── textures/
    └── dither3d/
        ├── Dither3D_8x8.vtex_c (compiled 3D texture)
        └── Dither3D_Ramp.vtex_c (brightness ramp)
```

### Phase 2: Port the Core HLSL Include

Create `code/Dither3D/Dither3D_Include.hlsl`:

Key changes from Unity CGINC:
1. Replace `sampler3D` with `Texture3D<float4>` and `SamplerState`
2. Replace `tex3D()` with `.SampleLevel()`
3. Replace `tex2D()` with `.Sample()`
4. Remove Unity-specific macros (`UNITY_MATRIX_P`, etc.)
5. Add s&box-specific includes for screen position

### Phase 3: Create s&box Shaders

s&box uses a different shader model than Unity. You'll create shader files using the `.vfx` extension or standard HLSL with s&box conventions.

### Phase 4: Generate 3D Textures

Create `code/Dither3D/Dither3DTextureGenerator.cs` to generate Bayer pattern 3D textures programmatically.

### Phase 5: Create Global Properties Component

Create `code/Dither3D/Dither3DComponent.cs` to manage global dither settings.

### Phase 6: Create Material Files

Create material definition files (`.vmat`) in your materials folder with proper texture references and parameters.

---

## 4. File Structure Summary

After completing the migration, your project should have:

```
your-sbox-project/
├── code/
│   └── Dither3D/
│       ├── Dither3D_Include.hlsl         # Core dithering algorithm
│       ├── dither3d_opaque.vfx           # Opaque surface shader
│       ├── dither3d_cutout.vfx           # Cutout/alpha test shader
│       ├── dither3d_particles.vfx        # Particle additive shader
│       ├── Dither3DTextureGenerator.cs   # 3D texture generation
│       └── Dither3DComponent.cs          # Global properties component
├── materials/
│   └── dither3d/
│       ├── dither3d_opaque.vmat
│       ├── dither3d_cutout.vmat
│       └── dither3d_particles.vmat
└── textures/
    └── dither3d/
        ├── Dither3D_8x8.vtex_c
        ├── Dither3D_4x4.vtex_c
        └── Dither3D_Ramp.vtex_c
```

---

## 5. Testing & Validation

### Test Checklist

1. **3D Texture Generation** - Run texture generator, verify layers
2. **Shader Compilation** - Ensure all shaders compile without errors
3. **Material Application** - Apply materials to test objects
4. **Visual Validation** - Test surface stability and screen-space stability
5. **Performance Testing** - Profile shader performance

---

## 6. Troubleshooting

### Common Issues

**Issue: 3D texture not sampling correctly**
- Verify texture format is R8 (single channel)
- Check wrap mode is set to Repeat

**Issue: Shader compilation errors**
- Check all include paths are correct
- Verify material parameter names match shader

**Issue: Dots not appearing surface-stable**
- Verify screen-space derivatives are calculated correctly
- Check that UV coordinates match surface geometry

---

## License Notice

The original Dither3D implementation by Rune Skovbo Johansen is licensed under Mozilla Public License v2.0. Your s&box implementation must keep the same license for Dither3D code.

---

## Next Steps

1. Start with Phase 1 (project setup)
2. Implement the core HLSL include (Phase 2)
3. Create a minimal test shader
4. Generate 3D textures
5. Iterate and expand features

Good luck with your s&box game development!
