module Example.DotVector32Covector32

import Shader.Source

%default total

||| A 32-component Euclidean-coordinate vector/covector contraction.
||| The mathematical length 32 is deliberately independent of GPU lane/task width.
%export "glsles:fragment|u_vector=uniform,u_covector=uniform"
dot_vector32_covector32 : SArray 32 Double -> SArray 32 Double -> SVec 4
dot_vector32_covector32 vector covector =
  let p0 = array_at vector 0.0 * array_at covector 0.0
      p1 = array_at vector 1.0 * array_at covector 1.0
      p2 = array_at vector 2.0 * array_at covector 2.0
      p3 = array_at vector 3.0 * array_at covector 3.0
      p4 = array_at vector 4.0 * array_at covector 4.0
      p5 = array_at vector 5.0 * array_at covector 5.0
      p6 = array_at vector 6.0 * array_at covector 6.0
      p7 = array_at vector 7.0 * array_at covector 7.0
      p8 = array_at vector 8.0 * array_at covector 8.0
      p9 = array_at vector 9.0 * array_at covector 9.0
      p10 = array_at vector 10.0 * array_at covector 10.0
      p11 = array_at vector 11.0 * array_at covector 11.0
      p12 = array_at vector 12.0 * array_at covector 12.0
      p13 = array_at vector 13.0 * array_at covector 13.0
      p14 = array_at vector 14.0 * array_at covector 14.0
      p15 = array_at vector 15.0 * array_at covector 15.0
      p16 = array_at vector 16.0 * array_at covector 16.0
      p17 = array_at vector 17.0 * array_at covector 17.0
      p18 = array_at vector 18.0 * array_at covector 18.0
      p19 = array_at vector 19.0 * array_at covector 19.0
      p20 = array_at vector 20.0 * array_at covector 20.0
      p21 = array_at vector 21.0 * array_at covector 21.0
      p22 = array_at vector 22.0 * array_at covector 22.0
      p23 = array_at vector 23.0 * array_at covector 23.0
      p24 = array_at vector 24.0 * array_at covector 24.0
      p25 = array_at vector 25.0 * array_at covector 25.0
      p26 = array_at vector 26.0 * array_at covector 26.0
      p27 = array_at vector 27.0 * array_at covector 27.0
      p28 = array_at vector 28.0 * array_at covector 28.0
      p29 = array_at vector 29.0 * array_at covector 29.0
      p30 = array_at vector 30.0 * array_at covector 30.0
      p31 = array_at vector 31.0 * array_at covector 31.0
      result = p0 + p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9 + p10 + p11 + p12 + p13 + p14 + p15 + p16 + p17 + p18 + p19 + p20 + p21 + p22 + p23 + p24 + p25 + p26 + p27 + p28 + p29 + p30 + p31
   in vec4 result result result 1.0

main : IO ()
main = pure ()
