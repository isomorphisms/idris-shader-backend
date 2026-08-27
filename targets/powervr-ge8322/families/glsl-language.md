# GLSL ES 3.00 language families

## Types

The pinned baseline has `bool`, signed and unsigned 32-bit integers, and `float`, plus fixed-width vectors and rectangular/square floating matrices. Sampler types describe 2D, 3D, cube and array textures, including integer and shadow-sampling variants. GLSL ES 3.00 has no general heap, arbitrary pointer arithmetic, closures, dynamically allocated arrays, or recursive runtime in the sense expected by a CPU language. That matches the existing restricted shader IR well.

For Idriç, the important compiler rule is that the source type should survive long enough to choose a target representation deliberately. In particular, source `Float16` intent must not be erased into an undifferentiated `float` before the PowerVR lowering gets to decide between `mediump` and `highp`.

## Expressions and control

The language gives ordinary scalar/vector arithmetic, comparisons, logical and bitwise operations, assignments, swizzles/indexing, function calls and constructors. Control flow consists of `if`, `switch`, bounded or data-dependent loops (`for`, `while`, `do`), `break`, `continue`, `return`, and fragment `discard`.

The existence of loops in GLSL does not imply that the Idriç shader subset should immediately accept arbitrary recursive source programs. Keeping finite iteration explicit is still useful for predictability, validation and GPU cost reasoning.

## Numerical built-ins

The standard numerical families are deliberately close to ordinary mathematical notation: trigonometric functions, exponential/logarithmic functions, `sqrt`/`inversesqrt`, common rounding and interpolation functions, vector geometry, matrix operations, integer bit manipulation, and relational reductions. The backend should preserve these as semantic operations in the shared shader IR where possible instead of prematurely expanding all of them into scalar arithmetic.

That matters on PowerVR because semantically equivalent GLSL expressions can expose different packing opportunities. Imagination's public guide gives concrete examples: reciprocal and reciprocal-square-root are direct operations; `sqrt` commonly becomes reciprocal-square-root plus reciprocal; grouping MAD/SOP-shaped work can improve packing; and manually expanding some compound vector built-ins can sometimes expose common subexpressions.

## Texture and derivative operations

The GLSL ES 3.00 texture family covers implicit sampling, explicit LOD, projected sampling, offsets, gradients and direct texel fetch. `dFdx`, `dFdy` and `fwidth` are fragment-stage derivative operations. These are not ordinary pure scalar library functions: they depend on the GPU execution model and, for derivatives, on neighboring fragment invocations. The shared IR should therefore distinguish them from ordinary arithmetic.

## Interface qualifiers

`in`, `out`, `uniform`, interpolation qualifiers, layouts and precision qualifiers determine how a shader crosses the pipeline boundary. They should be generated from typed interface metadata, not handwritten strings scattered through application code.

## Reference

Normative language reference: https://registry.khronos.org/OpenGL/specs/es/3.0/GLSL_ES_Specification_3.00.pdf