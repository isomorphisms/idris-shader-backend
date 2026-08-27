# RDNA 2 ISA families

AMD publishes a real RDNA 2 instruction-set reference (document 70648), so unlike the PowerVR path we can name the actual machine-level encoding families without pretending that Vulkan or SPIR-V is the hardware ISA.

The Steam Deck target has 8 RDNA 2 compute units. Treat the runtime Vulkan device properties as authoritative for supported features and limits; the ISA manual tells us how RDNA2 works, while the driver decides which Vulkan/SPIR-V features are exposed on the actual machine.

## Execution model

RDNA executes groups of lanes as waves and maintains separate scalar and vector state. The architecture exposes scalar general-purpose registers (SGPRs), vector general-purpose registers (VGPRs), predicate/execution-mask state, program counters, local/shared memory and global memory paths. RDNA supports wave32 and wave64 execution modes; occupancy is constrained by register, LDS and other per-wave/per-workgroup resources.

This makes “a boolean” or “a temporary float” an incomplete cost model. Uniform values may be profitable as scalar state, while lane-varying values consume vector resources. A future direct backend should preserve uniformity information far enough to exploit that distinction.

## Scalar instruction families

The public ISA uses scalar families conventionally named:

- `SOP1` — one-source scalar ALU;
- `SOP2` — two-source scalar ALU;
- `SOPC` — scalar compare;
- `SOPK` — scalar operations with immediates;
- `SOPP` — scalar control/program-flow operations;
- `SMEM` — scalar memory operations.

These cover scalar arithmetic/logic, shifts/bit manipulation, compares, branches, waits, barriers, register movement and scalar loads. Condition/execution state should be treated as architectural state worth studying, analogous to the single-bit state work on the CPU backends.

## Vector ALU families

Major vector encoding families include:

- `VOP1` — one-source vector ALU;
- `VOP2` — two-source vector ALU;
- `VOPC` — vector compares;
- `VOP3` — extended three-operand/vector forms;
- `VOP3P` — packed vector arithmetic, especially relevant to small floating/integer representations;
- `VINTRP` — interpolation operations.

The exact operations include floating and integer arithmetic, fused multiply/add forms, conversions, min/max, compare, transcendental/reciprocal-related operations, bit manipulation and packed arithmetic. Preserve fused/packed intent in the compiler IR instead of expanding it prematurely.

## Data-share / lane cooperation

`DS` operations address the local data share and include reads/writes, atomics and lane/data-sharing operations. DPP-style lane permutation/data-parallel primitives and cross-lane operations are important for reductions, stencils and other subgroup algorithms. These are a hardware counterpart to SPIR-V subgroup operations but are not one-to-one spellings.

## Buffer, image and flat/global memory

Major memory instruction families include:

- `MUBUF` — untyped buffer access;
- `MTBUF` — typed buffer access;
- `MIMG` — image/texture operations;
- `FLAT` — flat address-space access;
- `GLOBAL` — global-memory access;
- `SCRATCH` — private/scratch-memory access;
- `SMEM` — scalar-memory access.

The address-space/resource distinction is fundamental. It is a mistake to lower every Idriç resource access to an undifferentiated pointer load and hope the final driver reconstructs the intended memory class.

## Export and fixed pipeline boundary

`EXP` exports shader outputs toward later graphics-pipeline stages. Interpolation and export operations show why a fragment/vertex shader is not merely a compute kernel with a funny entry point: some operations directly participate in the graphics pipeline.

## Synchronization and waits

RDNA has explicit wait/barrier/control operations for outstanding memory and execution dependencies. Vulkan/SPIR-V barriers are higher-level semantics that the driver maps onto these mechanisms. A direct backend must derive waits from dependencies rather than reproducing driver-like conservative stalls everywhere.

## FP16 and packed work

The RDNA2 ISA includes packed arithmetic routes and half-precision support. This is directly relevant to the repository's `Float16` policy: a small-float source type can translate into genuinely different packed ALU/register/bandwidth choices on this architecture. It should not be treated as merely a GLSL precision adjective.

## First milestone versus long-term target

Initial path:

`shared shader IR → Vulkan GLSL → SPIR-V → AMD driver → RDNA2`

Long-term experimental path, only after we have exact disassembly/oracles:

`shared shader IR → RDNA2 machine code experiment`

The second path is valuable for studying architecture-specific optimization but should not become a prerequisite for rendering a first correct frame.

Reference: https://docs.amd.com/v/u/en-US/rdna2-shader-instruction-set-architecture