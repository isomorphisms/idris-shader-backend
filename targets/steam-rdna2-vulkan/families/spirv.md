# SPIR-V 1.6 instruction families

SPIR-V is a typed binary intermediate language, not the RDNA2 machine ISA. Vulkan consumes SPIR-V modules and the AMD driver lowers them to the actual GPU. For this branch, SPIR-V is the stable compiler/runtime boundary below GLSL.

## Module structure

A module declares capabilities, extensions, imported extended-instruction sets, a memory model, entry points and execution modes. Debug/name/source operations are semantically non-executable but important for inspectable compiler artifacts.

## Types and constants

SPIR-V explicitly declares scalar, vector, matrix, image/sampler, arrays, structures, pointers and function types. Constants and specialization constants are separate operations. This is useful for Idriç because type/precision intent does not need to disappear before driver lowering.

## SSA values, composites and functions

Most computational instructions produce SSA result IDs. Composite construct/extract/insert and vector shuffle operations make vector/aggregate manipulation explicit. Functions have typed parameters and calls; control flow is represented with labels, branches, merge instructions and `OpPhi`.

## Memory and address spaces

Variables and pointers carry storage classes. Loads/stores, access chains and pointer operations therefore preserve distinctions among uniform, storage, workgroup, private and other address spaces. Do not flatten this to one CPU-like memory class in the shared IR.

## Arithmetic, bit operations and comparisons

The core has explicit integer/floating arithmetic, conversions, bitfield operations, ordered/unordered floating comparisons and integer signed/unsigned comparisons. Higher mathematical functions such as `sin`, `cos`, `exp`, `log`, `sqrt`, `fma` and many common GLSL operations are normally represented through imported extended instruction sets such as `GLSL.std.450`, rather than pretending each is a core `Op*` instruction.

## Images

Sampling, fetching, gathering, reading/writing storage images and querying image properties are distinct operations, with sparse variants where capabilities allow them. Image operands encode LOD, gradients, offsets and related modifiers.

## Derivatives and fragment termination

Derivative operations have ordinary, fine and coarse variants. Fragment termination/helper behavior is explicit through operations such as kill/terminate/demote. These carry execution-model semantics and must not be treated like ordinary pure calls.

## Atomics and synchronization

Atomics identify scope and memory semantics. Barriers similarly encode execution/memory scopes and semantics. This is substantially more precise than a generic `barrier()` node and should inform a future Idriç parallel-memory IR.

## Subgroups

The core group-non-uniform family covers election, votes, broadcasts, ballots, shuffles, reductions/scans and quad exchanges. Vulkan 1.4 can additionally enable promoted SPIR-V subgroup-rotate functionality through its feature/capability route, but extension/promoted capability details are kept outside the minimum baseline until negotiated.

## OpenCL-flavored core operations

SPIR-V core historically includes device-enqueue and pipe operations intended for kernel/OpenCL environments. Their presence in the SPIR-V grammar does not mean Vulkan permits them. The Vulkan SPIR-V environment imposes additional validity rules. This is why the backend needs both a complete SPIR-V inventory and a Vulkan-environment checker.

## Completeness

`SURFACE.txt` gives the readable list. `tools/extract_registry_surface.py` filters the Khronos grammar to operations with a real core version at or below 1.6; extension-only operations (`version: None`) are not silently promoted into the baseline.

References:
- https://registry.khronos.org/SPIR-V/specs/unified1/SPIRV.html
- https://github.com/KhronosGroup/SPIRV-Headers/blob/main/include/spirv/unified1/spirv.core.grammar.json