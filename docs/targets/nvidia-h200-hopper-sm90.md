# NVIDIA H200 / Hopper target profile

Branch: `target/nvidia-h200-hopper-sm90`

Hardware family: NVIDIA Hopper. Public CUDA compute capability: **9.0**.

H200 and H100 share the Hopper GPU instruction architecture. Therefore the **legal PTX instruction selection is the same capability family**: ordinary `sm_90`, and `sm_90a` only for Hopper architecture-accelerated operations. This branch exists separately because H200's memory subsystem and product-level performance characteristics can change the best tiling, batching, staging, and data-placement choices even when the generated instruction vocabulary is identical.

## PTX target contract

### `sm_90`

Use for the ordinary compute-capability-9.0 instruction set when forward-compatible PTX is desired.

### `sm_90a`

Use only when selecting architecture-accelerated Hopper operations such as:

- `wgmma.mma_async`
- `wgmma.mma_async.sp`
- `wgmma.fence`
- `wgmma.commit_group`
- `wgmma.wait_group`
- `setmaxnreg`

The `a` target is an exact architecture contract; do not expect an `sm_90a` PTX kernel to be a Blackwell-compatible representation.

## Same ISA does not imply same tuning

Keep H100 and H200 benchmark records separate even though both are CC 9.0. Product differences can change:

- how large a dataset remains resident on the GPU;
- how many records can be batched per transfer/launch;
- whether a kernel is bandwidth-bound or instruction-bound;
- the payoff from staging data in shared memory;
- overlap between transfers and computation;
- multi-GPU partition sizes.

These are target measurements, not new semantic instructions.

## Hopper execution model to preserve

### SIMT branching

A PTX `bra` is a per-thread semantic branch. Physical warp execution makes divergence the performance issue. Preserve enough information to distinguish:

- warp-uniform condition;
- lane-varying condition;
- short selection that can become predication/`selp`;
- genuine multiway dispatch suitable for `brx`;
- decisions that can be aggregated first with `vote.sync` or masks.

For Bioawk-style code, compare these rather than automatically converting every `if` to predication.

### Warp collectives

Candidate operations:

- `activemask`
- `vote.sync`
- `match.sync`
- `elect.sync`
- `shfl.sync`
- `redux.sync`
- `fns`

These let a warp share classification/search information without a full CTA-shared data structure.

### Bit operations

Particularly interesting for branch-free classifiers and motif bitsets:

- `lop3`
- `prmt`
- `bfe`, `bfi`, `bmsk`
- `clz`, `popc`, `bfind`
- `brev`
- `shf`

Treat them as candidate lowerings of known Boolean/bit semantics rather than exposing them as source-level accidents.

## Hopper memory/async machinery

The H200 branch should support the same Hopper families as H100:

- cluster execution and distributed shared-memory addressing;
- `mapa`, `getctarank`, cluster special registers;
- `barrier.cluster`;
- `cp.async`;
- `cp.async.bulk` and TMA tensor variants;
- `mbarrier.*` lifecycle/completion operations;
- tensor-map descriptors and proxy fences;
- multimem operations supported by the selected PTX form/target.

H200's larger/faster memory system is a reason to re-measure staging and batching, not a reason to invent H200-only PTX opcodes.

## Hopper matrix acceleration

`wgmma.*` is the accelerated Hopper warpgroup matrix family. It is asynchronous and requires the correct descriptor/layout/fence/commit/wait protocol.

For biological stream processing:

- do not use WGMMA for parsing or exact substring matching by default;
- do consider it for a downstream operation that is already a dense/sparse matrix computation or can be reformulated with an exact correctness oracle and measured benefit.

This keeps the compiler honest: target hardware can influence lowering without rewriting the problem merely to exercise exotic hardware.

## Bioawk/H200 first experiment set

Keep the same semantic kernels as CPU and H100 experiments so results are comparable:

1. delimiter scan;
2. fixed literal/motif search;
3. character-class classification;
4. quality-score threshold/trim loop;
5. one genuinely multiway AWK dispatch case.

For each, measure at least:

- naïve lane-local branches;
- predicated/select form;
- warp-vote/elected form where meaningful;
- bit-logic form;
- alternative work partition (record-per-thread versus cooperative warp/block scan).

Then separately vary batch size and memory staging on H200. That separates **instruction selection** from **product-level memory tuning**.

## Documentation inherited by this branch

- `docs/nvidia-ptx-9.3/instruction-map.md` — PTX 9.3 base instruction-family inventory with per-family comments.
- `docs/nvidia-ptx-9.3/machine-model-and-forms.md` — execution hierarchy, state spaces, types, predication, memory model, directives, special registers, target compatibility.
- `docs/nvidia-ptx-9.3/modern-subfamilies.md` — asynchronous copy, TMA, multimem, fabric, mbarrier, WGMMA, cluster launch control, and TensorCore fifth-generation suboperations.

PTX is the exhaustive public compiler-facing boundary for this pass. A complete native Hopper SASS encoding inventory would require independent reverse-engineering/verification and should not be fabricated from PTX names.
