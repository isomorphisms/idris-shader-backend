module Example.SubtractVector8Norm

import Shader.Source

%default total

||| Subtract two 8D vectors represented as two vec4 chunks and reduce the
||| eight-component difference to its Euclidean norm.
-- SVec 4 = one four-component shader-vector chunk.
-- vsub a b = vector subtraction, component by component.
-- dot d d = sum of the squared components of d.
-- sqrtF = floating-point square root; here it turns squared norm into Euclidean norm.
-- vec4 result result result 1.0 = display the scalar norm as grayscale RGB.
%export "glsles:fragment|u_a0=uniform,u_a1=uniform,u_b0=uniform,u_b1=uniform"
subtract_vector8_norm :
  SVec 4 -> SVec 4 -> SVec 4 -> SVec 4 -> SVec 4
subtract_vector8_norm a0 a1 b0 b1 =
  let d0 = vsub a0 b0
      d1 = vsub a1 b1
      norm_squared = dot d0 d0 + dot d1 d1
      result = sqrtF norm_squared
   in vec4 result result result 1.0

main : IO ()
main = pure ()
