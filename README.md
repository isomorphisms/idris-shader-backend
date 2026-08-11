# Idris2 → GLSL ES backend slice

This project contains an actual Idris2 code generator named `glsles`. It is
registered through `Idris.Driver.mainWithCodegens`, consumes Idris ANF, and
compiles a deliberately restricted first-order numerical subset to GLSL ES
3.00 fragment shaders.

It does not pretend that arbitrary Idris can run inside GLSL. Unsupported
closures, recursive calls, heap-shaped data, IO, and partial application are
rejected with backend errors.

```text
ordinary restricted Idris source
        │
        ├─ inspect exported Idris type before erasure
        │    SVec 2 → Double → SVec 4
        │
        ▼
Idris2 ANF ── subset checking / helper specialization
        ▼
typed linear shader IR (vector width is Nat)
        ▼
temporary lowering / deterministic CSE
        ▼
GLSL ES 3.00 fragment shader
```

The earlier embedded `Expr` compiler remains in the project as a small direct
shader IR, pure evaluator, and correctness oracle. The compiler-facing path no
longer requires users to construct that AST by hand.

## What an input shader looks like

`src/Example/CompilerSphere.idr` contains an ordinary Idris function:

```idris
%export "glsles:fragment|v_uv=in,u_time=uniform"
sphere : SVec 2 -> Double -> SVec 4
sphere uv time =
  let px = 1.35 * x uv
      py = 1.35 * y uv
      -- polynomial, gradient, normal and lighting ...
   in vec4 red green blue 1.0
```

The export annotation supplies only GLSL names and storage classes. The
backend reads `vec2`, `float`, and `vec4` from the checked Idris signature
before those types are erased. A duplicated textual type declaration cannot
drift away from the Idris type.

`Shader.Source.SVec n` carries vector width as an Idris index. Operations such
as

```idris
dot : SVec n -> SVec n -> Double
```

therefore reject mismatched widths in Idris itself. The backend's internal IR
also represents vectors as `TVec Nat`, rather than duplicating every operation
for vec2, vec3, and vec4.

## Accepted subset

- `Double` literals, arithmetic, negation, comparisons, `sin`, `cos`, and
  `sqrt`
- `SVec 2`, `SVec 3`, and `SVec 4`
- vector construction, components, addition, subtraction, scaling, dot,
  length, and normalization
- scalar `abs`, `min`, `max`, `clamp`, and `mix`
- `let` bindings and pure Boolean conditionals
- saturated calls to first-order helper functions; their ANF bodies are
  specialized into one fragment body
- fragment inputs and uniforms described by the `%export` annotation

The source API makes invalid component access fail during Idris checking: for
example, `w` requires a vector of width at least four.

## Explicitly rejected

- recursion, including otherwise total recursive data traversals
- closures, higher-order calls, and partial application
- lists, user constructors, and other heap-shaped runtime data
- IO, crashes, holes, strings, arbitrary integers, and unsupported primitives
- implicit or auto arguments on the exported shader entry
- entry types outside `Double`, `Bool`, and `SVec 2` through `SVec 4`
- fragment results other than `SVec 4`

This boundary is intentional. Bounded renderer iteration/root search should be
added as an explicit shader construct or a statically unrolled source form,
not by silently accepting general recursion.

## Build the backend

A self-hosting Idris2 0.8.0 or newer installation is required. Its `idris2`
compiler API package must be installed; from the Idris2 source tree this is:

```sh
make install-api
```

Then build the registered compiler:

```sh
make backend
```

Compile the ordinary Idris sphere shader:

```sh
./build/exec/idris2-glsles \
  --cg glsles \
  --source-dir src \
  --output-dir generated \
  src/Example/CompilerSphere.idr \
  -o compiler-sphere
```

This writes `generated/compiler-sphere.frag`. The `make generate-compiler`
target also writes the inspectable pre-CSE golden dump at
`generated/compiler-sphere.ir`.

The compiler's ordinary `--dumpanf FILE` option exposes its input IR. The
backend also exposes its own checked linear IR:

```sh
./build/exec/idris2-glsles --cg glsles \
  --directive dump-ir=/tmp/sphere.shader-ir \
  --source-dir src src/Example/CompilerSphere.idr -o compiler-sphere
```

## Test

```sh
make check
```

The checks cover:

- the original pure evaluator and symbolic polynomial derivative oracle
- direct typed-IR GLSL generation and its golden shader
- ordinary Idris source → ANF → GLSL generation and its golden shader
- specialization of deliberately non-inlined first-order helpers
- conditional lowering and common-subexpression elimination
- rejection of recursion, heap constructors, bad entry results, and bad
  interface arity
- an Idris type error for a `dot` product between `SVec 2` and `SVec 3`
- structural GLSL checks and `glslangValidator` when available

## Source map

- `src/Shader/Source.idr` — indexed source-level vector API and shader
  primitives
- `src/Backend/GLSLES/Signature.idr` — reads argument/result dimensions from
  checked Idris types before erasure
- `src/Backend/GLSLES/Interface.idr` — `%export` interface parser and name
  validation
- `src/Backend/GLSLES/IR.idr` — typed linear shader IR with `TVec Nat`
- `src/Backend/GLSLES/Lower.idr` — ANF subset checker, type inference, helper
  specialization, and lowering
- `src/Backend/GLSLES/Emit.idr` — GLSL ES emission and CSE
- `src/Backend/GLSLES/Codegen.idr` — Idris2 `Codegen` implementation
- `src/Backend/GLSLES/Main.idr` — `idris2-glsles` compiler executable
- `src/Example/CompilerSphere.idr` — ordinary Idris compiler example
- `generated/compiler-sphere.ir` — checked typed-IR dump for that example
- `src/Shader/IR.idr` / `Eval.idr` / `Polynomial.idr` — direct typed IR and
  reference semantics
- `src/Test/Backend/` — accepted/rejected compiler fixtures

## Current boundary

The completed path ends at validated fragment source. Android EGL/OpenGL ES
context creation, shader upload/link diagnostics, frame presentation, and GPU
differential execution remain host integration. Bounded ray construction,
root search, and surface-hit selection remain the next renderer layer.
