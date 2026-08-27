# Vulkan GLSL source-language family

The first Steam Deck emitter should print GLSL accepted under the Vulkan environment and let Khronos tooling produce SPIR-V. That is deliberately different from treating ordinary desktop OpenGL GLSL as the target.

## Why keep GLSL and SPIR-V separate

GLSL is the human-readable source artifact produced by the first backend. SPIR-V is the typed binary module actually consumed by Vulkan. Keeping both receipts lets us tell whether an optimization was a source rewrite or a lower-level SPIR-V/driver effect.

The long-term compiler may eventually emit SPIR-V directly. Until then, GLSL should stay simple, explicit and inspectable rather than trying to outsmart `glslang` with source tricks whose machine effect is unknown.

## Vulkan interface rules

Resources are described explicitly through set/binding layouts, uniform/storage blocks, push constants, images/samplers and stage inputs/outputs. Specialization constants use `constant_id`; compute workgroup size may be literal or specialization-ID based. These interface facts should come from typed shader metadata, not handwritten layout strings in application code.

## Numerical surface

The language has the usual GLSL 4.60 arithmetic, common mathematical functions, vectors/matrices, bit operations, texture/image access, derivatives, atomics and barriers. `VULKAN-GLSL-SURFACE.txt` lists the names. The important compiler policy is to preserve semantic operations—`fma`, dot products, reciprocal/inverse-square-root intent, packed/half data, atomics, resource classes—until late enough that the SPIR-V/AMD path can make architecture-specific choices.

## Precision

Unlike GLSL ES, desktop/Vulkan GLSL precision qualifiers do not give the same simple PowerVR-style `mediump` story. Smaller arithmetic should be represented through actual types/capabilities/extensions and verified in emitted SPIR-V. Do not use a cosmetic `mediump` qualifier as a substitute for proving that FP16 survived the path.

## Vulkan validity

A construct being legal in generic GLSL 4.60 does not guarantee it is legal in the Vulkan GLSL environment. The generated source must be compiled for a pinned Vulkan target environment, then the SPIR-V module must be validated for that environment. Device feature negotiation remains a separate runtime gate.

## Exclusions

Legacy compatibility-profile features, OpenGL default uniforms/state, WSI, ray tracing, mesh/task stages and vendor extensions are outside the initial branch. Add one only with an explicit capability/validation oracle rather than expanding the baseline implicitly.

References:
- https://registry.khronos.org/OpenGL/specs/gl/GLSLangSpec.4.60.pdf
- https://github.com/KhronosGroup/glslang
- https://registry.khronos.org/SPIR-V/specs/unified1/SPIRV.html
