# Complex/projective GPU follower

This repository follows the shared complex/projective semantics. It does not define them.

For this subsystem, the current implementation hierarchy is:

```text
canonical mathematical/type semantics
    -> direct x86-64 executable leader and CPU oracle
    -> shared numerical/projective corpus
    -> shader/GPU followers
```

This exception does not make x86-64 the general Idriç backend leader.

## Representation boundary

`Shader.ComplexProjectiveFollower` lowers one complex scalar to `SVec 2` because GLSL ES naturally carries the two arithmetic coordinates in a `vec2`. That is a target representation. It is not the source-language meaning of `Complex`, and it does not identify a complex coordinate space C^n with an arbitrary shader vector.

Projective values remain homogeneous coordinates semantically. The initial shader follower exercises CP^1 with the invariant wedge

```text
z0*w1 - z1*w0
```

and with an explicit common nonzero scaling witness. It does not compare homogeneous components for raw equality, does not introduce projective vector addition, and does not normalize after each operation.

## Holomorphic boundary

The follower fragment evaluates

```text
f(z) = R(z) exp(q(z))
```

using Cartesian complex add/multiply/divide, with `R` carrying one explicit zero and pole and `q` a nonconstant entire quadratic polynomial. The current `exp` follower is the same bounded degree-7 polynomial used by the shared Float32 corpus and is only a follower of the `|q| <= 0.5` acceptance domain.

Conjugation, magnitude, and phase are observational/non-holomorphic operations. The fixture uses magnitude only after the complex field has been formed, for output coloring. It does not insert phase, logarithm, conjugation, screen derivatives, or viewport-derived tests into the evolving holomorphic factor.

## Precision

The present main-line shader backend's checked IR treats its existing `Double` source surface as Float32/highp shader semantics. This follower preserves that existing declared path; it does not globally narrow to mediump merely because a target can execute FP16.

Target-specific F16/mediump work remains a separate follower optimization and must continue to record the actual declared precision.

## Evidence levels

`tools/check_complex_projective_follower.py` retains the typed IR and generated GLSL ES, validates the fragment with `glslangValidator`, and links it with the existing fullscreen vertex fixture.

That proves:

```text
typed IR generated
GLSL ES generated
GLSL ES compiled/validated
vertex + fragment linked
```

It does **not** prove that a shader was loaded by a driver, executed by a GPU, captured from a framebuffer, or run on a particular vendor device. The receipt marks those stages `SKIP` rather than fabricating hardware evidence.

Existing PowerVR, Mali, Switch/Maxwell, RDNA2/Vulkan, WebGPU/WGSL, Metal-research, NVIDIA, and Adreno target work remains downstream of the same mathematical contract. A target can strengthen its receipt independently without becoming the semantic leader.
