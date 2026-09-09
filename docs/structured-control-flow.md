# Structured shader control flow

## Goal

The shader backend should preserve structured source control flow instead of flattening it to value selects and reconstructing it later.

The current recovery pass fixed a serious performance regression, but it is transitional architecture. It should not become the long-term representation of branches or loops.

## Current failure mode

The current lowering path turns an Idris boolean case into two eagerly lowered branch bodies followed by `RSelect`. A later pass scans the already-linear IR and moves sufficiently expensive branch-local bindings back under GLSL `if`/`else` blocks.

That works for correctness and recovered the Analytic Continuation performance failure, but it loses the original control-flow object and has to infer it from dependencies.

The Analytic Continuation candidate also currently spells out 32 zero slots and 32 pole slots manually because the backend has no bounded-loop representation. The resulting generated shader is therefore fast after recovery but still contains dozens of repeated guarded chunks.

## Required architecture

The checked shader IR should contain structured statements directly:

- binding;
- conditional with typed result and branch-local blocks;
- bounded loop with an explicit induction value, upper bound, loop-carried typed state, body block, and result.

A source conditional should lower directly to the conditional statement. It should not first become an eager select.

A bounded source iteration should lower directly to the loop statement. It should not be manually duplicated in source, unrolled by default, or rediscovered from a large linear binding graph.

Target emitters may later choose a target-specific realization such as a select, branch, compact loop, partial unroll, or full unroll, but that is an optimization decision made from preserved structure. The semantic IR remains structured.

## Analytic Continuation acceptance

The current manual 32+32 factor expansion is retained only as a reference oracle while this work is developed.

The replacement fixture must express factor accumulation once and prove all of the following:

1. typed IR contains one bounded zero loop and one bounded pole loop;
2. the loop bound is tied to the fixed array capacity and the runtime active count without permitting an out-of-range array access;
3. `atan` and `log` are inside the loop body and execute only for active factors;
4. generated GLSL contains compact structured loops rather than 64 copied guarded factor bodies;
5. lowp and highp differ only by the requested precision policy, not by mathematical/control-flow meaning;
6. framebuffer output remains equivalent to the current reference path within the established tolerance;
7. physical-device responsiveness does not regress from the repaired build.

## Non-goals

Do not add an Analytic-Continuation-specific backend primitive.

Do not add a pattern recognizer that merely recognizes the current 32-slot expansion and replaces it with a loop.

Do not make the recovery pass more elaborate in order to emulate a missing loop IR.

Do not make full unrolling the default representation. A target-specific optimization may choose to unroll only after preserving the loop and proving the choice useful.

## Migration order

1. Move structured conditional representation into the checked IR and lower cases directly to it.
2. Stop relying on post-hoc conditional recovery for source cases; retain recovery temporarily only for legacy linear `RSelect` producers.
3. Add typed bounded-loop IR and direct lowering for the admitted first-order bounded-iteration source shape.
4. Rewrite the Analytic Continuation candidate to use that source shape once.
5. Make compact-loop code shape part of the regression suite.
6. Remove the manual 32+32 candidate from the active path after semantic and device receipts are green.
