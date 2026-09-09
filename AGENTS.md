# Agent instructions

## Backend claims require backend output

Do not count a reference evaluator, mock backend, CPU implementation, handwritten GLSL, fixture, or lookalike renderer as acceptance of this compiler backend.

A compiler-path claim must start from ordinary checked source, pass through the registered backend at the exact revision under review, and inspect or validate the emitted shader artifact. If the claim includes rendering, the emitted shader must be the shader selected by the running renderer; successful emission or `glslang` validation alone is not live rendering evidence.

A fallback may be useful for comparison, but it must be labeled as a fallback and cannot make the named backend pass.

## Preserve refusal semantics

The restricted shader subset is intentional. Do not make a failing example pass by silently translating recursion, closures, heap-shaped data, unsupported effects, bad interfaces, or mismatched widths into weaker semantics.

Do not remove or dilute negative fixtures merely to get green. If an accepted/rejected boundary changes, justify the language/backend semantic change independently and update both positive and targeted negative evidence.

## Separate oracle, compile, link, and runtime evidence

Keep these claims distinct:

- a mathematical/reference oracle agrees;
- the backend emitted the intended IR/GLSL;
- the emitted shader passed syntax/link validation;
- a renderer selected and drew with that shader;
- a named physical GPU/device executed it.

Evidence for an earlier item does not imply a later one. In particular, SwiftShader or another emulator renderer is not evidence for a named physical GPU.

## Exact source and compiler provenance

Record the exact backend head and the exact compiler revision/API used to produce accepted output. Old generated files or a green run from another head are historical fixtures, not current acceptance.

When downstream apps consume generated shaders, keep enough provenance to show which backend revision generated the asset and whether the app actually selected it.