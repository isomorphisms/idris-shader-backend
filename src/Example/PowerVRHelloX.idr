module Example.PowerVRHelloX

import Shader.Source

%default total

||| The GPU analogue of `print "X"`: shade two diagonal strips white and the
||| rest black. `v_ndc` ranges over the visible square from -1 to +1.
%export "glsles:fragment|v_ndc=in"
power_vr_hello_x : SVec 2 -> SVec 4
power_vr_hello_x ndc =
  let diagonal = minF (absF (x ndc - y ndc)) (absF (x ndc + y ndc))
      ink = if diagonal < 0.12 then 1.0 else 0.0
   in vec4 ink ink ink 1.0

main : IO ()
main = pure ()
