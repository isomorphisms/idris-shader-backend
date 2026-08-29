module Example.RotateDifference8ToE1

import Shader.Source

%default total

||| Subtract two 8D vectors (stored as two vec4 chunks), then map the
||| difference to ||a-b|| e1 with an orientation-preserving orthogonal map.
|||
||| For a non-degenerate difference, the first Householder reflection sends
||| d to ||d||e1.  A fixed reflection that flips e2 leaves ||d||e1 unchanged;
||| composing the two reflections has determinant +1, so the composition is a
||| proper high-dimensional rotation.  If d is already on +e1, use identity.
%export "glsles:fragment|u_a0=uniform,u_a1=uniform,u_b0=uniform,u_b1=uniform"
rotate_difference8_to_e1 :
  SVec 4 -> SVec 4 -> SVec 4 -> SVec 4 -> SVec 4
rotate_difference8_to_e1 a0 a1 b0 b1 =
  let d0 = vsub a0 b0
      d1 = vsub a1 b1
      original_norm = sqrtF (dot d0 d0 + dot d1 d1)
      target0 = vec4 original_norm 0.0 0.0 0.0
      u0_raw = vsub d0 target0
      u1_raw = d1
      u_norm = sqrtF (dot u0_raw u0_raw + dot u1_raw u1_raw)
      inverse_u_norm = 1.0 / maxF 0.000001 u_norm
      u0 = scale inverse_u_norm u0_raw
      u1 = scale inverse_u_norm u1_raw
      projection = dot d0 u0 + dot d1 u1
      twice_projection = 2.0 * projection
      reflected0 = vsub d0 (scale twice_projection u0)
      reflected1 = vsub d1 (scale twice_projection u1)
      rotated0 =
        if u_norm > 0.000001
           then vec4 (x reflected0) (0.0 - y reflected0) (z reflected0) (w reflected0)
           else reflected0
      tail0 = vec3 (y rotated0) (z rotated0) (w rotated0)
      residual = sqrtF (dot tail0 tail0 + dot reflected1 reflected1)
      axis_ratio = x rotated0 / maxF 0.000001 original_norm
   in vec4 axis_ratio residual residual 1.0

main : IO ()
main = pure ()
