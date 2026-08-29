# NVIDIA GB200 Grace Blackwell target profile

Branch: `target/nvidia-gb200-blackwell-sm100`

GPU architecture: NVIDIA Blackwell. Public CUDA compute capability of the Blackwell GPUs: **10.0**.

GB200 is not a separate GPU instruction architecture from B200. The GB200 Grace Blackwell Superchip combines a Grace CPU with **two Blackwell GPUs** over NVLink-C2C. Therefore individual GPU kernels use the same Blackwell PTX target family as B200; the reason for a separate branch is the host/GPU topology, coherent-memory/interconnect opportunities, multi-GPU scheduling, and product-specific measurements.

## GPU PTX target contract

### `sm_100`

Portable Blackwell baseline.

### `sm_100f`

Blackwell-family-specific forms where PTX explicitly permits family forward compatibility.

### `sm_100a`

Exact Blackwell architecture-accelerated forms where the PTX Target ISA Notes require the `a` target.

As with B200, emit the weakest target that legally represents the selected kernel. A simple delimiter scanner has no reason to become `sm_100a` merely because it runs on GB200.

## GPU instruction vocabulary

The per-GPU instruction selection is the same Blackwell family described by the B200 branch. Important Blackwell-specific families include:

### TensorCore fifth generation

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

These are Blackwell matrix/Tensor Memory operations, not general-purpose replacements for ordinary integer/SIMT code.

### Cluster Launch Control

- `clusterlaunchcontrol.try_cancel`
- `clusterlaunchcontrol.query_cancel`

These can support dynamic persistent scheduling when work units are irregular. Long-variable-length FASTA/FASTQ records are one workload where load imbalance is plausible enough to test, but the data must justify the extra scheduler machinery.

### PTX 9.3 fabric operations

- `fabric.try_get`
- `fabric.try_put`
- `fabric.try_red`
- `fabric.try_pullred`
- `fabric.submit`
- `fabric.wait`

GB200's system topology makes fabric/interconnect-aware experiments particularly interesting, but the compiler must still follow the PTX fabric-handle, completion, reporting, mbarrier, and proxy-ordering rules. “Remote data” is not automatically a legal fabric operation.

### Multimem and asynchronous transfer

The shared PTX inventory includes:

- `multimem.ld_reduce`
- `multimem.st`
- `multimem.red`
- `multimem.st.async`
- `multimem.red.async`
- `multimem.cp.async.bulk`
- `multimem.cp.reduce.async.bulk`
- `cp.async.bulk` / tensor/TMA forms
- `mbarrier.*` completion and phase operations.

These deserve more attention on GB200 than on a single-GPU target when a workload actually spans GPUs or uses multicast/fabric-visible storage.

## GB200 system topology as a compiler-planning input

The GB200 Grace Blackwell Superchip consists of:

- one Grace CPU;
- two Blackwell GPUs;
- NVLink-C2C connections between Grace and the GPUs.

Larger GB200 systems then connect many such components through NVLink/NVLink Switch fabrics. That creates optimization questions above individual PTX instruction selection:

1. Where should input records initially live?
2. Is preprocessing better on Grace or the GPUs?
3. Should a biological stream be partitioned by record, by file block, or by pipeline stage?
4. When should both GPUs process independent partitions versus cooperate on one large structure?
5. Can data remain resident across several Bioawk-style passes?
6. When do multimem/fabric operations beat explicit ordinary copies and local processing?

Those are architecture-search questions. They should not contaminate the semantic IR, but the semantic IR must preserve enough information about independence, shape, record boundaries, and reductions to let the planner answer them.

## Branching on the Blackwell GPU

For ordinary Bioawk work, start with the same PTX control/warp operations as B200:

### Direct choices

- `setp` + `bra`
- predication with `@p` / `@!p`
- `selp`
- `brx` for indexed multiway dispatch.

### Warp-wide choices

- `activemask`
- `vote.sync`
- `match.sync`
- `elect.sync`
- `shfl.sync`
- `redux.sync`
- `fns`

### Bit-oriented choices

- `lop3`
- `prmt`
- `bfe`, `bfi`, `bmsk`
- `bfind`, `clz`, `popc`
- `brev`
- `shf`

The central GPU question is usually not whether a source `if` exists. It is whether neighboring lanes take the same path, and whether a warp-wide mask/vote can turn many lane decisions into one coherent operation.

## Bioawk experiments that are specifically interesting on GB200

### Independent record partitioning across two GPUs

For ordinary FASTA/FASTQ files, record boundaries give a natural independent-work unit. Compare:

- split the input once and run independent kernels on both GPUs;
- streaming chunks with boundary repair;
- persistent queues for variable record lengths;
- a single GPU when transfer/coordination overhead dominates.

### Keep parsed records resident

If several biological operations are applied successively, GB200's large GPU memory and fast interconnect can make repeated CPU↔GPU round trips especially wasteful. Preserve a “records already resident and validated” plan so later kernels can consume it directly.

### Grace preprocessing versus GPU parsing

Do not assume every byte must be parsed on the GPU. Compare:

- Grace finds record boundaries, GPU performs expensive biological operations;
- GPU performs delimiter/record scan using warp masks;
- hybrid pipeline in which CPU and GPUs consume separate chunks.

The same exact correctness oracle should validate all three.

### Load imbalance

Variable-length records can make thread-per-record or block-per-record mappings uneven. Compare ordinary static partitioning against persistent queues, and only then test Blackwell Cluster Launch Control as a more sophisticated scheduling mechanism.

### Cross-GPU reductions

If the output is a compact global statistic rather than per-record results, compare local per-GPU reductions followed by a small merge against multimem/fabric reduction operations. The latter are interesting precisely because GB200 has a strong interconnect, but they still need to win on the measured data.

## B200 versus GB200 branch rule

GPU opcode legality should normally remain identical between these two branches for a given `sm_100`/`sm_100f`/`sm_100a` form. Differences belong in:

- topology descriptions;
- memory placement;
- launch/runtime plan;
- multi-GPU work scheduling;
- interconnect/fabric use;
- benchmark results.

If an instruction-selection difference appears between B200 and GB200, document the concrete system capability or measurement that caused it instead of assuming the product name implies a different ISA.

## Documentation inherited by this branch

- `docs/nvidia-ptx-9.3/instruction-map.md` — PTX 9.3 base instruction-family inventory with a compiler note for every family.
- `docs/nvidia-ptx-9.3/machine-model-and-forms.md` — execution hierarchy, state spaces, types, predication, memory ordering/proxies, directives, special registers, and target compatibility.
- `docs/nvidia-ptx-9.3/modern-subfamilies.md` — explicit Hopper/Blackwell async-copy, mbarrier, WGMMA, TensorCore-5, multimem, fabric, and cluster-launch operations.

PTX is the exhaustive public compiler-facing ISA boundary for this pass. A native SASS backend would require a separately verified machine-encoding inventory; this branch does not pretend that proprietary native encodings are documented merely because PTX is.
