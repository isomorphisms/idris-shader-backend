# NVIDIA PTX 9.3 backend research

This directory is the shared NVIDIA compiler-facing ISA reference for the H100, H200, B200, and GB200 target branches.

- `instruction-map.md` — all PTX 9.3 base instruction families, grouped by meaning with a compiler comment for each family.
- `machine-model-and-forms.md` — execution hierarchy, state spaces, types, predication, modifiers, memory ordering, directives, special registers, and target-compatibility rules.
- `modern-subfamilies.md` — explicit dotted Hopper/Blackwell operations: asynchronous copy, TMA, multimem, fabric, mbarrier, WGMMA, cluster launch control, TensorCore fifth generation, and related synchronization.

## Why PTX is the exhaustive boundary here

PTX is NVIDIA's published compiler-facing ISA. NVIDIA's toolchain lowers PTX to the native GPU ISA. The repository can therefore make a reproducible, version-pinned inventory of PTX syntax and semantics, but it must not claim that this is a complete native SASS encoding manual. A later native-emission experiment should begin by independently inventorying verified machine encodings from real binaries and hardware.

## Target branches

- H100 and H200: Hopper, compute capability 9.0; baseline `sm_90`, with exact architecture-accelerated features gated behind `sm_90a`.
- B200 and the Blackwell GPU portion of GB200: Blackwell, compute capability 10.0; baseline `sm_100`, with family-specific and architecture-specific variants gated by `sm_100f` / `sm_100a` as the PTX form requires.

The four SKU branches stay separate because memory capacity/bandwidth, host topology, interconnect, and benchmarking can differ even when two SKUs share the same GPU instruction architecture.

Source pin: NVIDIA PTX ISA 9.3 and CUDA 13.3-era target/tuning documentation, checked 2026-08-29.
