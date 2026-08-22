module Shader.PolynomialRay

import Shader.Source

%default total

||| Evaluate a degree-at-most-seven polynomial whose coefficients are stored
||| from constant term through seventh power. Higher unused terms are zero.
public export
evaluate_degree_7 : SArray 8 Double -> Double -> Double
evaluate_degree_7 coefficients value =
  let coefficient_7 = array_at coefficients 7.0
      coefficient_6 = array_at coefficients 6.0
      coefficient_5 = array_at coefficients 5.0
      coefficient_4 = array_at coefficients 4.0
      coefficient_3 = array_at coefficients 3.0
      coefficient_2 = array_at coefficients 2.0
      coefficient_1 = array_at coefficients 1.0
      coefficient_0 = array_at coefficients 0.0
      accumulated_6 = coefficient_7 * value + coefficient_6
      accumulated_5 = accumulated_6 * value + coefficient_5
      accumulated_4 = accumulated_5 * value + coefficient_4
      accumulated_3 = accumulated_4 * value + coefficient_3
      accumulated_2 = accumulated_3 * value + coefficient_2
      accumulated_1 = accumulated_2 * value + coefficient_1
   in accumulated_1 * value + coefficient_0

bracket_step : SArray 8 Double -> Double -> Double -> SVec 3 -> Double -> SVec 3
bracket_step coefficients near interval_width state index =
  let found = x state
      left_value = near + (index - 1.0) * interval_width
      right_value = near + index * interval_width
      left_polynomial = evaluate_degree_7 coefficients left_value
      right_polynomial = evaluate_degree_7 coefficients right_value
      crosses = left_polynomial * right_polynomial <= 0.0
      candidate = vec3 1.0 left_value right_value
   in if found > 0.5
         then state
         else if crosses then candidate else state

bracket_16 : SArray 8 Double -> Double -> Double -> SVec 3
bracket_16 coefficients near far =
  let interval_width = (far - near) / 16.0
      state_0 = bracket_step coefficients near interval_width (vec3 0.0 near near) 1.0
      state_1 = bracket_step coefficients near interval_width state_0 2.0
      state_2 = bracket_step coefficients near interval_width state_1 3.0
      state_3 = bracket_step coefficients near interval_width state_2 4.0
      state_4 = bracket_step coefficients near interval_width state_3 5.0
      state_5 = bracket_step coefficients near interval_width state_4 6.0
      state_6 = bracket_step coefficients near interval_width state_5 7.0
      state_7 = bracket_step coefficients near interval_width state_6 8.0
      state_8 = bracket_step coefficients near interval_width state_7 9.0
      state_9 = bracket_step coefficients near interval_width state_8 10.0
      state_10 = bracket_step coefficients near interval_width state_9 11.0
      state_11 = bracket_step coefficients near interval_width state_10 12.0
      state_12 = bracket_step coefficients near interval_width state_11 13.0
      state_13 = bracket_step coefficients near interval_width state_12 14.0
      state_14 = bracket_step coefficients near interval_width state_13 15.0
      state_15 = bracket_step coefficients near interval_width state_14 16.0
   in state_15

bisect_step : SArray 8 Double -> SVec 2 -> SVec 2
bisect_step coefficients interval =
  let low = x interval
      high = y interval
      middle = 0.5 * (low + high)
      low_polynomial = evaluate_degree_7 coefficients low
      middle_polynomial = evaluate_degree_7 coefficients middle
   in if low_polynomial * middle_polynomial <= 0.0
         then vec2 low middle
         else vec2 middle high

bisect_20 : SArray 8 Double -> SVec 2 -> SVec 2
bisect_20 coefficients interval =
  let state_0 = bisect_step coefficients interval
      state_1 = bisect_step coefficients state_0
      state_2 = bisect_step coefficients state_1
      state_3 = bisect_step coefficients state_2
      state_4 = bisect_step coefficients state_3
      state_5 = bisect_step coefficients state_4
      state_6 = bisect_step coefficients state_5
      state_7 = bisect_step coefficients state_6
      state_8 = bisect_step coefficients state_7
      state_9 = bisect_step coefficients state_8
      state_10 = bisect_step coefficients state_9
      state_11 = bisect_step coefficients state_10
      state_12 = bisect_step coefficients state_11
      state_13 = bisect_step coefficients state_12
      state_14 = bisect_step coefficients state_13
      state_15 = bisect_step coefficients state_14
      state_16 = bisect_step coefficients state_15
      state_17 = bisect_step coefficients state_16
      state_18 = bisect_step coefficients state_17
      state_19 = bisect_step coefficients state_18
   in state_19

||| Return `(found, nearest_crossing)` for the first sampled sign-changing
||| interval. This is a bounded GPU-compatible search primitive, not a claim
||| that sign-change sampling alone finds every real polynomial root.
public export
nearest_crossing_degree_7 : SArray 8 Double -> Double -> Double -> SVec 2
nearest_crossing_degree_7 coefficients near far =
  let bracket = bracket_16 coefficients near far
      found = x bracket
      refined = bisect_20 coefficients (vec2 (y bracket) (z bracket))
      root = if found > 0.5 then 0.5 * (x refined + y refined) else far
   in vec2 found root
