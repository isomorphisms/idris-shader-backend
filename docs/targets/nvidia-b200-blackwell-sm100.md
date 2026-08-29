# NVIDIA B200 / Blackwell target profile

Branch: `target/nvidia-b200-blackwell-sm100`

Hardware family: NVIDIA Blackwell. Public CUDA compute capability: **10.0**.

This branch inherits the complete PTX 9.3 compiler-facing instruction inventory. Its job is to select the legal Blackwell forms and keep Blackwell-specific resource/topology decisions separate from Hopper.

## PTX target modes

Blackwell requires three distinct target ideas in the backend.

### Baseline `sm_100`

Use `.target sm_100` for the ordinary Blackwell compute-capability-10.0 baseline. Plain targets participate in PTX forward compatibility.

### Family-specific `sm_100f`

Use `.target sm_100f` when an instruction variant is documented as Blackwell-family-specific and may remain compatible with later architectures in the same family. This is stronger than the plain baseline but less restrictive than an exact `a` target.

### Architecture-accelerated `sm_100a`

Use `.target sm_100a` when the selected form is architecture-specific/accelerated and the PTX Target ISA Notes require it. Such PTX is tied to that architecture target rather than being generally forward-compatible.

The emitter should choose the weakest target that legally expresses the selected kernel. Do not stamp every B200 kernel `sm_100a` merely because B200 supports it.

## Blackwell-specific instruction families

### TensorCore fifth generation: `tcgen05.*`

Blackwell introduces the TensorCore fifth-generation programming family. The shared inventory expands these operations explicitly:

- `tcgen05.alloc`
- `tcgen05.dealloc`
- `tcgen05.relinquish_alloc_permit`
- `tcgen05.ld`
- `tcgen05.st`
- `tcgen05.wait`
- `tcgen05.cp`
- `tcgen05.shift`
- `tcgen05.mma`
- `tcgen05.mma.sp`
- `tcgen05.mma.ws`
- `tcgen05.mma.ws.sp`
- `tcgen05.fence`
- `tcgen05.commit`

These use Tensor Memory, descriptors, layout/swizzle information, CTA-group rules, and asynchronous completion semantics. PTX versions distinguish exact `sm_100a` and family-specific `sm_100f` availability for variants, so instruction selection must inspect the exact form's Target ISA Notes.

Compiler rule: keep matrix shape, operand kind, accumulator type, scaling, sparsity, CTA group, source location, layout, and descriptor state structured until emission. A concatenated opcode string is not a sufficient internal representation.

### Cluster Launch Control

Blackwell adds launch-control operations including:

- `clusterlaunchcontrol.try_cancel`
- `clusterlaunchcontrol.query_cancel`

They let a persistent/cluster-aware scheduler attempt to cancel future cluster work and reclaim it dynamically. This can be powerful for load imbalance, but it belongs to a scheduler transformation, not ordinary control-flow lowering.

### Fabric operations in PTX 9.3

The PTX 9.3 compiler-facing ISA adds:

- `fabric.try_get`
- `fabric.try_put`
- `fabric.try_red`
- `fabric.try_pullred`
- `fabric.submit`
- `fabric.wait`

These operations have fabric-handle, reporting/completion, mbarrier, and proxy-ordering semantics. They should be represented as a distinct address/transport capability, not treated as colorful spellings of `ld.global` and `st.global`.

### Expanded multimem/asynchronous operations

Blackwell-era PTX includes or extends operations such as:

- `multimem.st.async`
- `multimem.red.async`
- `multimem.ld_reduce`
- `multimem.st`
- `multimem.red`
- `multimem.cp.async.bulk`
- `multimem.cp.reduce.async.bulk`

Some forms or qualifiers begin earlier at `sm_90`; others require `sm_100`. The exact Target ISA Notes, not the family name, decide legality.

### Dynamic register allocation

`setmaxnreg` has Blackwell-supported architecture/family variants. As on Hopper, use it only for a deliberate pipeline in which cooperating warps have different register demand.

## Blackwell asynchronous-memory model

The backend should preserve distinct operations for:

1. ordinary load/store;
2. asynchronous copy;
3. TMA/tensor-map copy;
4. asynchronous store/reduction;
5. multimem operations;
6. fabric operations;
7. Tensor Memory operations.

