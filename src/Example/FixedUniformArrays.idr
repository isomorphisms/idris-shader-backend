module Example.FixedUniformArrays

import Shader.Source

%default total

%export "glsles:fragment|v_ndc=in,u_count=uniform,u_points=uniform,u_weights=uniform"
fixed_uniform_arrays : SVec 2 -> Int -> SArray 4 (SVec 2) -> SArray 4 Double -> SVec 4
fixed_uniform_arrays point count points weights =
  let count_value = int_to_double count
      point_0 = array_at points 0.0
      point_1 = array_at points 1.0
      weight_0 = array_at weights 0.0
      weight_1 = array_at weights 1.0
      contribution_0 =
        if 0.0 < count_value
           then weight_0 * length (vsub point point_0)
           else 0.0
      contribution_1 =
        if 1.0 < count_value
           then weight_1 * length (vsub point point_1)
           else 0.0
      total = contribution_0 + contribution_1
   in vec4 total weight_0 weight_1 1.0

main : IO ()
main = pure ()
