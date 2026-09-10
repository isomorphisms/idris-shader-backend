module Example.BoundedLoopProbe

import Shader.Source

%default covering

sum_until : Double -> Double -> Double -> Double
sum_until active index state =
  if index < minF active 4.0
     then sum_until active (index + 1.0) (state + index)
     else state

%export "glsles:fragment|u_active=uniform"
bounded_loop_probe : Double -> SVec 4
bounded_loop_probe active =
  let accumulated = sum_until active 0.0 0.0
   in vec4 accumulated accumulated accumulated 1.0

main : IO ()
main = pure ()
