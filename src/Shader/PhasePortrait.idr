module Shader.PhasePortrait

import Shader.Source

%default total

positive_fract : Double -> Double
positive_fract value = value - floorF value

srgb_component : Double -> Double
srgb_component linear_value =
  let value = maxF linear_value 0.0
   in if value <= 0.0031308
         then 12.92 * value
         else 1.055 * powF value (1.0 / 2.4) - 0.055

hcl_to_srgb : Double -> Double -> Double -> SVec 3
hcl_to_srgb hue_degrees chroma lightness =
  let hue = hue_degrees * 3.14159265358979323846 / 180.0
      u_star = chroma * cosF hue
      v_star = chroma * sinF hue
      white_u_prime = 0.19783982482140777
      white_v_prime = 0.46833630293240974
      cie_y =
        if lightness > 8.0
           then powF ((lightness + 16.0) / 116.0) 3.0
           else lightness / 903.2962962962963
      u_prime = u_star / (13.0 * lightness) + white_u_prime
      v_prime = v_star / (13.0 * lightness) + white_v_prime
      cie_x = (9.0 * cie_y * u_prime) / (4.0 * v_prime)
      cie_z = cie_y * (12.0 - 3.0 * u_prime - 20.0 * v_prime) / (4.0 * v_prime)
      linear_r = 3.2404542 * cie_x - 1.5371385 * cie_y - 0.4985314 * cie_z
      linear_g = -0.9692660 * cie_x + 1.8760108 * cie_y + 0.0415560 * cie_z
      linear_b = 0.0556434 * cie_x - 0.2040259 * cie_y + 1.0572252 * cie_z
      red = clampF (srgb_component linear_r) 0.0 1.0
      green = clampF (srgb_component linear_g) 0.0 1.0
      blue = clampF (srgb_component linear_b) 0.0 1.0
   in vec3 red green blue

factor_measure : SVec 2 -> SVec 2 -> SVec 2
factor_measure point factor =
  let delta = vsub point factor
      phase = atan2F (y delta) (x delta)
      log_modulus = logF (maxF (length delta) 0.000000000001)
   in vec2 phase log_modulus

active_factor_measure : SVec 2 -> Double -> SArray 64 (SVec 2) -> Double -> SVec 2
active_factor_measure point count factors index =
  if index < count
     then factor_measure point (array_at factors index)
     else vec2 0.0 0.0

