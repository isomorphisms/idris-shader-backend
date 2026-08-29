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

## First compiler optimization: preserve narrow-float intent

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

The next precision step should move the choice from a whole-shader directive into the typed shader IR so individual values can remain narrow or wide intentionally.

## Highest-confidence next passes

### 1. Per-value Float16 / Float32 types

Replace the single undifferentiated float type with a representation that carries precision intent through lowering. Keep widening explicit. Do not lower every `Double` to Float16 just because the target supports it.

Useful first candidates for narrow arithmetic are final color formation, bounded interpolation weights, normalized local coordinates, and other values whose error budget is visibly much looser than the sensitive complex-analysis path.

### 2. Register-pressure gate

Arm's Mali Offline Compiler reports exact work-register use and stack spilling for Valhall. Add a target check that records these for representative generated shaders. Treat crossing a register-allocation/occupancy boundary or introducing spills as a regression even when static instruction count falls.

Do not encode a guessed register allocator model in Idriç. Let the driver compiler remain authoritative and use its reported result as an oracle.

### 3. Keep expensive exceptional work behind real control flow

The current ANF lowering turns Idris boolean cases into precomputed branch values followed by a GLSL ternary. This can make both branches execute before selection. That is hostile to the intended ordinary-region / exceptional-region renderer split.

Preserve structured control flow when either branch contains substantial work. Keep cheap scalar selects as selects. The target rule should be based on branch cost and divergence, not on a blanket preference for either `if` or `?:`.

### 4. Subgroup-aware compute shapes

The device reports a fixed subgroup width of 16. Compute workgroup candidates should therefore be multiples of 16 and remain within the 512-invocation limit. Do not simply choose 512: compare sensible candidates such as 64, 128, and 256 against register use, shared-memory use, and occupancy.

### 5. 8-bit dot-product path

Where a later workload genuinely has quantized integer dot products, prefer the device's reported accelerated 8-bit signed/unsigned and packed 4x8 forms. Do not route floating-point geometry through integer quantization merely to use this unit.

## Public architecture references

- Arm, *The Valhall shader core guide*, document 102203.
- Arm, *Mali Offline Compiler User Guide*, document 101863.
- Arm, *Mali-G57 Performance Counters Reference Guide*, document 102659.

The optimization contract for this branch remains: capability facts come from the physical device dump; architecture guidance can suggest transformations; performance claims require generated-shader inspection or measurement on the tablet.
