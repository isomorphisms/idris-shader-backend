# Agent instructions

Apply the shared evidence and acceptance guardrails in
`isomorphisms/ai-ci/AGENTS.md`. The rules below are specific to this compiler
backend. Read [`README.md`](README.md) before changing its supported subset or
acceptance boundary.

## Backend claims require backend output

Do not count a reference evaluator, CPU implementation, handwritten GLSL, mock,
fixture, or lookalike renderer as acceptance of this backend.

A compiler-path claim must start from ordinary checked source, pass through the
registered backend at the exact revision under review, and identify the emitted
shader. If rendering is claimed, the running renderer must actually select and
draw with that emitted shader. Successful emission or GLSL validation alone is
not live rendering evidence.

A fallback may be useful for comparison, but label it as a fallback; it cannot
make the named backend pass.

## Preserve the intentional refusal boundary

Do not make a failing example pass by silently translating recursion, closures,
heap-shaped data, unsupported effects, bad interfaces, mismatched widths, or
other rejected constructs into weaker semantics.

Do not remove or dilute negative fixtures merely to obtain green. Change an
accepted/rejected boundary only for an explicit semantic decision, then update
both positive and targeted negative evidence.

## Keep backend evidence levels distinct

A mathematical oracle agreeing, backend emission, shader syntax/link
validation, a live renderer selecting the shader, and execution on a named
physical GPU are separate claims. Evidence for one does not imply the next.
SwiftShader or another emulator renderer is not physical-GPU evidence.

Record the exact backend head and compiler/API revision that produced accepted
output. When a downstream app consumes generated shaders, retain enough
provenance to show which backend generated the asset and whether the app
actually selected it.
