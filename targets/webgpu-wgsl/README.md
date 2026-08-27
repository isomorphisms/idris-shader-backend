# WebGPU / WGSL target

This branch owns the compiler-facing WebGPU shader target. `WebGPU` is a portable host API and command model; `WGSL` is the shading language supplied to it. Neither is a hardware ISA.

## Boundary

```text
Idriç/Idris host code → Wasm/native host backend → WebGPU API

Idriç/Idris shader subset
        ↓
shared typed shader IR
        ↓
WGSL
        ↓
GPUShaderModule / WebGPU implementation
        ↓
implementation-specific Vulkan/D3D12/Metal/etc. lowering
        ↓
actual GPU ISA
```

This branch owns the second path plus enough of the WebGPU host API to prove generated WGSL actually validates, dispatches/renders and produces an exact oracle.

## Pinned 2026 standards snapshot

- WGSL W3C Candidate Recommendation Draft, 25 August 2026: https://www.w3.org/TR/WGSL/
- current WebGPU editor draft: https://gpuweb.github.io/gpuweb/
- generated WebGPU TypeScript API snapshot `gpuweb/types` 0.1.72, commit `bcb683e961c619ae5ecf6696e55507602a07609e`: https://github.com/gpuweb/types

The August 2026 WGSL surface includes compute, vertex and fragment stages; subgroup and quad operations; and the newer buffer-view built-ins `bufferView`, `bufferArrayView` and `bufferLength`.

## Complete-surface rule

`SURFACE.txt` is the readable flat list of WGSL operations plus WebGPU API verbs and option sets. `tools/extract_webgpu_types.py` is the mechanical completeness oracle for the host API: give it the pinned `dist/index.d.ts` and it emits interface methods, string-union options and constant namespaces without hand-maintained omissions.

For WGSL, the W3C specification's keyword/token summary and built-in-function index are normative. The flat file follows those named operations and records feature-gated families instead of pretending every implementation exposes them unconditionally.

## First executable slice

Start with compute:

1. `u32`, `i32`, `f32`;
2. locals/functions/basic arithmetic and comparisons;
3. one `@compute` entry point and fixed `@workgroup_size`;
4. `@builtin(global_invocation_id)`;
5. one or two storage buffers;
6. indexed loads/stores;
7. exact readback oracle such as `out[i] = in[i] + 1`.

Do not require textures, atomics, subgroups, `f16`, buffer views or rendering in the first slice. They remain fully inventoried so the backend can grow into them deliberately.

## Files

- `SURFACE.txt` — flat WGSL/WebGPU verbs and options.
- `tools/extract_webgpu_types.py` — mechanical API/options extractor for the pinned generated types.
- `families/wgsl-language.md` — language and built-in operation families.
- `families/webgpu-api.md` — host API/resource/command families.
- `families/memory-and-execution.md` — address spaces, workgroups, uniformity, barriers, subgroups and precision.

## Repository ownership

The old `idric-embedded/webgpu` branch remains useful as a platform/runtime breadcrumb, but WGSL emission belongs here beside the other shader backends rather than being modeled as an embedded CPU architecture.