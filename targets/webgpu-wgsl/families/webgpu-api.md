# WebGPU host API families

WebGPU is the host/resource/command API around WGSL. The API does not expose a universal GPU instruction stream. It chooses an adapter/device, creates resources and pipelines, records commands, and lets the implementation lower the work to the native graphics stack.

## Adapter and device discovery

`GPU.requestAdapter` selects an adapter. `GPUAdapter` exposes supported features, limits and adapter information and creates a `GPUDevice`. The device exposes its enabled features/limits, primary queue and loss/error state.

Feature negotiation is part of shader correctness. A generated module that uses `f16`, subgroups, clip distances or subgroup-size control requires the corresponding feature to have been requested when creating the device.

## Resource creation

`GPUDevice` creates buffers, textures, samplers, external textures, bind-group layouts, pipeline layouts, bind groups, shader modules, pipelines, command encoders, render-bundle encoders and query sets. Those creation calls are the resource vocabulary from which a WebGPU program is assembled.

Buffers explicitly state usage bits and mapping state. Textures state dimensions, formats, usage, mip/sample counts and allowed view formats. Samplers state filtering, addressing, comparison and LOD behavior. These are host resource contracts, not data hidden in a shader string.

## Shader modules and pipelines

`createShaderModule` accepts WGSL. `getCompilationInfo` exposes diagnostics. Compute/render pipelines can be created synchronously or asynchronously. Pipeline layouts define bind-group interfaces and immediate-data size; pipelines expose `getBindGroupLayout` for their layouts.

The compiler receipt should retain the WGSL text and compilation diagnostics. The opaque native module produced below WebGPU is implementation-specific.

## Bind groups and immediates

Bind groups connect shader `@group/@binding` declarations to buffers, samplers, textures, storage textures and external textures. `setBindGroup` binds them during compute/render recording.

The current API also has `setImmediates`, paired with WGSL's `immediate` address space. This is small frequently updated data recorded directly into the command stream. It should not be conflated with a uniform-buffer binding in the shared shader interface.

## Command encoding

A command encoder starts compute/render passes, performs copies/clears/query resolves and finishes a command buffer. Compute passes bind a pipeline/resources and dispatch direct or indirect workgroups. Render passes additionally set viewport/scissor/blend/stencil state, bind vertex/index buffers, issue direct/indirect draws, execute render bundles and manage occlusion queries.

Render bundles pre-record reusable render commands but do not contain render-pass attachment setup. Debug groups/markers are available on encoders/passes/bundles and are worth generating around compiler-produced work when profiling.

## Queue and transfer

The queue submits finished command buffers and provides host-to-GPU writes for buffers/textures plus external-image copies. `onSubmittedWorkDone` is a host completion boundary, not a replacement for correctly expressing command/resource dependencies.

## Canvas

`GPUCanvasContext` is the browser presentation seam: configure/unconfigure, inspect configuration and acquire the current texture. This is deployment/presentation plumbing rather than shader semantics. A compute-only oracle needs no canvas.

## Queries

Query sets cover occlusion and, when the feature is enabled, timestamps. Query resolution copies results into buffers. Timing claims should always record the enabled feature set and actual implementation/device because WebGPU itself does not promise universal timestamp availability.

## Completeness

`SURFACE.txt` gives the readable API verbs/options. `tools/extract_webgpu_types.py` mechanically extracts all GPU interface method names, string-union option values and constant namespaces from the pinned `gpuweb/types` declaration file, so drift can be detected as the standard evolves.

References:
- https://gpuweb.github.io/gpuweb/
- https://github.com/gpuweb/types