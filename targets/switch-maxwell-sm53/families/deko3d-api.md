# deko3d API families

`deko3d.h` is the public GPU command/resource contract for the homebrew Switch path. Unlike OpenGL's large implicit state machine, deko3d makes command buffers, queues, memory, descriptors and synchronization relatively explicit. `SURFACE.txt` lists the public verbs by name.

## Device and memory

A device owns GPU-facing resources and establishes coordinate conventions. Memory blocks have explicit CPU/GPU access flags, alignment constraints, code/image usage and CPU-cache flushing. The API exposes both CPU and GPU addresses. Shader code, command memory, descriptors, uniform buffers and images each have target-specific alignment/size rules; these belong in target lowering and runtime setup rather than the common shader mathematics.

## Command buffers and queues

Commands are recorded into command buffers, finished into command lists, and submitted to queues. Lists can be captured, replayed and called from other command buffers. Queues can be graphics-capable, compute-capable or both, with priority and Z-cull options.

This is a useful boundary for Idriç because shader generation and command scheduling can remain separate. A shader backend should produce a module plus resource-interface metadata; host code decides when and where to bind and dispatch it.

## Synchronization

Fences and GPU-visible variables cover host/GPU and command-stream synchronization. deko3d exposes barrier strengths from no ordering through tile, fragment, primitive/compute completion and a full barrier. Cache invalidation is separately selectable for images, shaders, descriptors, Z-cull and L2.

These are not interchangeable “flush” operations. A generated host layer should eventually represent the resource dependency being ordered and choose the weakest correct barrier rather than scattering `Full` everywhere.

## Shader resources

Shaders bind by stage mask. Uniform buffers, storage buffers, textures and images have stage-local numbered slots. Image and sampler descriptors live in descriptor sets; combined texture handles are made from image and sampler IDs. Push constants and direct push-data commands provide smaller update paths.

## Fixed and dynamic graphics state

Rasterization, multisampling, blending, color writes, depth/stencil, vertex attributes and vertex-buffer layout are explicit state objects. Viewports, scissors, depth bias, line/point state, sample masks, stencil reference/masks, tessellation levels and tile/cache controls are command-buffer state changes.

The distinction matters for a compiler: a mathematical fragment function should not know whether culling is clockwise, whether alpha blending is enabled, or what the framebuffer format is unless those facts genuinely alter shader semantics.

## Draw and compute

The command surface includes direct and indirect nonindexed/indexed draws plus direct and indirect compute dispatch. The shader stages are vertex, tessellation control/evaluation, geometry, fragment and compute. This makes compute a real first-class Switch target rather than an accidental extension of a fragment-shader renderer.

## Images and transfers

Images support 1D/2D/3D, arrays, multisample, rectangle, cubemap and buffer forms. The public format set includes integer, normalized, floating, depth/stencil, BC, ASTC and ETC2 families. Layouts may be NVIDIA block-linear or pitch-linear. Copy, blit, resolve, buffer↔image transfer, clear, discard and depth-resolve commands are all explicit.

## Counters and observability

The API exposes timestamps and pipeline counters for samples, primitives, vertices and shader invocations. These are valuable backend receipts: when comparing two GLSL/UAM lowerings, retain the raw shader output and, where reproducible, invocation/counter/timing evidence rather than judging from source text alone.

Reference: https://github.com/devkitPro/deko3d/blob/master/include/deko3d.h