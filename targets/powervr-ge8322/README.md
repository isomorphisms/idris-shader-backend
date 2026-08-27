# PowerVR GE8322 / GLSL ES target

This branch is the reference GPU follower target for the actual Android Go phone work.

The public device/model identification points at a UNISOC SC9863-family SoC with a PowerVR GE8322 GPU. Treat that marketing identification as provisional until the phone acceptance receipt records `GL_VENDOR`, `GL_RENDERER`, `GL_VERSION`, `GL_SHADING_LANGUAGE_VERSION`, extensions, and limits from the real device. The existing `tools/accept_powervr_phone.sh` path on this branch is the hardware oracle.

## Compiler boundary

```text
Idriç/Idris numerical shader subset
        ↓
typed shader IR
        ↓
GLSL ES 3.00 source
        ↓
Android GLES driver
        ↓
PowerVR compiler / USC code
        ↓
PowerVR GE8322-class Rogue/Series8XE hardware
```

The target we own is the typed shader IR → GLSL ES boundary. We also inventory the GLES host API because it determines how generated shaders are compiled, linked, supplied resources, drawn, and measured.

Do not pretend the public PowerVR documentation is a complete native ISA specification. Imagination publishes useful Rogue/Series8XE architecture and low-level GLSL material, including USC/SOP/MAD behavior, but explicitly notes that precise feature availability belongs to the full ISR. Therefore `SURFACE.txt` is exhaustive for the pinned public GLSL ES 3.00 + OpenGL ES 3.0 compiler/runtime contract, while `families/precision-and-usc.md` records only publicly documented hardware facts.

The OpenGL ES host side is mechanically checkable rather than only handwritten: `tools/extract_gles30_surface.py` consumes Khronos `xml/gl.xml` and emits all commands and enumerants required by core GLES features through 3.0. Extensions and later ES versions are excluded from that baseline.

## Pinned references

- Khronos OpenGL Registry `gl.xml`: https://github.com/KhronosGroup/OpenGL-Registry/blob/main/xml/gl.xml
- Khronos OpenGL ES 3.0 registry: https://registry.khronos.org/OpenGL/specs/es/3.0/
- GLSL ES 3.00 specification: https://registry.khronos.org/OpenGL/specs/es/3.0/GLSL_ES_Specification_3.00.pdf
- PowerVR low-level GLSL guide: https://docs.imgtec.com/performance-guides/low-level-glsl/html/index.html
- PowerVR Rogue overview: https://docs.imgtec.com/performance-guides/low-level-glsl/html/topics/overview/rogue/overview-rogue.html
- PowerVR architecture guide: https://docs.imgtec.com/starter-guides/powervr-architecture/html/index.html
- Public PowerVR instruction-set architecture information: https://docs.imgtec.com/reference-manuals/powervr-instruction-set-reference/html/topics/general-architecture-information.html

## Files

- `SURFACE.txt` — flat compiler-visible GLSL ES 3.00 operations plus the GLES 3.0 core host command names.
- `tools/extract_gles30_surface.py` — mechanical completeness checker for GLES 3.0 core host commands/enumerants.
- `families/glsl-language.md` — language/types/control/math families.
- `families/resources-and-pipeline.md` — uniforms, buffers, textures, framebuffer and host pipeline boundary.
- `families/precision-and-usc.md` — PowerVR-specific FP16/FP32 and public USC execution facts.

## Follower rule

The common shader IR is primary. PowerVR-specific lowering may choose precision, expression shape, packing and resource representation, but it must not leak PowerVR assumptions upward into the mathematical source language.