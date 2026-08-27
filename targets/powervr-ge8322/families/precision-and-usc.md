# PowerVR precision and public USC facts

## Hardware classification

The GE8322 is publicly identified with the PowerVR Rogue/Series8XE lineage. The exact shipping device remains a runtime acceptance question: specialize only after the phone reports its actual renderer and extensions.

PowerVR is a tile-based renderer. For the full-screen mathematical shaders in this repository, that usually makes repeated arithmetic, register pressure, precision choice and temporary resource traffic more interesting than traditional overdraw assumptions.

## `mediump` and FP16

Imagination's architecture guidance states that `mediump` shader floating variables are represented as FP16 on the relevant PowerVR path and recommends lower precision where its range and error are sufficient. The low-level guide describes a strong FP16 SOP/MAD route and states that conversion around that path can be effectively free in the documented cases.

This is why `Float16` must remain visible in the source/IR. It is not merely a storage annotation. At the same time, `mediump` is a shader-language contract, not permission to assume arbitrary IEEE binary16 behavior everywhere. Numerical oracles still decide where it is safe.

## Publicly documented operation families

The public Rogue low-level guide exposes enough of the USC pipeline to reason about expression shape. It discusses FP16 SOP/MAD, FP32 MAD, integer MAD/unpack work, move/output/pack paths, conditional tests, bitwise work, reciprocal, reciprocal-square-root, exponential/log operations and texture/interpolation operations.

Examples from the public guide include:

- two FP16 SOP operations can be packed into a documented single-cycle route;
- four FP16 MAD operations can be issued in a documented packed form;
- FP32 MAD can coexist with other pipeline work in the documented route;
- reciprocal (`RCP`) and inverse-square-root (`RSQ`) are direct operations;
- `sqrt` is commonly expressed using RSQ plus reciprocal;
- `exp2` and `log2` map particularly directly to the documented transcendental path;
- input `abs`/negation and output saturation can sometimes be folded as modifiers rather than becoming standalone moves.

These facts justify target-specific pattern selection, but they do not justify inventing a complete GE8322 native opcode table. Imagination's public instruction-set reference explicitly says precise feature availability belongs to the fuller ISR.

## Compiler consequences

Preserve semantic operations such as reciprocal, inverse-square-root, clamp/saturate, fused multiply-add intent, dot products and precision classes until late lowering. Then measure whether a PowerVR-specific spelling actually produces the intended driver output. The GLSL text is an instruction to a compiler, not the USC instruction itself.

For the analytic-continuation and Wegert workloads, especially inspect:

- complex multiply/add chains for SOP/MAD packing;
- squared norms where a square root is unnecessary;
- `inversesqrt(dot(x,x))` where normalization is needed;
- FP16 coefficients/interpolation versus FP32 Newton residuals and small denominators;
- register pressure from polynomial recurrence and fixed iteration;
- whether persistent RG16F/RG32F state saves enough ALU to justify memory traffic.

## References

- https://docs.imgtec.com/performance-guides/low-level-glsl/html/topics/overview/rogue/overview-rogue.html
- https://docs.imgtec.com/performance-guides/low-level-glsl/html/topics/exploiting-the-sop-mad-fp16-pipeline.html
- https://docs.imgtec.com/performance-guides/low-level-glsl/html/topics/overview/rogue/rcp-rsqrt-sqrt.html
- https://docs.imgtec.com/starter-guides/powervr-architecture/html/topics/rules/do-prefer-lower-data-precision.html
- https://docs.imgtec.com/reference-manuals/powervr-instruction-set-reference/html/topics/general-architecture-information.html