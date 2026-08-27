# Apple GPU target atlas

This branch records the Apple graphics targets as a follower of the shader backend.

Do not confuse three different things:

1. the physical GPU architecture (PowerVR, Apple-designed GPU, Intel/AMD/NVIDIA on historical Macs);
2. the public shader/programming interface (Metal Shading Language and Metal API, historically OpenGL ES/OpenGL);
3. Metal GPU-family capability levels (Apple1..Apple10 and Mac families).

Apple does not publish a stable machine-opcode ISA for Apple-designed GPUs. Therefore `instructions.txt` in those hardware directories must say so rather than inventing opcodes. The public compiler target is MSL/Metal, and the public operation/capability inventory is under `metal/`.

For the holomorphic / meromorphic / metamorphic renderer, the especially interesting Apple4+ mechanisms are imageblocks, tile shaders, raster-order groups, quad/SIMD-group cooperation, threadgroup memory, barriers and later reductions/atomics/ray facilities. Keep a portable fallback; Apple specialization is optional.

Companion design issue: https://github.com/isomorphisms/idris-shader-backend/issues/25
