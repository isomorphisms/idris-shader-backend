module Example.DotVector32Covector32

import Shader.Source

%default total

||| A 32-component Euclidean-coordinate vector/covector contraction.
||| Each mathematical 32-vector is stored as eight vec4 chunks: the dimension
||| is deliberately independent of GPU tile, task, or lane width.
%export "glsles:fragment|u_vector=uniform,u_covector=uniform"
dot_vector32_covector32 : SArray 8 (SVec 4) -> SArray 8 (SVec 4) -> SVec 4
dot_vector32_covector32 vector covector =
  let v0 = array_at vector 0.0
      v1 = array_at vector 1.0
      v2 = array_at vector 2.0
      v3 = array_at vector 3.0
      v4 = array_at vector 4.0
      v5 = array_at vector 5.0
      v6 = array_at vector 6.0
      v7 = array_at vector 7.0
      c0 = array_at covector 0.0
      c1 = array_at covector 1.0
      c2 = array_at covector 2.0
      c3 = array_at covector 3.0
      c4 = array_at covector 4.0
      c5 = array_at covector 5.0
      c6 = array_at covector 6.0
      c7 = array_at covector 7.0
      p0 = dot v0 c0
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
