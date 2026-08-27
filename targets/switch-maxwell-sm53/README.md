# Original Nintendo Switch: Tegra X1 / Maxwell GM20x / deko3d

This branch is the shader/GPU target for the **original Nintendo Switch family** built around NVIDIA Tegra X1/X1+ and Maxwell-generation graphics. It deliberately does not cover Switch 2 / Ampere.

## Compiler and runtime boundary

```text
Idriç/Idris shader subset
        ↓
shared typed shader IR
        ↓
UAM-compatible GLSL
        ↓
UAM: Mesa GLSL parser → TGSI → nouveau nv50_ir GM20x codegen
        ↓
DKSH shader module / raw Maxwell bytecode
        ↓
deko3d command/resource API
        ↓
Tegra X1 GM20x Maxwell GPU
```

The CPU target remains AArch64 and belongs elsewhere. This branch owns shader semantics, the GLSL/UAM lowering contract, and the GPU-facing public deko3d boundary.

## Why this is a particularly useful follower

UAM can emit three inspectable levels: intermediary TGSI, final `.dksh`, and raw Maxwell bytecode. That gives us a much stronger compiler oracle than a generic driver-only GLSL path. We can compare the same shared shader IR against PowerVR GLSL ES and against the actual GM20x-oriented code produced for Switch.

UAM explicitly targets the Tegra X1 in Switch, is based on Mesa's GLSL/TGSI infrastructure plus nouveau `nv50_ir`, and inherits the GM20x feature set with deko3d-specific changes. It supports vertex, tessellation-control, tessellation-evaluation, geometry, fragment, and compute stages.

## Important UAM/deko3d differences from ordinary GL

- UBO, SSBO, sampler and image bindings must be explicit.
- Per stage: 16 UBOs, 16 SSBOs, 32 combined sampler handles and 8 images.
- Compute UBO bindings 0–5 are native; 6–15 are emulated through the SSBO route.
- Default uniforms outside UBO blocks are rejected.
- There is no ordinary shader-linking phase; separable-program behavior is always in effect.
- Transform feedback and GLSL shader subroutines are unsupported.
- Nonconstant integer division/modulo decays to floating division with a warning.
- UAM contains Maxwell-specific codegen changes including dual-issue scheduling, LDG/STG for SSBO access, TXQ use for multisample image queries, and explicit PT-predicate optimizations.

## Public-native-code boundary

NVIDIA does not provide this project with a normative, complete Maxwell SASS architecture manual comparable to Arm's public ISA manuals. However, UAM carries the actual GM107/GM20x nouveau code emitter it uses. `SURFACE.txt` therefore records both:

1. the public deko3d C API verbs and principal option families; and
2. the native-emitter operation families present in UAM's `CodeEmitterGM107` implementation.

`DEKO3D-OPTIONS.txt` expands the public deko3d option/enumerant side, while `tools/extract_deko3d_surface.py` mechanically extracts all `dk*` public verbs, `Dk*` enumerants and `DK_*` public constants from a pinned `deko3d.h`. That extractor is the completeness oracle when the header evolves.

The native-emitter list is an executable reverse-engineered compiler surface, not a claim that it exhausts every undocumented hardware encoding the chip might accept.

## Pinned references

- UAM: https://github.com/devkitPro/uam
- deko3d: https://github.com/devkitPro/deko3d
- UAM GM107 emitter: https://github.com/devkitPro/uam/blob/master/mesa-imported/codegen/nv50_ir_emit_gm107.cpp
- Switch platform note: https://github.com/isomorphisms/idric-embedded/tree/switch

## Files

- `SURFACE.txt` — flat UAM/deko3d/native-emitter operation surface.
- `DEKO3D-OPTIONS.txt` — public deko3d options, enumerants, helper verbs and constants.
- `tools/extract_deko3d_surface.py` — mechanical completeness checker for the public deko3d header.
- `families/uam-and-glsl.md` — source-language and compiler boundary.
- `families/deko3d-api.md` — command/resource API families.
- `families/maxwell-sm53.md` — GM20x execution/codegen families and compiler consequences.
