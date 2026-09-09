# Mali-G57 optimization notes

Target branch: `target/mali-g57-mc1-valhall`

These notes separate facts justified by the physical tablet from generic Valhall guidance and from performance claims that still require measurement.

## Verified on the tablet

The checked-in Vulkan profile reports:

- Mali-G57, Arm proprietary driver r51p0;
- fixed subgroup size 16;
- shader Float16 support;
- 16-bit storage in buffers, push constants, and shader input/output;
- Float16 RTE and RTZ rounding modes;
- 512 maximum compute workgroup invocations;
- 32 KiB maximum compute shared memory;
- accelerated signed and unsigned 8-bit integer dot products, including packed 4x8 forms;
- no shader Float64.

Those are compiler-visible target facts. They do not by themselves prove performance.

## Implemented: explicit shader precision

The GLSL ES emitter used to hard-code:

```glsl
precision highp float;
```

The backend now accepts:

```text
--directive float-precision=lowp
--directive float-precision=mediump
--directive float-precision=highp
```

`highp` remains the compatibility default for this branch, but applications can request `lowp` directly. Precision choice is kept separate from the mathematical/type semantics: a GLSL precision qualifier is an execution/lowering choice, not the definition of a real or complex number.

For the current Analytic Continuation experiment, lowp is an intentional application choice. The important performance fix is control flow, not precision promotion.

## Implemented: keep expensive branch work behind real control flow

ANF lowering still represents an Idris boolean case as a typed `RSelect`. Eager linear emission used to calculate branch-local work before selecting a result. That is especially bad for fragment operations such as `atan`, `log`, `sqrt`, and `pow`.

The structure-recovery pass now follows both result dependency chains, separates shared from exclusive work, identifies values required by code outside the branch, protects the full dependency closure of those values, and moves only a closed branch-local subgraph. Cheap selections can remain ternaries; expensive pure work becomes real GLSL `if`/`else` control flow.

`DiscReveal` remains a small acceptance fixture. The more important large acceptance is the current Analytic Continuation typed core.

### Large-fragment result

The first structure-recovery prototype was capped at 256 bindings because repeated dependency searches became pathologically slow. That global cutoff has been removed. Dependency discovery now walks backwards over the already-emitted prefix.

The current Analytic Continuation fixture contains 1,159 typed-IR lines. The generated Mali shader now contains:

- 64 `atan` calls, all 64 inside recovered branches;
- 64 `log` calls, all 64 inside recovered branches;
- 68 real GLSL `if` blocks;
- 0 ternary selects for this workload.

The highp and lowp versions have the same control-flow structure. The cross-repository structured-backend probe run `34311467111` validates both versions, as well as the matching generic-backend versions.

The present cost weights remain small, inspectable heuristics rather than claimed Mali cycle counts. Device measurement remains authoritative.

## Highest-confidence next passes

### 1. Physical tablet timing

Run the improved lowp fragment on the Mali-G57 tablet and measure frame time and touch-to-visible-frame latency. The previous generated fragment's greater-than-one-second interaction delay is the practical regression to eliminate.

### 2. Register-pressure gate

Arm's Mali Offline Compiler reports work-register use and stack spilling for Valhall. Record these for representative generated shaders. Treat introduced spills or occupancy-boundary regressions as failures even when GLSL text becomes shorter.

Do not encode a guessed Mali register allocator in Idriç; use the target compiler as the oracle.

### 3. Preserve source structure earlier

The current recovery pass repairs useful control flow after ANF flattening. A cleaner future path is to preserve bounded loops/cases earlier in lowering where that gives a smaller and more direct shader IR. Do not regress the current large-fragment acceptance while doing so.

### 4. Subgroup-aware compute shapes

The device reports fixed subgroup width 16. Compute workgroup candidates should be multiples of 16 and stay within the 512-invocation limit. Compare practical candidates rather than assuming the maximum is best.

### 5. 8-bit dot-product path

For later genuinely quantized workloads, use the reported accelerated signed/unsigned packed dot products. Do not quantize floating geometry merely to reach that unit.

## Public architecture references

- Arm, *The Valhall shader core guide*, document 102203.
- Arm, *Mali Offline Compiler User Guide*, document 101863.
- Arm, *Mali-G57 Performance Counters Reference Guide*, document 102659.

The optimization contract remains: capability facts come from the physical device dump; architecture guidance can suggest transformations; performance claims require generated-shader inspection or measurement on the tablet.
