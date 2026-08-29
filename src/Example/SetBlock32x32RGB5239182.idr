module Example.SetBlock32x32RGB5239182

import Shader.Source

%default total

||| Fill every fragment in the submitted render block with RGB (52, 39, 182).
||| The native probe runs this over a 32x32 target, matching a typical PowerVR
||| render-tile dimension without claiming that tile size is a shader vector width.
||| The zero-times-coordinate term keeps this a one-argument shader function at
||| the current backend boundary while leaving the requested colour unchanged.
-- v_ndc / ndc = normalized device coordinates for the current fragment.
-- SVec n = shader vector with exactly n components.
-- x ndc = first/horizontal coordinate. Multiplying it by 0.0 makes `zero` stay zero.
-- vec4 r g b a = construct the red/green/blue/alpha output vector.
%export "glsles:fragment|v_ndc=in"
set_block_32x32_to_rgb_52_39_182 : SVec 2 -> SVec 4
set_block_32x32_to_rgb_52_39_182 ndc =
  let zero = 0.0 * x ndc
   in vec4 (52.0 / 255.0 + zero)
           (39.0 / 255.0 + zero)
           (182.0 / 255.0 + zero)
           1.0

main : IO ()
main = pure ()
