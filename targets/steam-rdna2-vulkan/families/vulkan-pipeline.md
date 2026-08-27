# Vulkan shader/pipeline API families

Vulkan is the host-side contract that receives SPIR-V, describes resources and pipelines, records work into command buffers and submits it. It is not the RDNA2 instruction set.

## Instance, physical device and logical device

Instance/device queries establish which physical device exists and which features, limits, formats, memory types and queue families it exposes. The backend must never infer shader features merely from the marketing name “RDNA2”; capability queries are the executable contract.

## Shader modules and pipelines

SPIR-V enters through shader modules. Compute and graphics pipelines combine shader stages with pipeline layout and, for graphics, rasterization/multisample/depth-stencil/color state. Pipeline caches are compilation artifacts. The initial backend should preserve the generated SPIR-V as its compiler receipt even if pipeline caches or driver binaries are also captured.

## Descriptors and push constants

Descriptor set layouts, pools, sets and updates bind buffers, sampled images, storage images and samplers. Pipeline layouts define descriptor-set and push-constant interfaces. Vulkan 1.4 also promotes push-descriptor and newer bind/push command forms. The common shader IR should emit resource-interface metadata from which these layouts can be derived.

## Buffers, images and memory

Memory allocation/binding is separate from creating buffers/images. Memory requirements, mappings, flush/invalidate operations and device addresses are explicit. Images have separate views and layouts. Vulkan 1.4 also has host image-copy/layout-transition operations. These resource transitions belong in the host/runtime layer, not in scalar shader expressions.

## Command buffers

Rendering and compute work is recorded through command buffers. Pipeline/resource binding, dynamic state, draw, indexed draw, indirect draw, compute dispatch, copies, clears, queries and barriers are all explicit commands. Vulkan 1.3/1.4 add newer synchronization, copy and dynamic-rendering forms while retaining older core commands.

## Synchronization

Fences are host-visible completion objects. Semaphores coordinate queue work; timeline semaphores add counter semantics. Events and pipeline barriers order work within command streams. Synchronization2 gives the newer stage/access-mask model and queue-submit form. The compiler/runtime should express actual resource dependencies and lower them to Vulkan synchronization rather than defaulting to global stalls.

## Dynamic rendering versus render passes

Traditional render-pass/framebuffer operations remain core but Vulkan 1.3 introduced dynamic rendering and Vulkan 1.4 formally deprecates substantial legacy render-pass machinery in the registry. For a new tiny Idriç renderer, dynamic rendering is likely the cleaner first host path if the actual Deck driver acceptance fixture confirms it.

## Queries and evidence

Query pools and timestamps give GPU-side observability. A backend comparison should retain: source Idriç/IR, emitted GLSL, emitted SPIR-V, device/driver properties, validation output, framebuffer or compute oracle, and timing only where query support and synchronization make it meaningful.

## Core versus platform extensions

Swapchain/surface commands are not Vulkan core; they are KHR WSI extensions. They matter to the Steam application but not to defining the core shader compiler. The Steam platform branch should own which Linux window-system/swapchain route launches a visible frame, while this branch owns the shader/pipeline contract.

Reference: https://github.com/KhronosGroup/Vulkan-Headers/blob/main/registry/vk.xml