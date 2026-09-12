module Shader.ComplexProjectiveFollower

import Shader.Source

%default total

-- SVec 2 is the current shader lowering of one complex scalar.  It is not the
-- source-language definition of the mathematical complex numbers.
public export
complex_cartesian : Double -> Double -> SVec 2
complex_cartesian real imaginary = vec2 real imaginary

public export
complex_add : SVec 2 -> SVec 2 -> SVec 2
complex_add = vadd

public export
complex_subtract : SVec 2 -> SVec 2 -> SVec 2
complex_subtract = vsub

public export
complex_negate : SVec 2 -> SVec 2
complex_negate value = scale (-1.0) value

public export
complex_multiply : SVec 2 -> SVec 2 -> SVec 2
complex_multiply left right =
  vec2
    (x left * x right - y left * y right)
    (x left * y right + y left * x right)

public export
complex_conjugate : SVec 2 -> SVec 2
complex_conjugate value = vec2 (x value) (- y value)

public export
complex_magnitude_squared : SVec 2 -> Double
complex_magnitude_squared value = dot value value

-- The caller supplies a mathematically nonzero denominator.  The shader
-- representation itself does not manufacture a quotient proof or silently
-- choose exceptional semantics for division by zero.
public export
complex_divide_nonzero : SVec 2 -> SVec 2 -> SVec 2
complex_divide_nonzero numerator denominator =
  let denominator_squared = complex_magnitude_squared denominator
      real = (x numerator * x denominator + y numerator * y denominator)
             / denominator_squared
      imaginary = (y numerator * x denominator - x numerator * y denominator)
                  / denominator_squared
   in vec2 real imaginary

public export
complex_reciprocal_nonzero : SVec 2 -> SVec 2
complex_reciprocal_nonzero denominator =
  complex_divide_nonzero (vec2 1.0 0.0) denominator

public export
complex_square : SVec 2 -> SVec 2
complex_square value = complex_multiply value value

private
real_complex : Double -> SVec 2
real_complex value = vec2 value 0.0

-- The current shared executable corpus uses this bounded degree-7 polynomial
-- only for |z| <= 0.5.  Range reduction and a general exp implementation are
-- separate future work; this helper must not be treated as globally valid.
public export
complex_exp_degree7 : SVec 2 -> SVec 2
complex_exp_degree7 value =
  let degree_7 = real_complex (1.0 / 5040.0)
      degree_6 = complex_add (complex_multiply degree_7 value)
                             (real_complex (1.0 / 720.0))
      degree_5 = complex_add (complex_multiply degree_6 value)
                             (real_complex (1.0 / 120.0))
      degree_4 = complex_add (complex_multiply degree_5 value)
                             (real_complex (1.0 / 24.0))
      degree_3 = complex_add (complex_multiply degree_4 value)
                             (real_complex (1.0 / 6.0))
      degree_2 = complex_add (complex_multiply degree_3 value)
                             (real_complex 0.5)
      degree_1 = complex_add (complex_multiply degree_2 value)
                             (real_complex 1.0)
   in complex_add (complex_multiply degree_1 value)
                  (real_complex 1.0)

public export
complex_polynomial_quadratic :
  SVec 2 -> SVec 2 -> SVec 2 -> SVec 2 -> SVec 2
complex_polynomial_quadratic constant linear quadratic value =
  complex_add
    constant
    (complex_add
      (complex_multiply linear value)
      (complex_multiply quadratic (complex_square value)))

public export
rational_one_zero_one_pole : SVec 2 -> SVec 2 -> SVec 2 -> SVec 2
rational_one_zero_one_pole value zero pole =
  complex_divide_nonzero
    (complex_subtract value zero)
    (complex_subtract value pole)

-- For two homogeneous CP^1 representatives [z0:z1] and [w0:w1], the wedge
-- vanishes exactly when the representatives are complex-proportional.  This
-- is projectively invariant; raw component equality is not.
public export
projective_cp1_wedge : SVec 2 -> SVec 2 -> SVec 2 -> SVec 2 -> SVec 2
projective_cp1_wedge z0 z1 w0 w1 =
  complex_subtract
    (complex_multiply z0 w1)
    (complex_multiply z1 w0)

public export
projective_cp1_wedge_squared :
  SVec 2 -> SVec 2 -> SVec 2 -> SVec 2 -> Double
projective_cp1_wedge_squared z0 z1 w0 w1 =
  complex_magnitude_squared (projective_cp1_wedge z0 z1 w0 w1)

-- A concrete nonzero scale witness lets a follower test one representative
-- against another without defining an ordinary Eq instance for projective
-- points.
public export
projective_cp1_rescaling_error_squared :
  SVec 2 -> SVec 2 -> SVec 2 -> SVec 2 -> SVec 2 -> Double
projective_cp1_rescaling_error_squared scale_value z0 z1 w0 w1 =
  let error_0 = complex_subtract (complex_multiply scale_value z0) w0
      error_1 = complex_subtract (complex_multiply scale_value z1) w1
   in complex_magnitude_squared error_0 + complex_magnitude_squared error_1
