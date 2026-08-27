# Fragment derivatives / local differential information

Relevant public operations include `dfdx`, `dfdy`, and `fwidth` families. Derivatives are especially natural for the complex renderer: screen-space antialiasing, phase/log-modulus variation, local conformality diagnostics and singularity/refinement heuristics.

Derivative results are local raster approximations, not exact complex derivatives. Do not silently identify them with f'(z). Keep an explicit distinction between an analytic derivative, a finite-difference estimate, and a screen-space derivative.
