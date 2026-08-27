module Example.SetBlock32x32RGB5239182

import Shader.Source

%default total

||| Fill every fragment in the submitted render block with RGB (52, 39, 182).
||| The native probe runs this over a 32x32 target, matching a typical PowerVR
||| render-tile dimension without claiming that tile size is a shader vector width.
%export "glsles:fragment|"
set_block_32x32_to_rgb_52_39_182 : SVec 4
set_block_32x32_to_rgb_52_39_182 =
  vec4 (52.0 / 255.0) (39.0 / 255.0) (182.0 / 255.0) 1.0

main : IO ()
main = pure ()
