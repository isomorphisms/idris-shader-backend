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

||| The source expresses factor accumulation once. The shader backend accepts
||| this deliberately narrow tail-iteration shape only after proving the 64
||| element compile-time maximum and the runtime active bound.
covering
factor_sum_from :
  SVec 2 -> Double -> SArray 64 (SVec 2) -> Double -> SVec 2 -> SVec 2
factor_sum_from point count factors index state =
  if index < minF count 64.0
     then
       let factor = array_at factors index
           contribution = factor_measure point factor
           next = vadd state contribution
        in factor_sum_from point count factors (index + 1.0) next
     else state

covering
factor_sum_64 : SVec 2 -> Double -> SArray 64 (SVec 2) -> SVec 2
factor_sum_64 point count factors =
  factor_sum_from point count factors 0.0 (vec2 0.0 0.0)

covering
rational_measure :
  SVec 2 -> Double -> SArray 64 (SVec 2) ->
  Double -> SArray 64 (SVec 2) -> SVec 2
rational_measure point zero_count zeros pole_count poles =
  let zero_measure = factor_sum_64 point zero_count zeros
      pole_measure = factor_sum_64 point pole_count poles
   in vsub zero_measure pole_measure

covering
public export
wegert_rgb :
  SVec 2 -> Double -> SArray 64 (SVec 2) ->
  Double -> SArray 64 (SVec 2) -> SVec 3
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