All seven move or modify data, but they have different visibility, proxy, completion, scope, and address-space rules. Collapsing them into “memory operation” before target lowering would throw away exactly the information needed to use Blackwell well.

## Branching and SIMT experiments

For the Bioawk experiment, the most interesting Blackwell instructions are still mostly ordinary PTX rather than `tcgen05`.

### Lane-local branch forms

- `setp` + `bra`
- predicated instruction execution (`@p` / `@!p`)
- `selp`
- indexed `brx` for genuine multiway dispatch.

### Warp-level aggregation

- `activemask`
- `vote.sync`
- `match.sync`
- `elect.sync`
- `shfl.sync`
- `redux.sync`
- `fns`

A good parser/matcher lowering may let each lane test bytes but turn the outcome into one warp-level mask or elected action, reducing divergent control flow.

### Bit manipulation

- `lop3`
- `prmt`
- `bfe`, `bfi`, `bmsk`
- `bfind`, `clz`, `popc`
- `brev`
- `shf`

These are the likely Blackwell equivalents of the old-school bit/branch tricks we are testing on x86. They should be benchmarked before introducing TensorCore machinery into byte-oriented code.

## H100/H200 versus B200 compiler distinction

Do not carry Hopper's final instruction choices forward blindly.

- `sm_90a` accelerated PTX is not a Blackwell target contract.
- Hopper WGMMA is an accelerated Hopper family; Blackwell's native accelerated matrix path is the later TensorCore-5/Tensor Memory model.
- Plain semantic operations above that split — compare, mask, copy, reduction, matrix multiply, delimiter scan — should be shared.
- The final PTX operation family, shape, scheduling, and memory movement should be reconsidered for Blackwell.

This is exactly why the target branches share semantic/compiler machinery but keep final lowering separate.

## Bioawk candidates on B200

### Delimiter scanning

Compare work mappings:

- one thread per record;
- one warp cooperatively scans a long record;
- one CTA stages blocks and scans them repeatedly;
- persistent CTA/cluster scheduling when record lengths are highly irregular.

The first optimization target is coalesced byte traffic plus low-divergence classification, not matrix hardware.

### Literal motif search

Candidates include:

- first-byte/last-byte filters;
- warp ballot/vote over candidate positions;
- bitset/Shift-Or state using integer/Boolean PTX;
- skip-based algorithms where per-record control flow remains coherent enough;
- persistent scheduling/cluster launch control only if record-length imbalance becomes the measured bottleneck.

### Quality trimming

Threshold comparisons are simple. The harder question is finding the first/last relevant lane across blocks and handling variable record length without excessive divergence. Warp masks and elected lanes are natural first candidates.

### Multiway AWK decisions

Compare direct conditional chains, balanced trees, branchless select/predicate forms, and `brx`. If different lanes select different cases, a theoretically fewer-branch representation may still be slower because paths diverge.

## Resource/tuning policy

Blackwell tuning must remain empirical. Record per kernel:

- registers/thread;
- shared memory/CTA and cluster;
- CTA/cluster dimensions;
- achieved occupancy;
- bytes moved from/to global memory;
- instruction/branch counts where observable;
- divergence metrics where observable;
- async pipeline depth;
- Tensor Memory usage for `tcgen05` kernels;
- actual target (`sm_100`, `sm_100f`, or `sm_100a`).

A target branch should make the reason for an accelerated/family-specific instruction auditable.

## Documentation inherited by this branch

- `docs/nvidia-ptx-9.3/instruction-map.md` — complete PTX 9.3 base instruction-family map with compiler commentary.
- `docs/nvidia-ptx-9.3/machine-model-and-forms.md` — types, state spaces, predication, directives, special registers, memory scopes/orders/proxies, and target compatibility.
- `docs/nvidia-ptx-9.3/modern-subfamilies.md` — explicit Hopper/Blackwell dotted operations including async copy, mbarrier, WGMMA, `tcgen05`, multimem, fabric, and cluster launch control.

PTX is the exhaustive public compiler-facing ISA boundary for this pass. Native Blackwell SASS is intentionally not claimed complete because NVIDIA does not publish a complete stable SASS encoding specification.
