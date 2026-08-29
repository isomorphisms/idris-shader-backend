module Example.SetPixel3RGB5239182

import Shader.Source

%default total

||| On a four-pixel-wide framebuffer, set zero-based pixel 3 (the fourth
||| pixel) to RGB (52, 39, 182) and leave the other three pixels black.
-- glsles = GLSL ES; fragment = the per-fragment/pixel shader stage.
-- v_ndc = normalized device coordinates supplied as an input to this fragment.
-- SVec n = shader vector with exactly n components; Idris checks the width.
-- x ndc = the first (horizontal) coordinate of that two-component vector.
-- vec4 r g b a = make the four-component red/green/blue/alpha result vector.
%export "glsles:fragment|v_ndc=in"
set_pixel_3_to_rgb_52_39_182 : SVec 2 -> SVec 4
set_pixel_3_to_rgb_52_39_182 ndc =
  let selected = x ndc > 0.5
      red = if selected then 52.0 / 255.0 else 0.0
      green = if selected then 39.0 / 255.0 else 0.0
      blue = if selected then 182.0 / 255.0 else 0.0
   in vec4 red green blue 1.0

main : IO ()
main = pure ()
