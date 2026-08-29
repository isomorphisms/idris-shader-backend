# PTX 9.3 modern and architecture-sensitive instruction subfamilies

`instruction-map.md` inventories the compiler-facing PTX base instruction families. This file expands the dotted instruction families that are especially important for Hopper (`sm_90`) and Blackwell (`sm_100`) backend work. It is deliberately explicit about operations that would be hidden if we treated `cp`, `mbarrier`, `wgmma`, `tcgen05`, or `fabric` as one opcode.

The PTX 9.3 specification remains the legal-form oracle. Shape, type, layout, scope, order, cache, completion, and target modifiers can create many valid forms of one operation; the backend should model those fields rather than manufacture a separate semantic operation for every spelling.

## Asynchronous stores and reductions

- **`st.async`** — asynchronous store form; completion and visibility rules differ from an ordinary `st`.
- **`multimem.st.async`** — asynchronous store to multimem destinations; Blackwell-era operation with explicit completion semantics.
- **`st.bulk`** — bulk store operation; intended for larger transfer granularity rather than scalar register stores.
- **`red.async`** — asynchronous reduction; completion must be tracked rather than inferred from program order.
- **`multimem.red.async`** — asynchronous reduction over multimem locations.

Compiler rule: asynchronous issue and completion are two different events. Never lower a synchronous source operation to an asynchronous PTX operation unless the generated dependency/barrier structure preserves the source-visible order.

## Non-bulk asynchronous copy

- **`cp.async`** — copy global memory to shared memory asynchronously, avoiding the ordinary register-mediated load/store path where the target form permits it.
- **`cp.async.commit_group`** — close the current non-bulk async-copy group.
- **`cp.async.wait_group`** — wait until only the requested number of previously committed groups may remain outstanding.
- **`cp.async.wait_all`** — wait for all prior non-bulk async-copy groups.
- **`cp.async.mbarrier.arrive`** — connect completion of prior async-copy activity to an mbarrier arrival.

These operations are a pipeline vocabulary. A backend should reason about a logical copy stage, group lifetime, and consumer dependency instead of inserting waits immediately after every copy.

## Bulk asynchronous copy and reduction

- **`cp.async.bulk`** — asynchronous bulk copy between supported state spaces; Hopper TMA-related forms include global/shared and cluster-shared directions.
- **`cp.reduce.async.bulk`** — bulk asynchronous copy combined with reduction at the destination.
- **`cp.async.bulk.prefetch`** — bulk prefetch hint/path without the ordinary consumer-visible copy contract.
- **`multimem.cp.async.bulk`** — asynchronous bulk copy to multimem destinations.
- **`multimem.cp.reduce.async.bulk`** — asynchronous bulk copy plus reduction involving multimem destinations.
- **`cp.async.bulk.commit_group`** — commit a bulk async group for group-based completion forms.
- **`cp.async.bulk.wait_group`** — wait on committed bulk async groups.

The exact state-space direction, completion mechanism, multicast mask, cache hint, and byte-mask support are target-sensitive. For example, some forms exist at `sm_90` while additional qualifiers appear at `sm_100`.

## Tensor Memory Accelerator copy

- **`cp.async.bulk.tensor`** — tensor-shaped asynchronous copy driven by a tensor-map descriptor.
- **`cp.reduce.async.bulk.tensor`** — tensor-shaped asynchronous transfer combined with reduction.
- **`cp.async.bulk.prefetch.tensor`** — tensor-map-driven prefetch.

The tensor map is part of the operation's semantics: rank, dimensions, strides, element format, interleave/swizzle, out-of-bounds behavior, and destination layout cannot be reconstructed from a plain pointer after lowering.

## Tensor-map manipulation and ordering

- **`tensormap.replace`** — replace selected fields in a tensor-map descriptor under the PTX-defined constraints.
- **`tensormap.cp_fenceproxy`** — establish the required proxy ordering when a tensor map is copied/modified through one access mechanism and consumed by the tensor-map proxy.

Compiler rule: a descriptor should remain a typed object in the IR until all fields and required proxy fences are known.

## Multimem synchronous operations

- **`multimem.ld_reduce`** — load/reduce values represented by a multimem address.
- **`multimem.st`** — store through a multimem address.
- **`multimem.red`** — reduction through a multimem address.

These are not ordinary replicated scalar loads/stores. They refer to memory mappings with multicast/multimem semantics and therefore need their own address-space capability in a target plan.

