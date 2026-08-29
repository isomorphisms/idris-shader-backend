# NVIDIA PTX 9.3 machine model, forms, and non-opcode surface

The instruction names alone are not enough for a backend. PTX meaning also depends on execution hierarchy, state space, type, vector width, rounding, cache policy, memory order/scope, predication, and target architecture. This note records those axes so the Idriç backend does not accidentally treat PTX as a flat list of opcodes.

## Execution hierarchy

PTX exposes a data-parallel machine:

1. a kernel launch creates a grid;
2. a grid contains CTAs (CUDA thread blocks), optionally grouped into clusters on `sm_90+`;
3. a CTA contains threads;
4. threads execute in SIMT groups called warps;
5. `WARP_SZ` is the PTX constant for warp width and is 32 on all NVIDIA targets documented so far.

The important compiler distinction is **semantic scalar thread code versus physical SIMT execution**. A branch is defined per thread, but divergent lanes in a warp can serialize paths. Conversely, `.uni` on eligible control-flow operations is a promise that the branch/call/return is uniform. Do not mark `.uni` from hope; it must follow from the IR or a checked analysis.

## State spaces

- **`.reg`** — per-thread registers; ordinary ALU operands live here.
- **`.sreg`** — predefined read-only special registers.
- **`.const`** — grid-shared read-only constant memory.
- **`.global`** — context-wide global memory.
- **`.local`** — per-thread addressable local memory; spills and stack-like storage can land here.
- **`.param`** — kernel parameters or function parameters/return slots depending on context.
- **`.shared`** — CTA shared memory; on cluster-capable targets, active CTAs in a cluster can address peer shared memory through cluster mechanisms.
- **`.tex`** — legacy texture state space; texture/sampler operations have richer semantics than raw loads.

Generic addresses can refer into several named spaces. `cvta`, `isspacep`, `mapa`, and `getctarank` matter because address-space knowledge is a real optimization and correctness property, not decoration.

## Fundamental scalar and packed types

### Fundamental types

- predicate: `.pred`
- bit containers: `.b8`, `.b16`, `.b32`, `.b64`
- unsigned integers: `.u8`, `.u16`, `.u32`, `.u64`
- signed integers: `.s8`, `.s16`, `.s32`, `.s64`
- floating point: `.f16`, `.f16x2`, `.f32`, `.f64`

PTX does not silently perform arbitrary numeric conversions. `cvt` exists because source and destination representation should be explicit.

### Alternate and packed formats

PTX 9.3 also exposes formats used by conversion, matrix, and tensor instructions, including:

- `bf16` / `bf16x2`
- `tf32`
- `e4m3`, `e5m2`
- `e2m1`, `e2m3`, `e3m2`
- `ue8m0`, `ue4m3`
- `s2f6`
- packed integer types such as `u16x2`, `s16x2`, `u8x4`, `s8x4`

Several alternate formats are not general register types; they are instruction formats carried in appropriately sized bit registers. The backend must keep the distinction between a numeric value and a packed encoding.

## The form axes that change instruction meaning

Not every instruction accepts every modifier. The PTX specification's syntax and Target ISA Notes are the oracle for the legal cross-product. The backend nevertheless needs explicit representations for these recurring dimensions:

### Predicate guard

Most instructions may be prefixed by `@p` or `@!p`. This is lane-local conditional execution and is often the first alternative to a short divergent branch.

### Type and size

Suffixes such as `.u32`, `.s64`, `.f16`, `.f32`, `.b32`, packed types, and multiple source/destination type suffixes on conversions determine arithmetic interpretation and operand width.

### Vector width

Memory and some data operations use vector forms such as `.v2` and `.v4`. These are explicit grouped operands; they are not the same concept as a 32-lane warp.

### Rounding

Floating conversion/arithmetic forms can expose round-to-nearest-even, toward zero, toward negative infinity, toward positive infinity, or instruction-specific approximate modes. Exact Idriç arithmetic must not silently lower to an approximate form.

### Saturation, ReLU, finite/clamp behavior

Some arithmetic/conversion/matrix forms support saturation, ReLU-style clamping, or finite-range behavior. These change semantics and therefore need an IR-level reason, not just a performance preference.

### Flush-to-zero

`.ftz`-style forms change subnormal handling. Treat this as a semantic choice unless the source language has already declared relaxed floating behavior.

### Cache and eviction policy

Loads, stores, prefetches, and asynchronous copies can carry cache operators, eviction priorities/policies, and related hints. These should be selected from target measurements and reuse analysis; they are not part of the logical value being computed.

### Memory order and scope

Atomics, loads/stores in modern memory-model forms, and fences can distinguish relaxed/acquire/release/acq_rel/SC-like semantics and scopes such as CTA, cluster, GPU, and system. The memory-ordering relation is correctness-critical. Never infer a stronger synchronization guarantee from execution order alone.

### Proxy and alias ordering

PTX exposes proxy-fence mechanisms for cases where the same storage is accessed through distinct access mechanisms or aliases. These are easy to omit in a hand-written backend and can create rare correctness bugs.

### Address space

`.global`, `.shared`, `.local`, `.const`, `.param`, generic addressing, cluster-shared mappings, and special multimem/fabric address classes change both legality and cost.

