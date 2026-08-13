module Shader.IR

import Data.List.Elem
import Shader.Types

%default total

||| A deliberately small, intrinsically typed expression language. There is no
||| constructor for an ill-typed operation such as adding a bool to a vec3.
public export
data Expr : List ShaderTy → ShaderTy → Type where
  FloatLit : Double → Expr context TFloat
  BoolLit  : Bool → Expr context TBool
  Var      : Elem ty context → Expr context ty

  Vec2 : Expr context TFloat → Expr context TFloat → Expr context TVec2
  Vec3 : Expr context TFloat → Expr context TFloat → Expr context TFloat →
         Expr context TVec3
  Vec4 : Expr context TFloat → Expr context TFloat → Expr context TFloat →
         Expr context TFloat → Expr context TVec4

  AddF : Expr context TFloat → Expr context TFloat → Expr context TFloat
  SubF : Expr context TFloat → Expr context TFloat → Expr context TFloat
  MulF : Expr context TFloat → Expr context TFloat → Expr context TFloat
  DivF : Expr context TFloat → Expr context TFloat → Expr context TFloat
  NegF : Expr context TFloat → Expr context TFloat
  AbsF : Expr context TFloat → Expr context TFloat
  SqrtF : Expr context TFloat → Expr context TFloat
  SinF : Expr context TFloat → Expr context TFloat
  CosF : Expr context TFloat → Expr context TFloat
  MinF : Expr context TFloat → Expr context TFloat → Expr context TFloat
  MaxF : Expr context TFloat → Expr context TFloat → Expr context TFloat
  ClampF : Expr context TFloat → Expr context TFloat → Expr context TFloat →
           Expr context TFloat
  MixF : Expr context TFloat → Expr context TFloat → Expr context TFloat →
         Expr context TFloat

  Add2 : Expr context TVec2 → Expr context TVec2 → Expr context TVec2
  Sub2 : Expr context TVec2 → Expr context TVec2 → Expr context TVec2
  Scale2 : Expr context TFloat → Expr context TVec2 → Expr context TVec2
  Dot2 : Expr context TVec2 → Expr context TVec2 → Expr context TFloat
  Length2 : Expr context TVec2 → Expr context TFloat
  Normalize2 : Expr context TVec2 → Expr context TVec2

  Add3 : Expr context TVec3 → Expr context TVec3 → Expr context TVec3
  Sub3 : Expr context TVec3 → Expr context TVec3 → Expr context TVec3
  Scale3 : Expr context TFloat → Expr context TVec3 → Expr context TVec3
  Dot3 : Expr context TVec3 → Expr context TVec3 → Expr context TFloat
  Length3 : Expr context TVec3 → Expr context TFloat
  Normalize3 : Expr context TVec3 → Expr context TVec3

  Add4 : Expr context TVec4 → Expr context TVec4 → Expr context TVec4
  Sub4 : Expr context TVec4 → Expr context TVec4 → Expr context TVec4
  Scale4 : Expr context TFloat → Expr context TVec4 → Expr context TVec4
  Dot4 : Expr context TVec4 → Expr context TVec4 → Expr context TFloat
  Length4 : Expr context TVec4 → Expr context TFloat
  Normalize4 : Expr context TVec4 → Expr context TVec4

  X2 : Expr context TVec2 → Expr context TFloat
  Y2 : Expr context TVec2 → Expr context TFloat
  X3 : Expr context TVec3 → Expr context TFloat
  Y3 : Expr context TVec3 → Expr context TFloat
  Z3 : Expr context TVec3 → Expr context TFloat
  X4 : Expr context TVec4 → Expr context TFloat
  Y4 : Expr context TVec4 → Expr context TFloat
  Z4 : Expr context TVec4 → Expr context TFloat
  W4 : Expr context TVec4 → Expr context TFloat

  LtF : Expr context TFloat → Expr context TFloat → Expr context TBool
  LeF : Expr context TFloat → Expr context TFloat → Expr context TBool
  EqF : Expr context TFloat → Expr context TFloat → Expr context TBool
  GeF : Expr context TFloat → Expr context TFloat → Expr context TBool
  GtF : Expr context TFloat → Expr context TFloat → Expr context TBool
  AndB : Expr context TBool → Expr context TBool → Expr context TBool
  OrB  : Expr context TBool → Expr context TBool → Expr context TBool
  NotB : Expr context TBool → Expr context TBool
  Select : Expr context TBool → Expr context ty → Expr context ty →
           Expr context ty

||| Integer powers are represented by multiplication in the IR. That avoids
||| GLSL's less useful semantics for pow(x, n) when x may be negative.
public export
powNat : Expr context TFloat → Nat → Expr context TFloat
powNat _ Z = FloatLit 1.0
powNat x (S Z) = x
powNat x (S k) = MulF x (powNat x k)