## Fabric operations — PTX 9.3

- **`fabric.try_get`** — attempt a fabric read/get operation through a CFT handle.
- **`fabric.try_put`** — attempt a fabric write/put operation.
- **`fabric.try_red`** — attempt a fabric-side reduction operation.
- **`fabric.try_pullred`** — attempt a pull/reduction operation that returns reduced data from fabric-visible locations.
- **`fabric.submit`** — submit previously prepared fabric work into the fabric completion/reporting machinery.
- **`fabric.wait`** — wait/check completion according to the PTX fabric reporting contract.

Fabric operations have their own proxy and completion model. They are **not** interchangeable with `.global` loads/stores merely because the payload is memory data. PTX 9.3 documents these in the `sm_100+` generation; target gating is mandatory.

## Memory barriers (`mbarrier`)

- **`mbarrier.init`** — initialize a memory-resident barrier and its expected arrival count.
- **`mbarrier.inval`** — invalidate/release an mbarrier object when its lifecycle is complete.
- **`mbarrier.expect_tx`** — increase the barrier's expected asynchronous transaction count.
- **`mbarrier.complete_tx`** — report completion of asynchronous transaction bytes/count under the selected form.
- **`mbarrier.arrive`** — arrive at the current barrier phase, optionally manipulating expected transaction state where the form permits.
- **`mbarrier.arrive_drop`** — arrive and permanently reduce future arrival expectation for the participating entity.
- **`mbarrier.test_wait`** — test whether a phase has completed without the blocking/retry behavior of a full wait loop.
- **`mbarrier.try_wait`** — attempt to wait/test completion with the PTX-defined suspend/hint behavior.
- **`mbarrier.pending_count`** — query pending transaction/arrival state in supported forms.
- **`mbarrier.check_layout`** — PTX 9.3 layout-validation operation for mbarrier objects.
- **`cp.async.mbarrier.arrive`** — bridge async-copy completion into mbarrier state; listed here as well because it is part of barrier lifecycle reasoning.

The backend needs barrier-phase values as real dependencies. Reusing an mbarrier for its next phase before all required consumers have observed the previous phase is a correctness error, not just a performance mistake.

## CTA, warp, and cluster barriers

- **`bar.sync` / `barrier.sync`** — synchronize participating CTA threads at a named barrier.
- **`bar.arrive` / `barrier.arrive`** — nonblocking arrival forms where supported.
- **`bar.red` / `barrier.red`** — barrier plus predicate reduction.
- **`bar.warp.sync`** — warp-scope synchronization under an explicit member mask.
- **`barrier.cluster`** — cluster-level barrier operation for cluster-capable targets.

Cluster synchronization is meaningful only when the launch topology actually creates a thread-block cluster.

## Warp collectives

- **`shfl.sync`** — warp-register exchange under an explicit active/member mask.
- **`vote.sync`** — warp predicate vote/ballot under an explicit member mask.
- **`match.sync`** — identify lanes with matching register values.
- **`redux.sync`** — warp reduction into register result(s).
- **`elect.sync`** — elect one active participating lane.

These are natural alternatives to shared-memory scratch arrays for short collective operations. They are also useful in branch experiments because one lane can perform a uniform action after a warp vote/election.

## Indirect control flow

- **`brx.idx` and the `brx` indexed-branch family** — dispatch through a bounded branch-target table; pair with `.branchtargets` metadata where required.
- **indirect `call` forms** — call through a function value with `.callprototype`/`.calltargets` metadata as required by PTX.

For Bioawk-style multiway dispatch, compare these against balanced compare trees and predicated/select formulations. A source `switch` does not prescribe any one of them.

## Hopper asynchronous warpgroup matrix operations

- **`wgmma.mma_async`** — dense asynchronous warpgroup matrix multiply-accumulate.
- **`wgmma.mma_async.sp`** — sparse asynchronous warpgroup matrix multiply-accumulate.
- **`wgmma.fence`** — order register/shared-memory producers before asynchronous WGMMA consumption as required by the WGMMA proxy model.
- **`wgmma.commit_group`** — commit a WGMMA operation group.
- **`wgmma.wait_group`** — wait until the requested number of WGMMA groups remain pending.

WGMMA is an architecture-accelerated Hopper path associated with `sm_90a`, not a portable replacement for arbitrary arithmetic. Keep the semantic matrix operation above PTX so a Blackwell lowering can choose the later TensorCore family instead.

