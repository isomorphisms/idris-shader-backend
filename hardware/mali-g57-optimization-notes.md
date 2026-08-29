# Mali-G57 optimization notes

Target branch: `target/mali-g57-mc1-valhall`

These notes separate optimizations justified by the physical tablet from generic Valhall guidance and from guesses that still need measurement.

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

Those are compiler-visible facts for this target. They may be used as capability gates without guessing from the product name.

## Implemented: explicit narrow-float choice

The GLSL ES emitter used to hard-code:

```glsl
precision highp float;
```

for every shader. The backend now accepts an explicit compiler directive:

```text
--directive float-precision=mediump
```

and retains `highp` as the compatibility default.

This is deliberately opt-in. The Vulkan profile proves native Float16 exists on this device, and Arm's Valhall guidance treats narrow FP16 arithmetic as a major throughput and register-pressure optimization, but the GLSL ES `mediump` contract is not being silently equated with exact IEEE binary16 semantics for every shader. A shader should only be narrowed when its numerical error budget permits it.

The next precision step is to move the choice from a whole-shader directive into the typed shader IR so individual values can remain narrow or wide intentionally.

## Implemented: keep expensive branch work behind real control flow

The ANF lowering still represents an Idris boolean case as a typed `RSelect`, which is a useful simple semantic form. A structure-recovery pass before GLSL emission now distinguishes cheap selection from expensive branch-local work.

For each select it follows the typed local-dependency chains of the two results, keeps shared or externally used values outside the branch, and estimates the cost of the work which is genuinely exclusive to each side. Cheap scalar choices stay readable GLSL ternaries. A sufficiently expensive pure branch becomes a real `if`/`else`, with its exclusive temporaries emitted inside the branch.

`DiscReveal` is the first useful real case. For a negative disc radius the shader now tests the no-mask sentinel before computing world coordinates, distance, `sqrt`, boundary width, and clamp work. The later gray texture still needs `v_ndc` and resolution, so those inexpensive values are read again after the branch instead of forcing the expensive distance chain to remain live outside it.

A separate structured-branch fixture verifies that expensive `sqrt`/`sin` work occurs after the `if`, while the existing compiler-sphere fixture verifies that cheap conditionals remain ternary selects.

The present recovery implementation uses simple list searches and is deliberately capped at 256 bindings. Larger shader bodies remain in the existing linear select form rather than paying pathological compiler time. Removing that cap requires a linear-time liveness/use analysis or preserving structured cases earlier in lowering; do not simply raise the number.

The present cost weights are deliberately small and inspectable rather than a claim about exact Mali cycle counts. Tune them only after examining generated code or measurements from the Mali toolchain/tablet.

## Highest-confidence next passes

### 1. Per-value Float16 / Float32 types

Replace the single undifferentiated float type with a representation that carries precision intent through lowering. Keep widening explicit. Do not lower every `Double` to Float16 just because the target supports it.

Useful first candidates for narrow arithmetic are final color formation, bounded interpolation weights, normalized local coordinates, and other values whose error budget is visibly much looser than the sensitive complex-analysis path.

### 2. Register-pressure gate

Arm's Mali Offline Compiler reports work-register use and stack spilling for Valhall. Add a target check that records these for representative generated shaders. Treat crossing a register-allocation/occupancy boundary or introducing spills as a regression even when static instruction count falls.

Do not encode a guessed register allocator model in Idriç. Let the target compiler remain authoritative and use its reported result as an oracle.

### 3. Subgroup-aware compute shapes

The device reports a fixed subgroup width of 16. Compute workgroup candidates should therefore be multiples of 16 and remain within the 512-invocation limit. Do not simply choose 512: compare sensible candidates such as 64, 128, and 256 against register use, shared-memory use, and occupancy.

### 4. 8-bit dot-product path

Where a later workload genuinely has quantized integer dot products, prefer the device's reported accelerated 8-bit signed/unsigned and packed 4x8 forms. Do not route floating-point geometry through integer quantization merely to use this unit.

## Public architecture references

- Arm, *The Valhall shader core guide*, document 102203.
- Arm, *Mali Offline Compiler User Guide*, document 101863.
- Arm, *Mali-G57 Performance Counters Reference Guide*, document 102659.

The optimization contract for this branch remains: capability facts come from the physical device dump; architecture guidance can suggest transformations; performance claims require generated-shader inspection or measurement on the tablet.
