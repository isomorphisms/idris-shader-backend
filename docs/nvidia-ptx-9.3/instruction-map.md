# NVIDIA PTX 9.3 instruction map

This is the complete **reserved PTX instruction-keyword inventory** from NVIDIA PTX ISA 9.3, grouped by compiler-relevant meaning and annotated for backend work.

## Scope and honesty boundary

PTX is NVIDIA's public, compiler-facing virtual ISA. PTX is translated by NVIDIA's toolchain/driver to the GPU's native hardware instruction set. This document therefore inventories every documented PTX instruction keyword, not every proprietary SASS encoding. NVIDIA does not publish a complete stable SASS ISA/encoding manual for Hopper or Blackwell, so an alleged exhaustive native H100/B200 instruction manual would be invented.

A keyword can name a large family. In particular `cp`, `multimem`, `mbarrier`, `tensormap`, `tcgen05`, `wgmma`, and related families have important dotted suboperations and modifiers. The PTX 9.3 specification remains the row-level oracle for legal forms, operand types, modifiers, minimum targets, and memory semantics. The comments here are a compiler map: what the operation means and why we might care.

For Idriç lowering, never select an instruction merely because it exists. Preserve the typed/semantic operation first, then choose the PTX form using target capability, divergence, memory-space knowledge, alignment, precision requirements, and measured cost.

## Scalar arithmetic and bit manipulation

- **`abs`** — Absolute value; integer and floating forms differ in overflow/NaN details, so preserve the source type.
- **`add`** — Add scalars or supported packed types; this is the ordinary arithmetic add, not a synchronization primitive.
- **`addc`** — Add with carry-in from PTX condition-code state; mainly useful for multiword integer arithmetic.
- **`sub`** — Subtract two values; ordinary typed arithmetic.
- **`subc`** — Subtract with borrow/carry state; pair with extended-precision sequences.
- **`mul`** — Multiply; integer forms select low/high/wide results while floating forms follow their own rounding rules.
- **`mul24`** — Legacy 24-bit integer multiply; keep for completeness but do not prefer it without evidence.
- **`mad`** — Multiply then add; integer and floating variants have materially different exactness and historical behavior.
- **`mad24`** — Legacy 24-bit multiply-add; compatibility operation rather than a default lowering target.
- **`madc`** — Multiply-add with carry state for straight-line multiword integer arithmetic.
- **`clmad`** — Carryless 64-bit multiply-add; useful for polynomial/GF(2)-style arithmetic and introduced in PTX 9.3.
- **`div`** — Division; floating variants expose approximate versus correctly rounded choices.
- **`rem`** — Integer remainder; signedness matters.
- **`min`** — Minimum; type and floating NaN rules matter.
- **`max`** — Maximum; type and floating NaN rules matter.
- **`neg`** — Arithmetic negation; preserve signed/floating semantics.
- **`sad`** — Sum of absolute difference with an accumulator; useful for distance/image-style kernels.
- **`and`** — Bitwise or predicate AND depending on type.
- **`or`** — Bitwise or predicate OR depending on type.
- **`xor`** — Bitwise or predicate XOR depending on type.
- **`not`** — Bitwise or predicate complement.
- **`cnot`** — Integer logical-not producing zero/nonzero style results; distinct from predicate `not`.
- **`lop3`** — Three-input Boolean lookup-table operation; a strong candidate for collapsing short bit-logic trees.
- **`bfe`** — Extract a bit field from a word.
- **`bfi`** — Insert a bit field into a word.
- **`bfind`** — Find the position of a significant set bit according to the signed/unsigned form.
- **`bmsk`** — Construct a contiguous bit mask from position and width.
- **`brev`** — Reverse bit order.
- **`clz`** — Count leading zeros.
- **`popc`** — Population count.
- **`prmt`** — Byte permutation; powerful for packing, table-free rearrangement, and small data shuffles.
- **`shl`** — Logical left shift.
- **`shr`** — Right shift; arithmetic versus logical behavior follows the instruction type.
- **`shf`** — Funnel shift across two source words; useful for wide shifts and bitstream work.
- **`szext`** — Sign/zero extension operation for supported packed/narrow formats.

## Floating point, conversion, comparison, selection