## Dynamic register allocation

- **`setmaxnreg.inc` / `setmaxnreg.dec` forms** — transfer register-allocation capacity between cooperating warps/warpgroups under target restrictions.

This is resource scheduling, not arithmetic. It only makes sense when a producer/consumer pipeline has intentionally asymmetric register demand.

## Cluster launch control — Blackwell

- **`clusterlaunchcontrol.try_cancel`** — attempt to cancel not-yet-started cluster work so a running cluster can claim/rebalance work under the Blackwell launch-control model.
- **`clusterlaunchcontrol.query_cancel`** — query the result of the cancel operation, including success and the cancelled CTA identity where defined.

These operations require a launch-control-aware algorithm. They should never appear merely because the target is `sm_100`.

## TensorCore fifth generation (`tcgen05`) — Blackwell

### Tensor-memory ownership

- **`tcgen05.alloc`** — allocate Tensor Memory for the participating CTA group.
- **`tcgen05.dealloc`** — release Tensor Memory allocation.
- **`tcgen05.relinquish_alloc_permit`** — relinquish the allocation permit/resource when the protocol requires it.

### Tensor Memory/register transfer

- **`tcgen05.ld`** — load from Tensor Memory to registers using an explicitly described data-movement shape/packing.
- **`tcgen05.st`** — store register data into Tensor Memory.
- **`tcgen05.wait`** — wait on relevant Tensor Memory transfer/visibility state; its subforms distinguish load/store-side dependencies.

### Tensor Memory movement

- **`tcgen05.cp`** — copy/rearrange tensor data between supported Tensor/Shared Memory representations, including optional decompression forms where specified.
- **`tcgen05.shift`** — shift/reposition tensor-memory data according to the TensorCore-5 data-movement model.

### Matrix multiply-accumulate

- **`tcgen05.mma`** — dense fifth-generation TensorCore MMA.
- **`tcgen05.mma.sp`** — sparse fifth-generation TensorCore MMA.
- **`tcgen05.mma.ws`** — warp-specialized dense TensorCore-5 MMA form.
- **`tcgen05.mma.ws.sp`** — warp-specialized sparse TensorCore-5 MMA form.

The `mma` forms carry substantial shape, kind, type, scaling, descriptor, CTA-group, swizzle, and layout state. That cross-product belongs in structured target data, not in a giant string-matching emitter.

### TensorCore-5 synchronization

- **`tcgen05.fence`** — specialized fence/order operations around TensorCore-5 memory/register dependencies.
- **`tcgen05.commit`** — commit asynchronous TensorCore-5 work to its completion mechanism.

`tcgen05` was introduced for Blackwell-family targets. PTX revisions distinguish architecture-specific (`sm_100a`) and family-specific (`sm_100f`) availability for variants; the exact variant's Target ISA Notes must be checked before emission.

## Other architecture-sensitive matrix movement

- **`ldmatrix`** — warp-cooperative shared-memory matrix load into registers; shape/type/transpose support is target dependent.
- **`stmatrix`** — warp-cooperative matrix store; newer Blackwell forms add shapes/types not available on earlier targets.
- **`movmatrix`** — matrix-fragment rearrangement in registers.
- **`mma.sync`** — synchronous warp-level MMA family.
- **`wmma.load` / `wmma.store` / `wmma.mma`** — higher-level warp matrix interface retained in PTX alongside lower-level MMA families.

These are legitimate compiler targets when the source operation is genuinely a matrix/tensor computation. They are not a reason to encode string comparison as a matrix multiply unless measurements support an equivalent reformulation.

## PTX 9.3 source-of-truth checklist

When implementing one of these families, copy the following from the pinned PTX section into structured backend data rather than memory or prose alone:

1. full syntax and legal modifier sets;
2. operand widths, register classes, tuple/vector shapes, and alignment;
3. state-space restrictions;
4. instruction introduction PTX version;
5. minimum target and any `a`/`f` target restriction;
6. memory order, scope, proxy, and completion semantics;
7. divergence/uniformity constraints;
8. undefined-behavior preconditions;
9. asynchronous dependency and lifetime rules;
10. examples used as assembler/disassembler acceptance fixtures.

That is the level at which “every move” becomes useful to a compiler: the inventory names every operation family, while the machine-readable backend tables should carry the legal forms and restrictions for each selected target.
