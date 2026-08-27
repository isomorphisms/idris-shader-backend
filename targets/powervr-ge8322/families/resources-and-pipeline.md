# GLES resources and pipeline families

The shader language is only half the executable contract. OpenGL ES host calls create shader/program objects, upload source, compile/link, create buffers/textures/framebuffers, establish state, draw, synchronize and read back results. `SURFACE.txt` lists the OpenGL ES 3.0 core commands by name.

## Shader/program lifecycle

The central lifecycle is `glCreateShader` → `glShaderSource` → `glCompileShader`, attach shaders to a program, `glLinkProgram`, query logs/status, then `glUseProgram`. Program binaries are available through the ES 3.0 program-binary calls, but generated GLSL remains the inspectable compiler artifact. A driver-produced binary is target/driver-specific evidence, not the portable source of truth.

## Uniforms and uniform blocks

Simple uniforms are located and uploaded with the `glUniform*` family. ES 3.0 additionally exposes uniform blocks and indexed buffer binding. The compiler should distinguish ordinary scalar/vector uniforms from block-backed data because layout, alignment and update frequency are different constraints.

## Vertex inputs and instancing

Vertex arrays, vertex attribute pointers, integer attribute pointers, buffer objects, element buffers, divisors and instanced draw commands form the geometry-input family. This belongs below the mathematical shader IR: the same vertex shader expression may be fed by several host layouts.

## Textures and samplers

Textures have independent storage/image upload, parameter and sampler-object state. GLSL sampler values are opaque handles supplied through the host binding model. The backend should not turn a sampler into a CPU-like pointer. Texture format, filtering, addressing and mip state affect the semantics/cost of a sampling operation even though the shader call is compact.

## Framebuffers and renderbuffers

Framebuffer attachment commands, renderbuffer storage, multisample storage, draw-buffer selection, blit, invalidate and clear operations describe render destinations. On a tile-based PowerVR renderer, invalidate/discard behavior and avoiding needless external-memory traffic can matter substantially; these are host-side scheduling/resource choices, not reasons to distort the shader mathematics.

## Queries and synchronization

ES 3.0 query objects, fences/sync objects, mapped buffer ranges and explicit waits provide the main observability/synchronization tools in the pinned core. Timing should be treated as hardware evidence only when the relevant query/timer path is actually exposed by the phone driver; extension timer queries are not silently assumed by this ES 3.0 baseline.

## Phone acceptance

Every hardware-specialized claim should be tied back to a receipt from the real phone: renderer/version strings, extensions, limits, framebuffer output and timing/profiling evidence where available. Public model specifications are useful for choosing experiments but do not override the runtime driver report.