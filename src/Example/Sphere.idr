module Example.Sphere

import Data.List.Elem
import Shader.Types
import Shader.IR
import Shader.Polynomial
import Shader.GLSLES

%default total

public export
SphereContext : List ShaderTy
SphereContext = [TVec2, TFloat]

public export
sphereSchema : Schema SphereContext
sphereSchema =
  Declare TVec2 FragmentInput "v_uv" $
  Declare TFloat Uniform "u_time" $
  Empty

public export
spherePolynomial : Polynomial
spherePolynomial =
  [ MkMonomial  1.0 2 0 0
  , MkMonomial  1.0 0 2 0
  , MkMonomial  1.0 0 0 2
  , MkMonomial (-1.0) 0 0 0
  ]

vUV : Expr SphereContext TVec2
vUV = Var Here

time : Expr SphereContext TFloat
time = Var (There Here)

slicePoint : Expr SphereContext TVec3
slicePoint =
  Vec3 (MulF (FloatLit 1.35) (X2 vUV))
       (MulF (FloatLit 1.35) (Y2 vUV))
       (MulF (FloatLit 0.35) (SinF time))

field : Expr SphereContext TFloat
field = polynomialExpr spherePolynomial slicePoint

gradient : Expr SphereContext TVec3
gradient = gradientExpr spherePolynomial slicePoint

normal : Expr SphereContext TVec3
normal = Scale3
           (DivF (FloatLit 1.0) (MaxF (FloatLit 0.00001) (Length3 gradient)))
           gradient

lightDirection : Expr SphereContext TVec3
lightDirection = Normalize3 (Vec3 (FloatLit 0.35) (FloatLit 0.55) (FloatLit 1.0))

diffuse : Expr SphereContext TFloat
diffuse = MaxF (FloatLit 0.0) (Dot3 normal lightDirection)

band : Expr SphereContext TFloat
band = ClampF
         (DivF (SubF (FloatLit 0.075) (AbsF field)) (FloatLit 0.075))
         (FloatLit 0.0)
         (FloatLit 1.0)

pulse : Expr SphereContext TFloat
pulse = AddF (FloatLit 0.88) (MulF (FloatLit 0.12) (SinF time))

shade : Expr SphereContext TFloat
shade = MulF pulse (AddF (FloatLit 0.25) (MulF (FloatLit 0.75) diffuse))

sphereColor : Expr SphereContext TVec4
sphereColor =
  Vec4 (MixF (FloatLit 0.015) (MulF (FloatLit 0.95) shade) band)
       (MixF (FloatLit 0.025) (MulF (FloatLit 0.72) shade) band)
       (MixF (FloatLit 0.060) (MulF (FloatLit 0.18) shade) band)
       (FloatLit 1.0)

public export
sphereShader : FragmentShader SphereContext
sphereShader = MkFragmentShader sphereSchema sphereColor

public export
sphereFragment : Either String String
sphereFragment = compileFragment sphereShader
