module Example.RotateDifference8ToE1

import Shader.Source

%default total

||| Subtract two 8D vectors (stored as two vec4 chunks), then apply seven
||| ordinary Givens plane rotations. The resulting direction is ||a-b|| e1:
||| all coordinates except the first should be numerically near zero.
-- SVec 4 = one four-component shader-vector chunk.
-- vsub a b = componentwise vector subtraction.
-- x/y/z/w = first/second/third/fourth components of a vec4 chunk.
-- q0..q7 = the eight scalar coordinates of the difference vector.
-- sqrtF = floating-point square root.
-- maxF a b = floating-point maximum; here it prevents division by a tiny radius.
-- c1..c7 and s1..s7 = cosine-like and sine-like coefficients of the Givens rotations.
-- z1..z7 = coordinates each rotation is trying to drive to zero.
-- absF = floating-point absolute value; residual measures how far from zero those coordinates remain.
-- vec4 axis_ratio residual residual 1.0 = pack the two diagnostics into RGBA output.
%export "glsles:fragment|u_a0=uniform,u_a1=uniform,u_b0=uniform,u_b1=uniform"
rotate_difference8_to_e1 :
  SVec 4 -> SVec 4 -> SVec 4 -> SVec 4 -> SVec 4
rotate_difference8_to_e1 a0 a1 b0 b1 =
  let d0 = vsub a0 b0
      d1 = vsub a1 b1
      q0 = x d0
      q1 = y d0
      q2 = z d0
      q3 = w d0
      q4 = x d1
      q5 = y d1
      q6 = z d1
      q7 = w d1
      r1 = sqrtF (q0 * q0 + q1 * q1)
      h1 = maxF 0.000001 r1
      c1 = q0 / h1
      s1 = q1 / h1
      x1 = c1 * q0 + s1 * q1
      z1 = (0.0 - s1) * q0 + c1 * q1
      r2 = sqrtF (x1 * x1 + q2 * q2)
      h2 = maxF 0.000001 r2
      c2 = x1 / h2
      s2 = q2 / h2
      x2 = c2 * x1 + s2 * q2
      z2 = (0.0 - s2) * x1 + c2 * q2
      r3 = sqrtF (x2 * x2 + q3 * q3)
      h3 = maxF 0.000001 r3
      c3 = x2 / h3
      s3 = q3 / h3
      x3 = c3 * x2 + s3 * q3
      z3 = (0.0 - s3) * x2 + c3 * q3
      r4 = sqrtF (x3 * x3 + q4 * q4)
      h4 = maxF 0.000001 r4
      c4 = x3 / h4
      s4 = q4 / h4
      x4 = c4 * x3 + s4 * q4
      z4 = (0.0 - s4) * x3 + c4 * q4
      r5 = sqrtF (x4 * x4 + q5 * q5)
      h5 = maxF 0.000001 r5
      c5 = x4 / h5
      s5 = q5 / h5
      x5 = c5 * x4 + s5 * q5
      z5 = (0.0 - s5) * x4 + c5 * q5
      r6 = sqrtF (x5 * x5 + q6 * q6)
      h6 = maxF 0.000001 r6
      c6 = x5 / h6
      s6 = q6 / h6
      x6 = c6 * x5 + s6 * q6
      z6 = (0.0 - s6) * x5 + c6 * q6
      r7 = sqrtF (x6 * x6 + q7 * q7)
      h7 = maxF 0.000001 r7
      c7 = x6 / h7
      s7 = q7 / h7
      x7 = c7 * x6 + s7 * q7
      z7 = (0.0 - s7) * x6 + c7 * q7
      original_norm = sqrtF
        (q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3 +
         q4 * q4 + q5 * q5 + q6 * q6 + q7 * q7)
      axis_ratio = x7 / maxF 0.000001 original_norm
      residual01 = maxF (absF z1) (absF z2)
      residual23 = maxF (absF z3) (absF z4)
      residual45 = maxF (absF z5) (absF z6)
      residual = maxF (maxF residual01 residual23) (maxF residual45 (absF z7))
   in vec4 axis_ratio residual residual 1.0

main : IO ()
main = pure ()
