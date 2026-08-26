# Float semantics for the GLSL ES backend

The current compiler accepts Idris `Double` and emits GLSL ES `float`. That is not a promise of binary64 arithmetic. For this backend the existing path is **F32 semantics lowered to `highp float`**. This branch makes that contract explicit before adding mixed precision.

The broader cross-target record, including Arm `soft`, `softfp`, hard-float, scalar/vector execution, and PowerVR, lives in the ComputerScience repository at `floating-point/semantics.md` on the matching `float-semantics-f16-f32` branch.

## Semantic widths

- **F32**: the existing numerical path. GLSL ES representation is `highp float` / `highp vecN`.
- **F16**: a distinct semantic width. It is never an implicit synonym for F32 and F32→F16 demotion must be explicit.

The two widths may coexist in one shader. Arithmetic follows the width of its typed operands; mixed-width operations require an explicit conversion in the source/IR.

## GLSL ES caveat

Portable GLSL ES `mediump` specifies a minimum range and precision rather than an exact storage width on every implementation. Therefore the backend distinguishes an F16 semantic request from the generic portable `mediump` guarantee.

For a generic GLES target, F16 lowering is a relaxed-precision path unless stronger capability evidence exists. For PowerVR, Imagination documents `mediump` shader variables as FP16 and recommends them where range and precision are sufficient. Production selection must still be backed by device capability observations and framebuffer tests.

References:

- Khronos GLSL ES range and precision: https://registry.khronos.org/OpenGL/specs/es/3.2/GLSL_ES_Specification_3.20.html#precision
- Imagination PowerVR lower-precision guidance: https://docs.imgtec.com/starter-guides/powervr-architecture/html/topics/rules/do-prefer-lower-data-precision.html

## Orthogonal CPU ABI axis

The CPU reference/oracle can be built for Arm soft, softfp, or hard-float ABIs. Those modes do not change F16/F32 value semantics:

- `soft`: software arithmetic, base/core-register PCS;
- `softfp`: hardware arithmetic permitted, base/core-register PCS;
- `hard`: hardware arithmetic with the VFP procedure-call variant.

Vectorization is another independent axis. `Vec n F16` and `Vec n F32` lift scalar semantics lane-wise; reductions and FMA/contraction need explicit semantics because they can change rounding.

## Backend invariants

1. No unlabelled `Double`→GLSL narrowing in typed backend diagnostics.
2. F32 emits high precision explicitly.
3. F16 and F32 are distinct in backend policy/types before F16 production use is enabled.
4. No implicit F32→F16 conversion.
5. Vector width and float width are both preserved by lowering.
6. Portable GLES `mediump` is not claimed to be exact binary16 without target evidence.
7. PowerVR gets a target profile, not a global textual replacement of `highp` by `mediump`.
8. CPU width-controlled tests and real-device framebuffer tests decide equivalence.

## Implementation sequence

1. Name the existing compiler path F32 and centralize GLSL precision policy.
2. Add F16 as a distinct backend width and explicit F16↔F32 conversions.
3. Lift width through vectors and fixed arrays.
4. Add mixed-precision fixtures.
5. Add CPU F16/F32 oracle cases.
6. Capture PowerVR renderer/precision capabilities and compare framebuffer output.
7. Profile F16, F32, and mixed-precision variants on the real phone before changing production defaults.
