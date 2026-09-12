module Example.ComplexProjectiveFollower

import Shader.ComplexProjectiveFollower
import Shader.Source

%default total

%export "glsles:fragment|v_ndc=in,u_projective_scale=uniform,u_projective_right_0=uniform,u_projective_right_1=uniform"
complex_projective_follower :
  SVec 2 -> SVec 2 -> SVec 2 -> SVec 2 -> SVec 4
complex_projective_follower ndc projective_scale projective_right_0 projective_right_1 =
  let point = ndc
      zero = complex_cartesian (-0.35) 0.2
      pole = complex_cartesian 0.4 (-0.25)
      q = complex_polynomial_quadratic
            (complex_cartesian 0.0 0.0)
            (complex_cartesian 0.125 0.0)
            (complex_cartesian 0.03125 0.0)
            point
      holomorphic_factor = complex_exp_degree7 q
      divisor = rational_one_zero_one_pole point zero pole
      field = complex_multiply divisor holomorphic_factor
      projective_error =
        projective_cp1_rescaling_error_squared
          projective_scale
          (complex_cartesian 1.0 0.0)
          (complex_cartesian 0.0 1.0)
          projective_right_0
          projective_right_1
      magnitude = sqrtF (complex_magnitude_squared field)
      observation_scale = 1.0 + magnitude
      red = clampF (0.5 + 0.5 * x field / observation_scale) 0.0 1.0
      green = clampF (0.5 + 0.5 * y field / observation_scale) 0.0 1.0
      blue = clampF (magnitude / observation_scale + minF projective_error 0.25)
                    0.0 1.0
   in vec4 red green blue 1.0

main : IO ()
main = pure ()
