module Example.SurferRootSearch

import Shader.PolynomialRay
import Shader.Source

%default total

%export "glsles:fragment|v_uv=in,u_coefficients=uniform,u_near=uniform,u_far=uniform"
surfer_root_search : SVec 2 -> SArray 8 Double -> Double -> Double -> SVec 4
surfer_root_search uv coefficients near far =
  let result = nearest_crossing_degree_7 coefficients near far
      found = x result
      root = y result
      span = maxF (absF (far - near)) 0.000001
      depth = clampF ((root - near) / span) 0.0 1.0
      horizontal = 0.5 + 0.5 * x uv
      red = if found > 0.5 then 0.15 + 0.75 * (1.0 - depth) else 0.02
      green = if found > 0.5 then 0.20 + 0.55 * horizontal else 0.025
      blue = if found > 0.5 then 0.30 + 0.60 * depth else 0.06
   in vec4 red green blue 1.0

main : IO ()
main = pure ()