- **`copysign`** — Combine one floating magnitude with another floating sign.
- **`fma`** — Fused multiply-add with one final rounding; do not replace with separate multiply/add when exact semantics matter.
- **`rcp`** — Reciprocal; approximate variants trade precision for speed.
- **`sqrt`** — Square root; exact/approximate and rounding forms differ by type.
- **`rsqrt`** — Reciprocal square root; primarily an approximate math primitive.
- **`sin`** — Approximate sine primitive; accuracy contract is weaker than a general math library.
- **`cos`** — Approximate cosine primitive; accuracy contract is weaker than a general math library.
- **`lg2`** — Base-2 logarithm approximation.
- **`ex2`** — Base-2 exponential approximation.
- **`tanh`** — Hyperbolic tangent primitive on supported targets/types.
- **`testp`** — Classify floating values, such as finite/NaN/subnormal classes, into a predicate.
- **`cvt`** — Numeric conversion with explicit source/destination types, rounding, saturation, and related modifiers.
- **`cvta`** — Convert addresses between generic and named PTX state spaces.
- **`set`** — Compare values and materialize the Boolean result as a numeric value.
- **`setp`** — Compare values and write predicate result(s); this is the normal producer for predicated execution.
- **`selp`** — Select one of two values by predicate; often preferable to a branch for tiny lane-local decisions.
- **`slct`** — Select by sign/comparison of a third scalar; older arithmetic selection primitive.
- **`mov`** — Move/register-copy or materialize certain addresses/symbol values; semantically broader than a physical MOV.

## Packed integer, dot-product, and legacy vector operations

- **`dp2a`** — Packed two-way integer dot-product accumulate.
- **`dp4a`** — Packed four-way byte dot-product accumulate; useful for compact integer scoring.
- **`vabsdiff`** — Legacy scalar-width video absolute-difference family.
- **`vabsdiff2`** — Two-lane packed absolute-difference family.
- **`vabsdiff4`** — Four-lane packed absolute-difference family.
- **`vadd`** — Legacy video integer add with selectable saturation/secondary operation forms.
- **`vadd2`** — Two-lane packed video add.
- **`vadd4`** — Four-lane packed video add.
- **`vavrg2`** — Two-lane packed rounded average.
- **`vavrg4`** — Four-lane packed rounded average.
- **`vmad`** — Legacy packed/video multiply-add family.
- **`vmax`** — Legacy video maximum.
- **`vmax2`** — Two-lane packed maximum.
- **`vmax4`** — Four-lane packed maximum.
- **`vmin`** — Legacy video minimum.
- **`vmin2`** — Two-lane packed minimum.
- **`vmin4`** — Four-lane packed minimum.
- **`vset`** — Legacy video comparison producing packed results.
- **`vset2`** — Two-lane packed comparison.
- **`vset4`** — Four-lane packed comparison.
- **`vshl`** — Variable packed/video left shift.
- **`vshr`** — Variable packed/video right shift.
- **`vsub`** — Legacy video subtract.
- **`vsub2`** — Two-lane packed subtract.
- **`vsub4`** — Four-lane packed subtract.

## Memory, addressing, data movement, and cache control

- **`ld`** — Load from a named or generic state space; cache, ordering, scope, vector width, and eviction modifiers can change behavior.
- **`ldu`** — Load through an address the compiler promises is uniform enough for the special uniform-load path.
- **`st`** — Store to a named or generic state space; ordering/scope/cache qualifiers must match the memory model.
- **`isspacep`** — Test whether a generic address belongs to a particular PTX state space.
- **`istypep`** — Test whether an operand/reference satisfies a PTX type or handle classification.
- **`prefetch`** — Request cache prefetch for an address; a performance hint, not a correctness operation.
- **`prefetchu`** — Uniform prefetch hint.
- **`alloca`** — Dynamically allocate per-thread stack/local storage.
- **`stacksave`** — Save the current dynamic stack position.
- **`stackrestore`** — Restore a previously saved dynamic stack position.
- **`createpolicy`** — Build a cache-policy object/value used by memory operations.
- **`cp`** — Prefix for asynchronous copy families, including `cp.async` and bulk/TMA-oriented copies; treat the subopcode as the real operation.
- **`multimem`** — Prefix for operations on multicast/multimem addresses; includes loads, reductions, stores, and asynchronous copies on supporting targets.
- **`tensormap`** — Tensor-map manipulation/query family for TMA descriptors; many forms are architecture/family gated.
- **`mapa`** — Map a shared-memory address to the corresponding address in another CTA of the same cluster.
- **`getctarank`** — Return the rank of the CTA owning a cluster-shared address.

## Atomics, barriers, memory ordering, and scheduling

- **`atom`** — Atomic read-modify-write returning the prior/result value as specified; memory order and scope are part of semantics.
- **`red`** — Atomic reduction without returning the old value; not interchangeable with `atom` in acquire-pattern reasoning.
- **`redux`** — Warp-level reduction of register values; avoids shared-memory round trips for supported operations.
- **`membar`** — Legacy memory barrier/fence form; prefer reasoning in the newer scoped memory model when possible.
- **`fence`** — Memory-ordering fence with explicit semantics/scope/proxy forms; correctness-critical.
- **`bar`** — CTA barrier family, including synchronization and reductions on older-style barrier resources.
- **`barrier`** — Named barrier family with arrive/wait/reduction forms.
- **`mbarrier`** — Memory-resident barrier family used heavily by asynchronous/TMA pipelines and cluster coordination.
- **`nanosleep`** — Hint that a thread should sleep for a bounded interval; useful in polling/backoff, not precise timing.
- **`applypriority`** — Apply scheduler priority hint/state where supported; optimization hint rather than semantic ordering.

