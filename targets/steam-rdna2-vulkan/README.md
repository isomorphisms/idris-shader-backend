# Steam Deck RDNA2 / Vulkan / SPIR-V target

This branch is the native-PC GPU follower for the Steam Deck family. Valve specifies an AMD APU with an RDNA 2 GPU containing 8 compute units. CPU/x86-64 work remains outside this shader branch.

## Pinned compiler boundary

```text
Idriç/Idris shader subset
        ↓
shared typed shader IR
        ↓
Vulkan GLSL
        ↓
glslang/glslc
        ↓
SPIR-V 1.6 module
        ↓
Vulkan 1.4 shader/pipeline API
        ↓
AMD Linux driver
        ↓
RDNA 2 ISA
```

The first implementation should use Khronos tooling to produce SPIR-V rather than hand-encode the binary. SPIR-V remains important enough to inventory completely because it is the stable compiler/runtime boundary that Vulkan actually consumes.

## Standards snapshot

- Vulkan registry: current Vulkan 1.4 core registry (`vk.xml`).
- SPIR-V: 1.6 Revision 7 (`spirv.core.grammar.json`).
- GLSL: GLSL 4.60, constrained by the Vulkan environment rules.
- Hardware: AMD RDNA 2 ISA Reference Guide, document 70648.

Extensions are deliberately separate. This branch inventories the **core shader/compiler/pipeline contract** first. Swapchain/window-system extensions belong to the Steam platform layer; ray tracing, mesh shading and vendor extensions are later capability branches rather than silently part of baseline code generation.

## Exact-surface policy

`VULKAN-GLSL-SURFACE.txt` states the source language the first emitter is willing to print: GLSL 4.60 operations plus Vulkan-specific resource/interface layout forms, with generic desktop-GL compatibility assumptions excluded.

`SURFACE.txt` lists the post-GLSL core Vulkan/SPIR-V operations. Because Vulkan and SPIR-V evolve from machine-readable registries, `tools/extract_registry_surface.py` is also checked in: given Khronos `vk.xml` and `spirv.core.grammar.json`, it extracts the authoritative core command/opcode names. The registry extraction is the completeness oracle rather than relying forever on a handwritten list.

Generated GLSL must be compiled for an explicitly pinned Vulkan target environment and the resulting SPIR-V must validate for that same environment. This keeps “legal generic GLSL” distinct from “legal Vulkan shader.”

## RDNA2 boundary

AMD publishes a real RDNA2 ISA reference, so this branch can go lower than the PowerVR branch without pretending. The hardware commentary records scalar/vector ALU, branch/control, scalar/global/local memory, export, interpolation, data-share, wave and synchronization families. It does not make direct RDNA2 emission the first milestone; initial code should remain GLSL → SPIR-V → Vulkan driver.

## Files

- `VULKAN-GLSL-SURFACE.txt` — flat source-language operations and Vulkan interface/layout forms.
- `SURFACE.txt` — flat core Vulkan/SPIR-V/compiler-visible surface.
- `tools/extract_registry_surface.py` — mechanical completeness checker for Khronos Vulkan/SPIR-V registries.
- `families/vulkan-glsl.md` — Vulkan-constrained GLSL source-language family.
- `families/spirv.md` — SPIR-V module and instruction families.
- `families/vulkan-pipeline.md` — host shader/pipeline/resource command families.
- `families/rdna2.md` — AMD hardware execution and ISA families.

## References

- https://registry.khronos.org/vulkan/
- https://github.com/KhronosGroup/Vulkan-Headers/blob/main/registry/vk.xml
- https://github.com/KhronosGroup/SPIRV-Headers/blob/main/include/spirv/unified1/spirv.core.grammar.json
- https://registry.khronos.org/SPIR-V/specs/unified1/SPIRV.html
- https://registry.khronos.org/OpenGL/specs/gl/GLSLangSpec.4.60.pdf
- https://github.com/KhronosGroup/glslang
- https://docs.amd.com/v/u/en-US/rdna2-shader-instruction-set-architecture
- https://www.steamdeck.com/tech