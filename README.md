# Idris2 → GLSL ES backend

This repository contains a real GLSL ES 3.00 code generator for a deliberately
restricted numerical subset of Idris 2.

The useful path is:

```text
ordinary Idris source
        ↓
Idris type checking
        ↓
Idris ANF (a simplified compiler representation)
        ↓
shader subset checking and first-order helper specialization
        ↓
typed linear shader representation
        ↓
GLSL ES 3.00 fragment shader
```

The restriction is intentional. A GPU fragment shader is not a general Idris
runtime. Closures, general recursion, heap-shaped data, IO, and partial
application are rejected rather than silently translated into something with
different semantics.

The compiler integration currently uses ordinary Idris 2. Moving the same
backend behind Idriç/`edric` is a separate integration step once that compiler's
surface language is settled.

## What already works

The backend reads shader argument and result types from the checked Idris
signature before those types are erased. A declaration such as

```idris
%export "glsles:fragment|v_uv=in,u_time=uniform"
sphere : SVec 2 -> Double -> SVec 4
```

therefore becomes a `vec2` fragment input, a `float` uniform, and a `vec4`
fragment result without a second handwritten type description.

`SVec n` keeps vector width in the Idris type. For example,

```idris
dot : SVec n -> SVec n -> Double
```

cannot be called with a `SVec 2` and a `SVec 3`.

`SArray n a` is a fixed shader array, not an Idris heap container. Its length
and element type survive into generated GLSL. It is currently accepted as a
uniform, for example:

```glsl
uniform vec2 u_zeros[64];
uniform float u_continuation_radii[24];
```

The accepted numerical operations now include:

- `Double` arithmetic, negation, comparisons, and Boolean conditionals
- `Int` uniforms where an integer count is needed, with explicit conversion to
  shader floating-point arithmetic
- `SVec 2`, `SVec 3`, and `SVec 4`
- vector construction, components, addition, subtraction, scaling, dot,
  length, and normalization
- `abs`, `sqrt`, `sin`, `cos`, `min`, `max`, `clamp`, and `mix`
- `floor`, `fract`, `log`, two-argument `atan`, `pow`, and `smoothstep`
- fixed uniform arrays with typed indexing
- `let` bindings and pure conditionals
- saturated calls to first-order helper functions; their bodies are
  specialized into the generated fragment

## Real renderer examples

The backend is tested on several ordinary Idris shader sources rather than
only on small synthetic expressions.

### Polynomial surface

`src/Example/CompilerSphere.idr` exercises polynomial arithmetic, derivatives,
normal construction, lighting, helper specialization, and repeated-expression
elimination. It is the original Surfer-style compiler example.

### Wegert phase portrait

`src/Shader/PhasePortrait.idr` contains the shared rational-function portrait
mathematics used by Wegert and analytic continuation:

- up to 64 zeros and 64 poles
- phase accumulation with two-argument `atan`
- log-modulus accumulation
- the established Wegert HCL constants
- CIE L*u*v* to display sRGB conversion

`src/Example/SharedFactorPortrait.idr` compiles that path into a complete
fragment shader. The 64-factor bound is explicit and finite; it does not enable
general recursion.

### Analytic continuation

`src/Shader/ContinuationOverlay.idr` adds the continuation-specific layer:

- up to 24 continuation discs
- revealed and unrevealed regions
- disc boundaries
- path segments
- center marks
- the charcoal woven unrevealed texture

`src/Example/AnalyticContinuation.idr` combines that overlay with the shared
Wegert phase portrait. Its generated fragment is validated and linked against
`fixtures/wegert-fullscreen.vert` during the checks.

The current generated continuation example covers the mathematical portrait
and continuation overlay. The zero/pole marker drawings used by the Android
apps are still a separate presentation layer.

### Bounded Surfer root search

`src/Shader/PolynomialRay.idr` proves that finite ray-root search can also be
expressed through this backend without general recursion. It currently:

- evaluates a degree-at-most-seven polynomial from eight fixed coefficients
  using Horner form
- checks 16 fixed intervals for the first sign change
- performs 20 fixed bisection refinements

`src/Example/SurferRootSearch.idr` compiles that search into a fragment shader.
This is a backend capability test, not a complete real-root isolator: a simple
sign-change search can miss even-multiplicity roots, so the final Surfer
renderer still needs the appropriate robust root-isolation algorithm.

### Disc mask

