module Example.MaliMockSmoke

import Shader.Source

%default total

%export "mali-mock:fragment|v_uv=in,u_time=uniform"
maliMockSmoke : SVec 2 -> Double -> SVec 4
maliMockSmoke uv time =
  let direction = normalize (vec2 0.6 0.8)
      projection = dot uv direction
      positive = if projection > 0.0 then projection else 0.0
      pulse = 0.5 + 0.5 * sinF time
   in vec4 (positive * pulse) (x uv) (y uv) 1.0

main : IO ()
main = pure ()