factor_sum_64 : SVec 2 -> Double -> SArray 64 (SVec 2) -> SVec 2
factor_sum_64 point count factors =
  let sum_0 = active_factor_measure point count factors 0.0
      sum_1 = vadd sum_0 (active_factor_measure point count factors 1.0)
      sum_2 = vadd sum_1 (active_factor_measure point count factors 2.0)
      sum_3 = vadd sum_2 (active_factor_measure point count factors 3.0)
      sum_4 = vadd sum_3 (active_factor_measure point count factors 4.0)
      sum_5 = vadd sum_4 (active_factor_measure point count factors 5.0)
      sum_6 = vadd sum_5 (active_factor_measure point count factors 6.0)
      sum_7 = vadd sum_6 (active_factor_measure point count factors 7.0)
      sum_8 = vadd sum_7 (active_factor_measure point count factors 8.0)
      sum_9 = vadd sum_8 (active_factor_measure point count factors 9.0)
      sum_10 = vadd sum_9 (active_factor_measure point count factors 10.0)
      sum_11 = vadd sum_10 (active_factor_measure point count factors 11.0)
      sum_12 = vadd sum_11 (active_factor_measure point count factors 12.0)
      sum_13 = vadd sum_12 (active_factor_measure point count factors 13.0)
      sum_14 = vadd sum_13 (active_factor_measure point count factors 14.0)
      sum_15 = vadd sum_14 (active_factor_measure point count factors 15.0)
      sum_16 = vadd sum_15 (active_factor_measure point count factors 16.0)
      sum_17 = vadd sum_16 (active_factor_measure point count factors 17.0)
      sum_18 = vadd sum_17 (active_factor_measure point count factors 18.0)
      sum_19 = vadd sum_18 (active_factor_measure point count factors 19.0)
      sum_20 = vadd sum_19 (active_factor_measure point count factors 20.0)
      sum_21 = vadd sum_20 (active_factor_measure point count factors 21.0)
      sum_22 = vadd sum_21 (active_factor_measure point count factors 22.0)
      sum_23 = vadd sum_22 (active_factor_measure point count factors 23.0)
      sum_24 = vadd sum_23 (active_factor_measure point count factors 24.0)
      sum_25 = vadd sum_24 (active_factor_measure point count factors 25.0)
      sum_26 = vadd sum_25 (active_factor_measure point count factors 26.0)
      sum_27 = vadd sum_26 (active_factor_measure point count factors 27.0)
      sum_28 = vadd sum_27 (active_factor_measure point count factors 28.0)
      sum_29 = vadd sum_28 (active_factor_measure point count factors 29.0)
      sum_30 = vadd sum_29 (active_factor_measure point count factors 30.0)
      sum_31 = vadd sum_30 (active_factor_measure point count factors 31.0)
      sum_32 = vadd sum_31 (active_factor_measure point count factors 32.0)
      sum_33 = vadd sum_32 (active_factor_measure point count factors 33.0)
      sum_34 = vadd sum_33 (active_factor_measure point count factors 34.0)
      sum_35 = vadd sum_34 (active_factor_measure point count factors 35.0)
      sum_36 = vadd sum_35 (active_factor_measure point count factors 36.0)
      sum_37 = vadd sum_36 (active_factor_measure point count factors 37.0)
      sum_38 = vadd sum_37 (active_factor_measure point count factors 38.0)
      sum_39 = vadd sum_38 (active_factor_measure point count factors 39.0)
      sum_40 = vadd sum_39 (active_factor_measure point count factors 40.0)
      sum_41 = vadd sum_40 (active_factor_measure point count factors 41.0)
      sum_42 = vadd sum_41 (active_factor_measure point count factors 42.0)
      sum_43 = vadd sum_42 (active_factor_measure point count factors 43.0)
      sum_44 = vadd sum_43 (active_factor_measure point count factors 44.0)
      sum_45 = vadd sum_44 (active_factor_measure point count factors 45.0)
      sum_46 = vadd sum_45 (active_factor_measure point count factors 46.0)
      sum_47 = vadd sum_46 (active_factor_measure point count factors 47.0)
      sum_48 = vadd sum_47 (active_factor_measure point count factors 48.0)
      sum_49 = vadd sum_48 (active_factor_measure point count factors 49.0)
      sum_50 = vadd sum_49 (active_factor_measure point count factors 50.0)
      sum_51 = vadd sum_50 (active_factor_measure point count factors 51.0)
      sum_52 = vadd sum_51 (active_factor_measure point count factors 52.0)
      sum_53 = vadd sum_52 (active_factor_measure point count factors 53.0)
      sum_54 = vadd sum_53 (active_factor_measure point count factors 54.0)
      sum_55 = vadd sum_54 (active_factor_measure point count factors 55.0)
      sum_56 = vadd sum_55 (active_factor_measure point count factors 56.0)
      sum_57 = vadd sum_56 (active_factor_measure point count factors 57.0)
      sum_58 = vadd sum_57 (active_factor_measure point count factors 58.0)
      sum_59 = vadd sum_58 (active_factor_measure point count factors 59.0)
      sum_60 = vadd sum_59 (active_factor_measure point count factors 60.0)
      sum_61 = vadd sum_60 (active_factor_measure point count factors 61.0)
      sum_62 = vadd sum_61 (active_factor_measure point count factors 62.0)
      sum_63 = vadd sum_62 (active_factor_measure point count factors 63.0)
   in sum_63

rational_measure : SVec 2 -> Double -> SArray 64 (SVec 2) -> Double -> SArray 64 (SVec 2) -> SVec 2
rational_measure point zero_count zeros pole_count poles =
  let zero_measure = factor_sum_64 point zero_count zeros
      pole_measure = factor_sum_64 point pole_count poles
   in vsub zero_measure pole_measure

public export
wegert_rgb : SVec 2 -> Double -> SArray 64 (SVec 2) -> Double -> SArray 64 (SVec 2) -> SVec 3
wegert_rgb point zero_count zeros pole_count poles =
  let measure = rational_measure point zero_count zeros pole_count poles
      phase = x measure
      log_modulus = y measure
      hue_degrees = 360.0 * positive_fract (phase / 6.28318530717958647692)
      log_modulus_band = positive_fract (log_modulus / 2.30258509299404568402)
      lightness = 66.0
                + 4.0 * log_modulus_band
                + 3.0 * positive_fract (hue_degrees / 100.0)
   in hcl_to_srgb hue_degrees 45.0 lightness
