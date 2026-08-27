# WGSL language families

WGSL is the source language accepted by WebGPU shader modules. It is strongly typed, structured and deliberately more constrained than a general CPU language. The compiler should target WGSL semantics directly rather than transliterating GLSL tokens.

## Types and constructors

The core concrete scalar types are `bool`, `i32`, `u32` and `f32`; `f16` is enabled through the `f16` WGSL extension backed by the WebGPU `shader-f16` device feature. WGSL also has abstract integer/floating values during expression/type inference. Vectors, matrices, arrays, structures, atomics, pointers, buffers, textures and samplers make up the compound/resource type system.

Constructors and conversions are ordinary built-in functions. This makes target precision especially explicit: an Idriç `Float16` should become `f16` only when the generated module enables `f16` and the requested device actually enabled `shader-f16`.

## Directives and language evolution

`enable` requests hardware-backed WGSL extensions such as `f16`, subgroups or clip distances. `requires` documents use of language extensions that implementations may support without a WebGPU device feature. The August 2026 language-extension set includes pointer/composite improvements, storage-texture access modes, packed 4x8 integer dot products, standard uniform layout, subgroup refinements, texture/sampler lets, tier-1 formats, linear indexing, the immediate address space, fragment-depth modes, buffer views and swizzle assignment.

This split is important to generated code. “The grammar knows this spelling” is not enough: the backend has to know whether it is universally available, requires a WGSL language feature, or requires a WebGPU device feature.

## Structured control

The language supplies `if`, `switch`, `loop`, `for`, `while`, `break`, `continue`, `continuing`, `return` and fragment `discard`. `const_assert` provides compile-time assertions. There is no reason to turn arbitrary Idriç recursion into WGSL merely because loops exist; bounded/finitely checkable GPU computation remains a useful source restriction.

## Numerical operations

WGSL has a broad numerical built-in family: trig/hyperbolic, exponential/logarithmic, rounding, min/max/clamp/mix, vector geometry, matrix operations, bit counting/extraction/insertion, fused multiply-add, half quantization, packed 8-bit dot products and pack/unpack operations. Preserve meaningful operations such as `fma`, `inverseSqrt`, `dot`, saturation and packed-dot intent in the shared IR rather than immediately scalarizing them.

## Textures and derivatives

Texture operations distinguish querying, loading/storing, implicit sampling, explicit LOD, gradients, comparison sampling and gathering. Derivative operations have ordinary/coarse/fine forms. These operations depend on shader-stage execution context and uniformity rules; they are not interchangeable with ordinary pure scalar function calls.

## Atomics and synchronization

WGSL atomics include load/store, arithmetic/logical read-modify-write, exchange and weak compare-exchange. Synchronization has storage, texture and workgroup barriers plus `workgroupUniformLoad`. Atomic and barrier behavior is constrained by WGSL's memory model and scopes, so a future parallel Idriç IR should represent ordering/resource intent rather than only a generic “atomic” or “barrier” node.

## Subgroups and quads

When the `subgroups` extension/device feature is enabled, WGSL exposes votes, ballots, broadcast, shuffle, reductions/scans and quad exchange operations. Subgroup size is not generally a portable constant; optional subgroup-size control exists separately. This is a semantic layer above native warp/wave instructions on NVIDIA/AMD hardware.

## Buffer views and immediate data

The August 2026 draft includes two particularly interesting newer facilities.

`bufferView`, `bufferArrayView` and `bufferLength` let a shader reinterpret opaque buffer storage as typed host-shareable views when the `buffer_view` language extension is supported.

The `immediate` address space, enabled by the `immediate_address_space` language extension, gives an entry point one small host-populated immutable data object. WebGPU records its bytes with `setImmediates`. This is closer to a small push-data boundary than to an ordinary bound uniform buffer, and should remain a distinct interface class in the compiler IR.

## References

- https://www.w3.org/TR/WGSL/
- built-in function index: section 17
- keyword/token summary: section 16
- directives/extensions: section 4
- memory model: section 14