## Warp and collective operations

- **`activemask`** — Return the currently active lane mask for the executing warp.
- **`shfl`** — Warp shuffle: move register values directly between lanes under a mask/topology.
- **`vote`** — Warp vote over predicates, including all/any/ballot-style forms.
- **`match`** — Warp-wide match/group lanes holding equal values.
- **`elect`** — Choose one active lane and report the elected lane via predicate.
- **`fns`** — Find an active lane by mask/rank-style search; useful for compact warp work queues.

## Control flow, calls, termination, and launch control

- **`bra`** — Direct branch; predicates make it conditional and `.uni` can assert uniform control flow.
- **`brx`** — Indexed/indirect branch family; the closest PTX analogue to a jump table.
- **`call`** — Direct or indirect function call under PTX calling conventions.
- **`ret`** — Return from a device function.
- **`exit`** — Terminate the current thread's kernel execution normally.
- **`trap`** — Abort/trap execution for a fatal condition.
- **`brkpt`** — Debugger breakpoint instruction.
- **`discard`** — Terminate/discard the current execution in environments where discard semantics are supported.
- **`griddepcontrol`** — Control dependency ordering between CUDA graph/grid launches.
- **`clusterlaunchcontrol`** — Cluster-launch-control family for dynamically cancelling/querying cluster work on supporting Blackwell targets.
- **`setmaxnreg`** — Dynamically adjust register allocation between cooperating warps/warpgroups; architecture-accelerated and highly target specific.

## Matrix and tensor operations

- **`mma`** — Warp-level matrix multiply-accumulate instruction family.
- **`wmma`** — Higher-level warp matrix load/mma/store family retained for compatibility and portable matrix lowering.
- **`wgmma`** — Asynchronous warpgroup matrix multiply-accumulate; central Hopper architecture-accelerated tensor primitive.
- **`ldmatrix`** — Warp-cooperative matrix-tile load from shared memory into registers.
- **`stmatrix`** — Warp-cooperative matrix-tile store from registers to shared memory.
- **`movmatrix`** — Matrix-fragment register rearrangement/move operation.
- **`tcgen05`** — Blackwell fifth-generation Tensor Core instruction family; treat each `tcgen05.*` suboperation and its descriptor/layout contract explicitly.

## Texture and surface operations

- **`tex`** — Texture sampling/fetch operation with sampler/texture semantics rather than raw memory semantics.
- **`tld4`** — Texture gather: fetch the same component from a small footprint of neighboring texels.
- **`txq`** — Query texture metadata/properties.
- **`suld`** — Surface load.
- **`sust`** — Surface store.
- **`sured`** — Surface atomic/reduction operation.
- **`suq`** — Query surface metadata/properties.

## Performance and instrumentation

- **`pmevent`** — Emit a performance-monitor event visible to profiling hardware/tools.

## Backend implications for the bioawk/branching experiments

Several PTX families map directly onto the branch and data-layout experiments we have been discussing:

- `setp` + predicated instructions and `selp` let us compare true control-flow against short branchless/predicated formulations.
- `bra` versus `brx` gives a clean direct-branch versus indexed/jump-table bakeoff.
- `activemask`, `vote`, `match`, `elect`, `shfl`, `fns`, and `redux` expose warp-wide information without first materializing a shared-memory data structure.
- `lop3`, `prmt`, `bfe`, `bfi`, `bmsk`, `popc`, `clz`, `shf`, and packed dot-product operations are exactly the sort of old, already-solved bit tricks that can replace naïve branch trees or byte-at-a-time work when the semantics match.
- `cp.async`/bulk/TMA, `mbarrier`, cluster shared-memory operations, and `multimem` matter when the limiting cost is getting biological records to the arithmetic rather than the arithmetic itself.
- Matrix/tensor instructions should not be forced onto string work. They belong only where the biological computation can honestly be reformulated as dense dot/matrix work and beats the scalar/bit-oriented alternatives.

## Sources pinned for this inventory

- NVIDIA PTX ISA 9.3, current documentation as checked on 2026-08-29.
- NVIDIA CUDA GPU Compute Capability table.
- NVIDIA Hopper Tuning Guide 13.3.
- NVIDIA Blackwell Tuning Guide 13.3.
- NVIDIA CUDA Compiler Driver documentation for `sm_90`, `sm_90a`, `sm_100`, `sm_100f`, and `sm_100a` target compatibility.

The reserved-keyword list contains 136 unique PTX instruction keywords. A future generator should verify that count against the upstream PTX specification whenever the pinned PTX version changes.
