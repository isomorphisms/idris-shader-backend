# Arithmetic and transcendental operations

MSL provides ordinary scalar/vector arithmetic plus mathematical built-ins. The renderer's portable core should express operations such as add/subtract/multiply/divide, `atan2`, `log`, `pow`, `sqrt`, `sin`, `cos`, `floor`, `fract`, `clamp`, `mix`, `smoothstep`, dot/length/normalize and FMA semantically.

Apple-family specialization should normally choose precision or cooperative evaluation, not change these mathematical meanings. `half` versus `float` is a target policy; Float32 remains the correctness-oriented ordinary lane.
