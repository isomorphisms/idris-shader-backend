module Example.DotVector32Covector32

import Shader.Source

%default total

||| A 32-component Euclidean-coordinate vector/covector contraction.
||| Each mathematical 32-vector is stored as eight plain vec4 chunks: the
||| dimension is deliberately independent of GPU tile, task, or lane width.
-- SVec 4 = one four-component shader-vector chunk.
-- v0..v7 = the eight vector chunks; c0..c7 = the eight covector chunks.
-- dot v0 c0 = four matching multiplications followed by their sum.
-- p0..p7 = the eight partial dot products; adding them gives the 32D contraction.
-- vec4 result result result 1.0 = display the scalar result as grayscale RGB.
%export "glsles:fragment|u_v0=uniform,u_v1=uniform,u_v2=uniform,u_v3=uniform,u_v4=uniform,u_v5=uniform,u_v6=uniform,u_v7=uniform,u_c0=uniform,u_c1=uniform,u_c2=uniform,u_c3=uniform,u_c4=uniform,u_c5=uniform,u_c6=uniform,u_c7=uniform"
dot_vector32_covector32 :
  SVec 4 -> SVec 4 -> SVec 4 -> SVec 4 ->
  SVec 4 -> SVec 4 -> SVec 4 -> SVec 4 ->
  SVec 4 -> SVec 4 -> SVec 4 -> SVec 4 ->
  SVec 4 -> SVec 4 -> SVec 4 -> SVec 4 -> SVec 4
dot_vector32_covector32 v0 v1 v2 v3 v4 v5 v6 v7 c0 c1 c2 c3 c4 c5 c6 c7 =
  let p0 = dot v0 c0
      p1 = dot v1 c1
      p2 = dot v2 c2
      p3 = dot v3 c3
      p4 = dot v4 c4
      p5 = dot v5 c5
      p6 = dot v6 c6
      p7 = dot v7 c7
      result = p0 + p1 + p2 + p3 + p4 + p5 + p6 + p7
   in vec4 result result result 1.0

main : IO ()
main = pure ()
