module Example.GivensRotate2ToE1

import Shader.Source

%default total

||| Construct and apply one proper Givens plane rotation.
|||
||| For a nonzero pair (a,b), let r = sqrt(a*a + b*b), c = a/r,
||| and s = b/r.  The matrix [[c,s],[-s,c]] has determinant +1 and
||| sends (a,b) to (r,0).
|||
||| The fragment result is (axis ratio, residual, norm error, 1), so
||| (1,0,0,1) is the successful result.  The zero vector takes a finite
||| identity result rather than dividing by zero.
%export "glsles:fragment|u_pair=uniform"
givens_rotate2_to_e1 : SVec 2 -> SVec 4
givens_rotate2_to_e1 pair =
  let a = x pair
      b = y pair
      original_norm = sqrtF (a * a + b * b)
      safe_norm = maxF 0.000001 original_norm
      c = a / safe_norm
      s = b / safe_norm
      rotated_x = c * a + s * b
      rotated_y = (0.0 - s) * a + c * b
      rotated_norm = sqrtF (rotated_x * rotated_x + rotated_y * rotated_y)
      axis_ratio = rotated_x / safe_norm
      residual = absF rotated_y
      norm_error = absF (rotated_norm - original_norm)
   in if original_norm > 0.000001
         then vec4 axis_ratio residual norm_error 1.0
         else vec4 1.0 0.0 0.0 1.0

main : IO ()
main = pure ()
