# Whole-plane holomorphic explorer: shader follower contract

## Scope

[`isomorphismes/analytic-continuation`](https://github.com/isomorphismes/analytic-continuation/blob/main/docs/holomorphic-mathematical-contract.md) owns the live mathematical object

```text
f(z) = R(z) exp(q(z)),
q entire.
```

This shader backend may eventually lower and evaluate an already-approved descriptor for `q`. It does not decide which perturbations are holomorphic, which Hilbert-space norm defines a canonical local direction, or which visual motion is successful.

The in-flight general complex/projective arithmetic effort in Idriç owns the shared numerical semantics. Shader support should follow its versioned corpus rather than creating another complex type hierarchy for this application.

## Exact handoff

At a regular point of the explicit meromorphic divisor, a follower implementation evaluates the approved descriptor and applies

```text
log_modulus = log|R(z)| + Re(q(z))
phase       = phase(R(z)) + Im(q(z))  (mod 2 pi)
```

before calling the canonical [Wegert](https://github.com/isomorphismes/wegert) value/phase/log-modulus-to-colour behavior. It need not form `exp(q)` solely to recover those two quantities.

The descriptor may be a polynomial, a finite list of entire reproducing-kernel directions, or a later approved representation. A finite array bound, coefficient packing, evaluation order, shader stage, or precision choice is an implementation contract with stated errors; none is the definition of the admissible entire-function space.

## Prohibited semantic shortcuts

The backend must not use any of the following to define or certify holomorphy:

- RGB differences or a screen-wide visual energy;
- `dFdx`, `dFdy`, or other screen-space finite differences;
- the visibility of a singularity inside the current viewport;
- a backend-specific finite coefficient count;
- successful shader generation, compilation, or rendering by itself.

Those quantities can support optimization or visual analysis after the mathematical descriptor is approved. They cannot turn a function with an exterior pole into an entire one.

## Existing continuation-named fixture

`src/Example/AnalyticContinuation.idr` and `src/Shader/ContinuationOverlay.idr` currently exercise a 24-disc reveal/path overlay over an already-known rational Wegert portrait. They are useful bounded shader capability fixtures, but they do not transport a germ and do not implement the live whole-plane random explorer.

Bounded/local-domain, chart, branch, sheet, and monodromy experiments belong to [`isomorphismes/lacunary`](https://github.com/isomorphismes/lacunary). Their historical disc descriptors must not be silently reused as whole-plane `q` descriptors.

## Evidence expected from later integration

A future live-explorer integration should keep separate evidence that:

1. a versioned host oracle accepts the descriptor and evaluates `q`, `Re(q)`, and `Im(q)`;
2. the shader agrees on the same descriptor corpus within declared precision;
3. `Re(q)` and `Im(q)` reach log modulus and phase before Wegert colouring;
4. generated source compiles and links;
5. the intended shader is loaded and executed, with numeric or image readback;
6. the exact artifact executes on the named target hardware and driver.

Visual approval of scale, anchor distribution, amplitude, phase/sign, lifetime, temporal correlation, overlap, active count, and cadence remains a separate user judgment. No GPU acceptance result makes those choices mathematical necessities.
