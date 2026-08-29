module Example.DotVector4Covector4

import Shader.Source

%default total

||| Contract a four-component vector with a four-component covector. In the
||| current Euclidean-coordinate representation both arrive as GLSL vec4 values.
-- u_... = uniform values supplied for the draw and shared by the fragments.
-- SVec 4 = a shader vector with exactly four components.
-- dot vector covector = multiply matching components and add the four products.
-- vec4 result result result 1.0 = show the scalar result as grayscale RGB, alpha 1.
%export "glsles:fragment|u_vector=uniform,u_covector=uniform"
dot_vector4_covector4 : SVec 4 -> SVec 4 -> SVec 4
dot_vector4_covector4 vector covector =
  let result = dot vector covector
   in vec4 result result result 1.0

main : IO ()
main = pure ()