`src/Example/DiscReveal.idr` remains as a small host-integration fixture for one
supplied disc and the Wegert `v_ndc` vertex contract.

## What is deliberately rejected

The compiler currently rejects:

- general recursion, including otherwise total recursive data traversals
- closures, higher-order runtime calls, and partial application
- lists, user constructors, and other heap-shaped runtime data
- IO, crashes, holes, strings, and unsupported primitives
- implicit or auto arguments on an exported shader entry
- dynamically sized shader arrays
- fragment results other than `SVec 4`

Finite renderer work is written as explicit bounded shader computation instead
of using general recursion. This keeps the GPU execution bound visible in the
source and in the generated shader.

One current lowering detail matters when writing shader source: both sides of
an Idris conditional can be lowered into temporaries before the final GLSL
ternary is emitted. Code therefore must not rely on a dead branch to protect an
out-of-bounds array access or a division by zero.

## Build

A self-hosting Idris 2 0.8.0 or newer installation is required, including its
compiler API package. From an Idris 2 source tree:

```sh
make install-api
```

Build the registered compiler:

```sh
make backend
```

Compile the sphere example:

```sh
./build/exec/idris2-glsles \
  --cg glsles \
  --source-dir src \
  --output-dir generated \
  src/Example/CompilerSphere.idr \
  -o compiler-sphere
```

The result is `generated/compiler-sphere.frag`.

The backend can also dump its checked linear shader representation before the
final repeated-expression elimination pass:

```sh
./build/exec/idris2-glsles --cg glsles \
  --directive dump-ir=/tmp/sphere.shader-ir \
  --source-dir src src/Example/CompilerSphere.idr -o compiler-sphere
```

## Checks

Run:

```sh
make check
```

The checks cover:

- the original pure evaluator and symbolic polynomial derivative reference
- generated GLSL and typed shader representations compared with checked-in
  expected outputs
- ordinary Idris source through the complete compiler path
- first-order helper specialization
- conditionals and repeated-expression elimination
- scalar shader operations used by the phase portrait
- fixed scalar and vector uniform arrays
- the full 64-zero/64-pole Wegert portrait
- the 24-step analytic-continuation overlay and vertex/fragment linking
- the bounded Surfer polynomial root-search example
- rejection of recursion, heap constructors, bad results, bad interfaces, and
  mismatched vector widths
- GLSL syntax validation with the external Khronos validator when available

## Source map

- `src/Shader/Source.idr` — source-level shader vectors, fixed arrays, and
  primitives
- `src/Backend/GLSLES/Signature.idr` — reads checked Idris argument and result
  types
- `src/Backend/GLSLES/Interface.idr` — parses exported shader names and storage
  classes
- `src/Backend/GLSLES/IR.idr` — typed linear shader representation
- `src/Backend/GLSLES/Lower.idr` — checks the supported subset and lowers Idris
  ANF into shader operations
- `src/Backend/GLSLES/Emit.idr` — emits GLSL ES and removes repeated pure
  expressions
- `src/Backend/GLSLES/Codegen.idr` — Idris 2 code-generator registration
- `src/Backend/GLSLES/Main.idr` — compiler executable
- `src/Shader/PhasePortrait.idr` — shared Wegert/continuation portrait math
- `src/Shader/ContinuationOverlay.idr` — continuation reveal/path layer
- `src/Shader/PolynomialRay.idr` — bounded polynomial ray-search primitives
- `src/Example/CompilerSphere.idr` — polynomial surface example
- `src/Example/SharedFactorPortrait.idr` — 64-factor Wegert portrait example
- `src/Example/AnalyticContinuation.idr` — combined continuation example
- `src/Example/SurferRootSearch.idr` — bounded Surfer root-search example
- `fixtures/wegert-fullscreen.vert` — matching Wegert fullscreen vertex stage
- `src/Test/Backend/` — accepted and rejected compiler fixtures

## Current boundary

The backend now reaches validated GLSL for all three relevant numerical
families: polynomial surface work, Wegert rational phase portraits, and the
analytic-continuation overlay. The remaining work is mostly renderer-specific:

- zero/pole marker presentation for exact Wegert/continuation visual parity
- a robust root-isolation strategy for the full Surfer renderer
- Android host asset/uniform/frame integration where an app still uses
  handwritten GLSL
- eventual Idriç/`edric` compiler integration

General recursion and arbitrary heap data are not required for those next
steps and remain outside the shader subset.
