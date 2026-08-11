module Test.Backend.BadRecursion

import Shader.Source

%default partial

%noinline
loop : Double -> Double
loop value = loop (value + 1.0)

%export "glsles:fragment|v_uv=in"
badRecursion : SVec 2 -> SVec 4
badRecursion uv =
  let value = loop (x uv)
   in vec4 value value value 1.0

main : IO ()
main = pure ()
