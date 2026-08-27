# WGSL memory and execution model

WGSL's parallel semantics should be treated as compiler semantics, not as incidental restrictions imposed by a browser.

## Invocations, workgroups, subgroups and quads

A draw or dispatch creates many shader invocations. Compute invocations are organized into workgroups whose size is declared with `@workgroup_size`; global/local/workgroup built-ins identify an invocation. Implementations further partition executing invocations into subgroups, and fragment processing has quad relationships used by derivatives and quad operations.

Subgroup width is target-dependent unless optional subgroup-size control is negotiated. Code that assumes “warp = 32” because one follower is Maxwell would break the common WGSL target.

## Address spaces

The current language distinguishes:

- `function`: private to one invocation and function lifetime;
- `private`: private to one invocation, module-scope lifetime;
- `workgroup`: shared among invocations in one compute workgroup;
- `uniform`: read-only host-bound data;
- `storage`: host-bound/storage data, with read or read-write modes;
- `immediate`: optional small immutable command-supplied data;
- `handle`: opaque texture/sampler resources.

Preserve these classes in the shader IR. They correspond to different hardware paths and synchronization/caching rules on the concrete followers.

## Memory model and barriers

WGSL maps into the WebGPU/SPIR-V memory model with explicit scopes. Atomics use relaxed semantics; workgroup/storage synchronization is supplied through the barrier operations and is constrained by uniform control-flow requirements. A barrier is therefore not simply a function with no return value: placement and participation are part of its correctness.

For simple independent-pixel or independent-buffer-index workloads, prefer algorithms requiring no inter-invocation synchronization. Add barriers/atomics only when the mathematical kernel actually requires communication.

## Uniformity

WGSL statically analyzes uniformity for operations that require coordinated invocations, notably derivatives, barriers and subgroup/quad work. Divergent control can make an otherwise syntactically valid call invalid or nonportable.

A shared shader IR should eventually record enough control-flow/uniformity information to reject bad lowerings before printing WGSL. This will also help the Maxwell/RDNA followers because the same distinction affects predicates, waves and occupancy there.

## Floating point

WGSL specifies `f32` and optional `f16`, but allows implementation latitude documented by its floating-point accuracy rules, reassociation/fusion rules and operation-specific accuracy requirements. Do not infer that a high-level expression has bit-identical behavior across PowerVR, Maxwell and RDNA2 merely because each accepts a 32-bit floating type.

For this project, generated shader acceptance should use mathematical/numerical tolerances where the language permits implementation variation, while exact integer/buffer oracles should remain exact.

## Host-shareable layout

Uniform/storage/immediate data crosses the CPU/GPU boundary without magical reformatting. WGSL defines alignment/size/layout constraints for host-shareable values. Resource metadata emitted by the compiler must therefore include a deterministic byte layout that the host side uses identically.

The newer `buffer_view` extension makes this especially explicit: opaque buffer storage can be reinterpreted at byte offsets as host-shareable types. This is powerful, but it increases the importance of alignment, bounds and provenance checks in generated code.

## Mapping to concrete followers

- PowerVR/GLES: many of these semantics are hidden behind GLSL ES and driver lowering, but precision/resource classes still matter.
- Switch/Maxwell: workgroups/subgroups eventually map onto Maxwell execution, predicates, shared/global memory, barriers and shuffle/vote operations.
- Steam/RDNA2: subgroup operations eventually map onto wave-level operations; uniform versus varying values can influence scalar versus vector hardware resources.

The common IR should preserve semantics; each follower chooses its hardware-specific implementation.

Reference: https://www.w3.org/TR/WGSL/ sections 14–15.