### Uniformity

Eligible control-flow operations can carry `.uni` when every participating thread follows the same destination. Uniformity is especially valuable in the branch experiments because it separates “branch exists” from “warp diverges.”

### Architecture/family acceleration

Targets ending in `a` enable architecture-specific accelerated features and lose ordinary forward compatibility. Targets ending in `f` enable family-specific features that can remain compatible within a Blackwell family. The target profile must therefore be part of instruction selection.

## PTX directives

The PTX 9.3 surface includes the following module, linkage, variable, function, debugging, and launch directives:

- `.version` — PTX language/ISA version required by the module.
- `.target` — assumed GPU target and target-specific feature contract.
- `.address_size` — module address width.
- `.language` — source-language metadata added in PTX 9.3.
- `.entry`, `.func`, `.noreturn` — kernel/function declaration and return behavior.
- `.visible`, `.extern`, `.weak`, `.common`, `.alias` — linkage and symbol rules.
- `.reg`, `.sreg`, `.const`, `.global`, `.local`, `.param`, `.shared`, `.tex` — state-space declarations.
- `.align` — object alignment.
- `.section` — named section declaration.
- `.file`, `.loc` — source/debug mapping.
- `.pragma` — implementation/optimization directives; PTX 9.3 adds `mma_throughput` support.
- `.maxnreg` — static register limit.
- `.maxntid`, `.reqntid` — maximum/required CTA dimensions.
- `.minnctapersm`, `.maxnctapersm` — CTA residency constraints.
- `.reqnctapercluster`, `.maxclusterrank`, `.explicitcluster` — cluster launch constraints/requirements.
- `.branchtargets` — admissible indirect-branch targets.
- `.calltargets`, `.callprototype` — indirect-call target/prototype declarations.

These are compiler output, not source-language concepts. For example, `.maxnreg` is a resource/tuning decision; it should not leak into Idriç semantics.

## Special registers and predefined values

### Thread / warp / CTA / grid identity

- `%tid`, `%ntid`
- `%laneid`, `%warpid`, `%nwarpid`
- `%ctaid`, `%nctaid`
- `%smid`, `%nsmid`
- `%gridid`
- `WARP_SZ`

### Cluster identity and topology

- `%clusterid`, `%nclusterid`
- `%cluster_ctaid`, `%cluster_nctaid`
- `%cluster_ctarank`, `%cluster_nctarank`
- `%is_explicit_cluster`

Cluster-level execution is a Hopper-and-later feature (`sm_90+`).

### Lane masks

- `%lanemask_eq`
- `%lanemask_le`
- `%lanemask_lt`
- `%lanemask_ge`
- `%lanemask_gt`

These are useful for warp scans, leader election, and compacting work without shared memory.

### Timing and performance monitoring

- `%clock`, `%clock64`
- `%globaltimer`, `%globaltimer_lo`, `%globaltimer_hi`
- `%pm0` ... `%pm7`
- `%pm0_64` ... `%pm7_64`
- `%envreg0` ... `%envreg31`

Some of these are intended primarily for tools or have target-specific/undefined behavior. They are suitable for probes, not portable program logic unless the contract says otherwise.

### Shared-memory accounting

- `%total_smem_size`
- `%dynamic_smem_size`
- `%aggr_smem_size`
- `%reserved_smem_offset_begin`
- `%reserved_smem_offset_end`
- `%reserved_smem_offset_cap`
- `%reserved_smem_offset_0`, `%reserved_smem_offset_1`

The reserved region belongs to NVIDIA system software; user code must not treat it as spare shared memory.

### Device graph

- `%current_graph_exec` — identifier for the currently executing CUDA device graph, or zero when not executing as part of one.

## Target compatibility model

A plain target such as `sm_90` or `sm_100` follows PTX's forward-compatible model: PTX for an older baseline target can normally be translated to a later architecture that contains that baseline feature set.

An `a` target such as `sm_90a` or `sm_100a` opts into architecture-specific accelerated features. Code using those features is tied to that architecture target; Hopper `sm_90a` PTX is not a portable way to target Blackwell.

A Blackwell `f` target such as `sm_100f` opts into family-specific features intended to remain usable on later targets in the same Blackwell family.

This means the backend should have at least three notions, not one numeric “GPU version”:

1. baseline capability;
2. family-specific capability;
3. exact architecture-accelerated capability.

## Native SASS boundary

PTX is explicitly designed as an ISA for compilers and code distribution; NVIDIA's assembler/JIT translates it to native GPU instructions. We can inspect generated cubins with NVIDIA binary tools when the toolchain is available, and we can learn target-specific scheduling/encoding facts empirically, but the repository should not claim a complete native SASS contract that NVIDIA has not published.

For now the direct Idriç GPU backend target is therefore **typed Idriç IR -> PTX -> NVIDIA assembler/JIT -> cubin/SASS**, with measurements feeding back into PTX instruction selection. If we later build a native SASS emitter, it should begin from an independently verified encoding inventory rather than folklore.

## Source pin

This note follows NVIDIA PTX ISA 9.3 and CUDA 13.3-era target documentation as checked on 2026-08-29. Update the pin and re-audit the instruction map when PTX changes.
