module Example.StructuredBranch

import Shader.Source

%default total

%noinline
expensive_positive : Double -> Double
expensive_positive value =
  let squared = value * value
      shifted = squared + 1.0
      rooted = sqrtF shifted
      waved = sinF rooted
   in waved * waved

%export "glsles:fragment|v_x=in"
structured_branch : Double -> SVec 4
structured_branch v_x =
  let chosen = if v_x > 0.0 then expensive_positive v_x else 0.0
   in vec4 chosen chosen chosen 1.0

main : IO ()
main = pure ()
