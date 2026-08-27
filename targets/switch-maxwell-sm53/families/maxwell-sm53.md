# Maxwell GM20x native code-generation families

The original Switch GPU is the Tegra X1 Maxwell-generation GM20x path targeted by UAM. For this project the most concrete public description of what can actually be emitted is UAM's own `CodeEmitterGM107`, inherited from nouveau and modified for Switch/deko3d.

## Control flow

The native emitter contains branch/call/return and structured reconvergence operations including `BRA`, `CAL`, `RET`, `EXIT`, `SSY`, `SYNC`, `PBK`, `BRK`, `PCNT`, `CONT`, `PRET`, `SAM` and `RAM`. Predicate registers are a first-class part of instruction emission rather than booleans living only in general registers.

For an aggressive compiler this is the GPU analogue of paying attention to CPU flags/predicates: a comparison whose only purpose is a later conditional need not necessarily materialize as a general scalar value.

## Conversion and movement

`MOV`, system-register transfers (`S2R`, `CS2R`), floating/integer conversions (`F2F`, `F2I`, `I2F`, `I2I`), selection and shuffle form the movement/conversion family. UAM specifically prefers `MOV Rd,RZ` to `MOV32I Rd,0` to match observed target code.

## Floating point

Double-family emitters include `DADD`, `DMUL`, `DFMA`, min/max and set/predicate comparisons. Single-precision operations include add, multiply, fused multiply-add, min/max, compare/set, multi-function/transcendental (`MUFU`), range reduction (`RRO`) and swizzled add.

UAM warns that native 64-bit divide and square root are approximate on this path. That is a target semantic constraint, not simply a throughput number.

## Integer and bit operations

The emitter contains logical operations, add/multiply/multiply-add, scaled add, `XMAD`, min/max, compare/set, shifts/funnel shifts, population count, bit-field insert/extract and find-leading-one operations. UAM's README calls out an `IMAD` encoding fix and warns about nonconstant integer divide/modulo lowering through floating point.

## Memory

The public emitter covers constant, local, shared, global and generic load/store families, attribute load/store/interpolation, atomics/reductions and cache control. UAM deliberately uses `LDG`/`STG` for SSBO access instead of the generic `LD`/`ST` route and removes software bounds checks for SSBO/image/atomic accesses.

This strongly argues for preserving address-space/resource classes in the shared shader IR. Flattening every load to “read memory” would throw away exactly the distinction the hardware backend needs.

## Texture and image work

`TEX`, `TEXS`, `TLD`, `TLD4`, `TXD`, `TXQ`, `TMML` and surface load/store/reduction families cover sampling, texel fetch/gather/query and image operations. UAM explicitly optimizes multisample image operations with `TXQ` and supports non-bindless image operations natively.

## Synchronization and collectives

`BAR`, `MEMBAR`, `DEPBAR`, `VOTE` and `SHFL` expose synchronization and lane/cohort operations. They should remain semantically distinguished from scalar arithmetic in any future compute-oriented Idriç shader IR.

## Scheduling

UAM adds Maxwell dual-issue scheduling support. This means instruction count alone is a poor objective. When comparing lowerings, retain UAM's raw bytecode and scheduling result; expression shapes that look equivalent in GLSL or TGSI can differ materially after dual-issue scheduling.

## Scope

The list in `SURFACE.txt` follows the emitter methods present in the exact public UAM GM107 backend. That is a reproducible compiler target surface. It should not be mislabeled as NVIDIA's complete official Maxwell ISA specification.

References:
- https://github.com/devkitPro/uam/blob/master/mesa-imported/codegen/nv50_ir_emit_gm107.cpp
- https://github.com/devkitPro/uam/blob/master/README.md