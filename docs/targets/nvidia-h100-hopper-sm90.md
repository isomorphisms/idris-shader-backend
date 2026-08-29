# NVIDIA H100 / Hopper target profile

Branch: `target/nvidia-h100-hopper-sm90`

Hardware family: NVIDIA Hopper. Public CUDA compute capability: **9.0**.

This branch inherits the complete PTX 9.3 compiler-facing inventory from `research/nvidia-ptx-9.3-inventory`. The profile below is the H100 capability/tuning layer; it does not maintain a second copy of every PTX operation.

## PTX target modes

### Portable Hopper baseline: `sm_90`

Use `.target sm_90` when the selected operations belong to the ordinary compute-capability-9.0 feature set. PTX at a plain target participates in NVIDIA's forward-compatibility model.

### Hopper architecture-accelerated: `sm_90a`

Use `.target sm_90a` only when the kernel actually selects Hopper architecture-accelerated operations. Important examples in the pinned PTX inventory include:

- `wgmma.mma_async`
- `wgmma.mma_async.sp`
- `wgmma.fence`
- `wgmma.commit_group`
- `wgmma.wait_group`
- `setmaxnreg`

`sm_90a` is an exact architecture contract. PTX using these accelerated Hopper features is not a portable Blackwell target. The backend therefore needs an explicit `hopper_accelerated` capability rather than treating `90a` as “90 but faster.”

## Execution resources relevant to lowering

The Hopper tuning guide records for H100-class compute capability 9.0:

- 64 concurrent warps per SM maximum;
- 64K 32-bit registers per SM;
- 255 registers per thread maximum;
- 32 thread blocks per SM maximum;
- 228 KB shared memory per SM;
- up to 227 KB shared memory per thread block under the documented configuration limits.

Those are resource constraints for occupancy and tiling, not source-language constants. The backend should estimate/register them after instruction selection and let measured kernels decide whether a more aggressive tile or unroll factor helps.

## Hopper features the backend should model directly

### Thread-block clusters

Hopper adds cluster-level execution/topology. Cluster-capable kernels can coordinate several CTAs and access distributed shared-memory facilities.

Compiler implications:

- CTA-local and cluster-local synchronization are different capabilities.
- A cluster-shared address is not an ordinary CTA-shared pointer.
- `mapa`, `getctarank`, cluster special registers, and `barrier.cluster` belong behind an explicit cluster execution plan.

### Tensor Memory Accelerator (TMA)

Hopper TMA supports asynchronous multidimensional movement between global/shared memory and cluster-related shared-memory paths.

Relevant PTX families include:

- `cp.async.bulk`
- `cp.async.bulk.tensor`
- `cp.reduce.async.bulk`
- `cp.reduce.async.bulk.tensor`
- tensor-map descriptors and `tensormap.*`
- `mbarrier.*` completion tracking.

For Bioawk-like byte streams, TMA should not be assumed useful just because it exists. It becomes interesting when records can be staged in large/coherent blocks or a later biological kernel is genuinely multidimensional.

### Memory barriers and asynchronous pipelines

Hopper makes `mbarrier` and asynchronous copies central to producer/consumer pipelines. The backend should model:

1. copy issue;
2. expected transaction count;
3. barrier arrival/completion;
4. phase transition;
5. consumer wait;
6. buffer reuse.

Inserting a wait immediately after each async copy is correct but defeats most of the reason to use the machinery.

### Warpgroup matrix operations

`wgmma.*` operates at warpgroup scope and is asynchronous. Its descriptors, layouts, commit/wait groups, and fence requirements are part of correctness.

This should be selected only from a genuine matrix/tensor semantic operation. String parsing/motif matching should stay on ordinary integer/bit/warp facilities unless a measured reformulation proves otherwise.

### Dynamic register redistribution

`setmaxnreg` can adjust register allocation between cooperating warps/warpgroups on the accelerated Hopper target. This is useful for asymmetric pipelines (for example, a lightweight producer plus register-heavy consumer), but it should be a late resource optimization after a working kernel exists.

## Ordinary PTX operations most relevant to Bioawk

The likely first useful H100 backend work is not Tensor Cores. It is the ordinary scalar/SIMT instruction set:

### Predicate versus branch

Compare:

- `setp` + `bra`;
- `setp` + predicated instructions;
- `selp` for short value selection;
- `brx` for genuine multiway indexed dispatch.

A GPU branch is defined per thread, but a warp pays when participating lanes diverge. A branch whose condition is uniform across the warp is a very different event from a data-dependent per-byte branch.

### Warp-wide branch reduction

Use candidates such as:

- `vote.sync`
- `activemask`
- `match.sync`
- `elect.sync`
- `shfl.sync`
- `redux.sync`
- `fns`

These let a warp aggregate lane decisions and perform one elected/uniform action instead of sending every lane through independent control flow.

### Bit tricks

High-value PTX building blocks for old-school branch elimination include:

- `lop3`
- `prmt`
- `bfe`, `bfi`, `bmsk`
- `brev`
- `clz`, `popc`, `bfind`
- `shf`
- packed `dp2a` / `dp4a` where the arithmetic genuinely matches.

These are worth testing against naïve `if` trees for character classification, bitset matching, and compact lookup transforms.

### Memory layout

For biological records, the first question is often whether adjacent lanes read adjacent bytes. Coalesced global loads and simple register work are a much stronger baseline than irregular per-lane table accesses.

Keep variants for:

- record-per-thread;
- warp cooperatively scanning one long record;
- warp processing fixed-size blocks from several records;
- staged shared-memory block followed by repeated local passes.

The dataset should choose among these.

## H100-specific benchmark policy

Keep three target levels in benchmark names/results:

1. `sm_90` baseline PTX;
2. `sm_90a` only for kernels requiring Hopper accelerated operations;
3. compiler/JIT-produced native binary identity when hardware is available.

Do not compare an `sm_90a` WGMMA kernel with an `sm_90` scalar parser and conclude that one “architecture” is faster; record the semantic kernel and selected operation family.

## Documentation inherited by this branch

- `docs/nvidia-ptx-9.3/instruction-map.md` — all PTX 9.3 base instruction families with compiler comments.
- `docs/nvidia-ptx-9.3/machine-model-and-forms.md` — state spaces, types, masks/predication, directives, special registers, memory ordering, and target compatibility.
- `docs/nvidia-ptx-9.3/modern-subfamilies.md` — explicit async-copy, mbarrier, WGMMA, multimem, fabric, cluster-launch, and TensorCore-5 subfamilies.

The native SASS encoding below PTX is deliberately not called exhaustive because NVIDIA does not publish a complete stable Hopper SASS encoding specification. PTX is the reproducible compiler-facing boundary for this pass.
