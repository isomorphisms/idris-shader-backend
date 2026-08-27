# Shader backend implementation adverbs

Date: 2026-08-26

## Connection to the Arm backend

The Arm `X\b` × 100,000 fixture exposes a general distinction between semantic intent and implementation policy. The same distinction matters in a shader backend even though the concrete choices are different.

A shader expression can have more than one valid realization, and the best realization can depend on target GPU, precision requirements, divergence, register pressure, memory bandwidth, and whether the programmer permits approximation.

These choices should be exposed as implementation **adverbs** where they are materially consequential rather than buried in one backend heuristic.

## Example adverb families

### Precision

```text
exact-within-source-contract
f32
f16
mixed-precision
approximate tolerance
```

A precision choice is not automatically semantics-preserving. The compiler must know what disagreement is permitted before lowering an F32 computation to F16 or replacing an operation with an approximation.

### Branch realization

```text
branching
branchless
predicated/select
```

On some inputs/hardware, a real branch can be better; on others, divergent lanes can make branchless/select forms preferable. The source meaning alone does not always determine the best execution policy.

### Repetition

```text
looped
unrolled N
fully-unrolled
```

This mirrors the Thumb lesson directly:

- a loop stores repetition compactly and performs the repetition in time;
- unrolling spends code size to remove some loop/control overhead and can expose more scheduling/constant-folding opportunities.

Neither should be universally declared "optimized" without target/context.

### Algebraic transformation

```text
strict-order
reassociated
fused
non-fused
```

Floating-point reassociation and fusion can change results. Such transformations need an explicit numerical contract/tolerance, not merely a speed preference.

### Storage/location

Potential future policy dimensions include:

```text
register/local
shared/workgroup
uniform
texture/buffer
precompute-on-CPU
compute-on-GPU
```

Again the compiler can expose candidates and costs when the choice is not semantically forced.

## Conversation rather than hidden heuristics

A useful compiler/backend interaction could report something like:

```text
This loop has a compile-time trip count of 64.

looped:
  smaller generated shader
  loop/control overhead remains
  lower instruction footprint

unrolled:
  larger shader
  exposes constant folding/scheduling
  may increase register pressure

adaptive/profiled:
  choose from target GPU/profile evidence
```

Or:

```text
This expression can be lowered to F16.

F32:
  preserves current precision contract

F16:
  lower precision/storage/bandwidth on supported hardware
  numerical disagreement possible

mixed:
  retain sensitive operations in F32
  lower selected intermediates to F16
```

The programmer should be able to record the answer once in source/project/deployment policy.

## Multiple variants plus selector

As on CPU, there is no requirement that compilation produce only one implementation.

For host-controlled dispatch, a build can contain:

```text
shader/F32
shader/F16
shader/branching
shader/branchless
host selector
```

The selector can choose by:

- GPU capabilities;
- measured performance for a device family;
- required precision mode;
- workload size/shape;
- power/performance profile.

Inside a shader, dynamic selection itself may be undesirable because it can introduce divergence, so the appropriate selector location is part of the policy design.

## Backend cost/capability report

Candidate realizations should eventually report facts such as:

- generated instruction/source size;
- required GLSL ES version/extensions;
- precision qualifiers/types;
- approximate operation count;
- loop/unroll structure;
- branch/divergence structure;
- estimated or measured register pressure when available;
- local/shared memory use;
- texture/buffer traffic;
- numerical tolerance/known disagreement;
- target capability requirements.

Unknown properties should remain `unknown` rather than be replaced by false precision.

## Semantic boundary

The backend must keep distinct:

1. transformations proved equivalent under the shader/source semantics;
2. transformations equivalent only under a relaxed numerical/observational contract;
3. genuinely different algorithms that happen to serve the same higher-level purpose.

Only (1) should be silently automatic by default.

(2) needs a declared adverb/tolerance/profile.

(3) should be surfaced as an explicit implementation choice or separate program.

## Relation to current shock/gain work

Classifiers such as local gain categories make the distinction especially relevant. If thresholds or neighborhoods are meaningful mathematical boundaries, approximate precision and algebraic transformations can move values across a category boundary.

Therefore a performance adverb must not silently change classifier semantics. Tests should include values at and around boundaries under every permitted precision policy.

## Shared architecture with Idriç

The desired layering is reusable across backends:

```text
semantic IR
      ↓
required observations / numerical contract
      ↓
implementation adverb/profile
      ↓
backend candidate realizations
      ↓
reported costs + capabilities
      ↓
static selection or external dispatcher
      ↓
shader code
```

The shader backend should participate in this protocol rather than invent an unrelated set of opaque optimization flags.