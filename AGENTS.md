# Agent instructions

## Cross-repository anti-patterns

These rules apply in addition to stricter repository-specific rules below.

- Claim only the boundary actually exercised. Source presence, fixtures, generation, compilation, packaging, installation, launch, smoke checks, semantic execution, backend execution, and physical-device execution are different evidence levels. If a stronger boundary was not exercised, report it as unverified.
- The named mechanism is part of acceptance. Do not substitute a fallback, oracle, mock, alternate backend, alternate executable, lookalike renderer, or conventional nearby toolchain and keep the original label.
- Do not weaken acceptance to obtain green. Repair the implementation. Change the contract only when the requirement itself is shown to be wrong or obsolete, and keep that semantic decision explicit. Targeted negative tests must fail for the intended reason when the distinction matters.
- Keep semantics independent of convenient representations. Mathematical, domain, and language objects are not defined by tuples, matrices, compiler nodes, ABI records, transport bytes, storage shapes, or UI payloads unless the semantics explicitly say so.
- Current explicit human corrections and current architecture outrank stale source, generated code, upstream conventions, older branches, bootstrap precedent, and familiar practice. Do not restore a rejected abstraction under its old name or a near-synonym.
- Acceptance belongs to an exact head and its material pins. An ancestor's, sibling branch's, or previous pin's green result is historical evidence only.
- Mocks, fixtures, harnesses, and today's platform adapter must cross replaceable interfaces; they do not get to define the permanent architecture merely because they are currently convenient.
- Preserve the repository's chosen implementation path and layout before introducing familiar infrastructure. Where `_` is an established machinery boundary, keep build/package/generated/test/compiler material there and preserve canonical source and intended soft links.

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