# Short names and long names

This file is a reading aid for the deliberately small shader language used by this repository.
The short spelling is kept because it is what the compiler currently recognizes. The long
spelling is the ordinary-language meaning to have in mind while reading the source.

None of these long names changes the language yet. They are documentation first; later we can
decide whether some deserve actual long aliases in `Shader.Source`.

## Source-level shader names

| Short spelling | Read it as | What it means here |
| --- | --- | --- |
| `SVec n` | shader vector of length `n` | An opaque GPU vector whose component count is checked by Idris. |
| `SArray n a` | shader array of `n` values of type `a` | A fixed-size shader interface array, not an Idris heap list. |
| `vec2` | make a 2-component vector | Construct `(x,y)`. |
| `vec3` | make a 3-component vector | Construct `(x,y,z)`. |
| `vec4` | make a 4-component vector | Construct `(x,y,z,w)`; for fragment colour this is normally `(red,green,blue,alpha)`. |
| `x`, `y`, `z`, `w` | first, second, third, fourth component | Read one component of a shader vector. |
| `vadd` | vector add | Add corresponding vector components. |
| `vsub` | vector subtract | Subtract corresponding vector components. |
| `scale` | scale vector | Multiply every vector component by one scalar. |
| `dot` | dot product | Multiply matching components and add the products. |
| `length` | Euclidean length | Square root of the sum of squared components. |
| `normalize` | make unit length | Divide a vector by its length when that operation is defined. |
| `array_at` | array value at index | Read one element of a fixed shader array. |
| `int_to_double` | convert integer to shader floating point | Lowers to GLSL `float(...)`; the current production shader path is F32/highp. |

## The `F` suffix

For helpers such as `minF`, the final `F` means: **this is the floating-point shader helper**.
It is there to keep these externals distinct and recognizable to the backend.

| Short spelling | Read it as | Emitted GLSL |
| --- | --- | --- |
| `absF x` | floating-point absolute value of `x` | `abs(x)` |
| `sqrtF x` | floating-point square root of `x` | `sqrt(x)` |
| `sinF x` | floating-point sine of `x` | `sin(x)` |
| `cosF x` | floating-point cosine of `x` | `cos(x)` |
| `floorF x` | greatest integer-valued float not above `x` | `floor(x)` |
| `fractF x` | fractional part of `x` | `fract(x)` |
| `logF x` | natural logarithm of `x` | `log(x)` |
| `minF a b` | smaller floating-point value | `min(a,b)` |
| `maxF a b` | larger floating-point value | `max(a,b)` |
| `atan2F y x` | angle of the point `(x,y)` with quadrant information | `atan(y,x)` |
| `powF x p` | `x` raised to power `p` | `pow(x,p)` |
| `clampF x lo hi` | keep `x` between `lo` and `hi` | `clamp(x,lo,hi)` |
| `mixF a b t` | interpolate from `a` to `b` by `t` | `mix(a,b,t)` |
| `smoothstepF lo hi x` | smooth 0-to-1 transition across an interval | `smoothstep(lo,hi,x)` |

## Interface abbreviations

| Short spelling | Read it as | Meaning |
| --- | --- | --- |
| `GLSL ES` / `glsles` | OpenGL ES Shading Language | The language emitted by this backend. |
| `fragment` | fragment shader | The program evaluated for each rasterized fragment/pixel candidate. |
| `NDC` / `ndc` | normalized device coordinates | Screen-oriented coordinates after the usual graphics coordinate normalization. In the fullscreen fixtures, `x` and `y` run roughly from -1 to +1. |
| `v_ndc` | varying/input normalized device coordinates | The interpolated NDC coordinate supplied to the fragment shader. |
| `v_...` | varying/input value | Naming convention for a value interpolated into the fragment stage. This prefix is a convention, not a GLSL requirement. |
| `u_...` | uniform value | Naming convention for a value supplied for the draw and shared by fragments. |
| `RGBA` | red, green, blue, alpha | Four colour/output components. |
| `F16` | 16-bit floating-point semantic width | Intended lower-precision shader arithmetic where supported. |
| `F32` | 32-bit floating-point semantic width | Current default production shader arithmetic. |
| `highp` | high precision | GLSL ES precision class used by the current F32 path. |
| `mediump` | medium precision | GLSL ES precision class used by the F16-oriented path; portable GLES does not guarantee exact IEEE binary16. |
| `_idris_t0`, `_idris_t1`, ... | compiler temporary 0, 1, ... | Intermediate values introduced by the backend. |

## PowerVR-side abbreviations

| Short spelling | Read it as | Meaning |
| --- | --- | --- |
| `GPU` | graphics processing unit | The processor executing the shader work. |
| `USC` | Unified Shading Cluster | PowerVR shader-execution core terminology. |
| `ISR` | instruction-set-reference assembly | The assembly notation used by Imagination's public PowerVR instruction-set reference. |
| `EGL` | EGL graphics interface | The API used by the native probe to create an OpenGL ES context/surface. |
| `GLES` | OpenGL ES | The graphics API through which the phone driver receives the shaders and draw calls. |

## Local names are allowed to be ordinary words

A name such as `ink` is not a GPU instruction and is not special syntax. In the old X example,
`ink` merely meant "how much white ink should this fragment receive?" and happened to be either
`0.0` or `1.0`.

Likewise `diagonal`, `red`, `green`, `blue`, `result`, `residual`, and similar names are just
programmer-chosen labels. Prefer ordinary descriptive names in new teaching examples when they do
not make the mathematics harder to see.
