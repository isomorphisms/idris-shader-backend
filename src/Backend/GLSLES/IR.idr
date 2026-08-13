module Backend.GLSLES.IR

import Data.Fin
import Decidable.Equality

%default total

||| Runtime value types admitted by the restricted shader compiler. Vector
||| width is data here, rather than three unrelated Vec2/Vec3/Vec4 cases.
public export
data ValueTy = TFloat | TBool | TVec Nat

public export
Eq ValueTy where
  TFloat == TFloat = True
  TBool == TBool = True
  TVec n == TVec m = n == m
  _ == _ = False

public export
DecEq ValueTy where
  decEq TFloat TFloat = Yes Refl
  decEq TFloat TBool = No (\Refl impossible)
  decEq TFloat (TVec _) = No (\Refl impossible)
  decEq TBool TFloat = No (\Refl impossible)
  decEq TBool TBool = Yes Refl
  decEq TBool (TVec _) = No (\Refl impossible)
  decEq (TVec _) TFloat = No (\Refl impossible)
  decEq (TVec _) TBool = No (\Refl impossible)
  decEq (TVec n) (TVec m) with (decEq n m)
    decEq (TVec n) (TVec n) | Yes Refl = Yes Refl
    decEq (TVec n) (TVec m) | No contra =
      No (\Refl ⇒ contra Refl)

public export
Show ValueTy where
  show TFloat = "float"
  show TBool = "bool"
  show (TVec n) = "vec" ++ show n

public export
data Storage = FragmentInput | Uniform

public export
Eq Storage where
  FragmentInput == FragmentInput = True
  Uniform == Uniform = True
  _ == _ = False

public export
record InterfaceVar where
  constructor MkInterfaceVar
  name : String
  storage : Storage
  valueTy : ValueTy

public export
record EntrySpec where
  constructor MkEntrySpec
  entryName : String
  entryInterface : List InterfaceVar
  resultTy : ValueTy

||| A typed operand in the backend's linear shader IR.
public export
data Operand : ValueTy → Type where
  OLocal : String → Operand ty
  OFloat : Double → Operand TFloat
  OBool : Bool → Operand TBool

public export
record SomeOperand where
  constructor PackOperand
  operandTy : ValueTy
  operand : Operand operandTy

public export
record SomeVector where
  constructor PackVector
  width : Nat
  vector : Operand (TVec width)

public export
data FloatUnary = FNeg | FAbs | FSqrt | FSin | FCos

public export
data FloatBinary = FAdd | FSub | FMul | FDiv | FMin | FMax

public export
data FloatTernary = FClamp | FMix

public export
data Comparison = FLt | FLe | FEq | FGe | FGt

public export
data BoolUnary = BNot

public export
data BoolBinary = BAnd | BOr

public export
data VectorBinary = VAdd | VSub

||| A right-hand side whose Idris index is its GLSL result type.
public export
data Rhs : ValueTy → Type where
  RFloatUnary : FloatUnary → Operand TFloat → Rhs TFloat
  RFloatBinary : FloatBinary → Operand TFloat → Operand TFloat → Rhs TFloat
  RFloatTernary : FloatTernary → Operand TFloat → Operand TFloat →
                  Operand TFloat → Rhs TFloat
  RComparison : Comparison → Operand TFloat → Operand TFloat → Rhs TBool
  RBoolUnary : BoolUnary → Operand TBool → Rhs TBool
  RBoolBinary : BoolBinary → Operand TBool → Operand TBool → Rhs TBool
  RVec2 : Operand TFloat → Operand TFloat → Rhs (TVec 2)
  RVec3 : Operand TFloat → Operand TFloat → Operand TFloat → Rhs (TVec 3)
  RVec4 : Operand TFloat → Operand TFloat → Operand TFloat →
          Operand TFloat → Rhs (TVec 4)
  RVectorBinary : VectorBinary → Operand (TVec n) → Operand (TVec n) →
                  Rhs (TVec n)
  RScale : Operand TFloat → Operand (TVec n) → Rhs (TVec n)
  RDot : Operand (TVec n) → Operand (TVec n) → Rhs TFloat
  RLength : Operand (TVec n) → Rhs TFloat
  RNormalize : Operand (TVec n) → Rhs (TVec n)
  RComponent : Fin n → Operand (TVec n) → Rhs TFloat
  RSelect : Operand TBool → Operand ty → Operand ty → Rhs ty

public export
record Binding where
  constructor MkBinding
  bindingTy : ValueTy
  bindingName : String
  bindingRhs : Rhs bindingTy

public export
record FragmentProgram where
  constructor MkFragmentProgram
  spec : EntrySpec
  bindings : List Binding
  result : Operand (TVec 4)

public export
expect : (wanted : ValueTy) → SomeOperand → Either String (Operand wanted)
expect wanted (PackOperand actual value) with (decEq wanted actual)
  expect wanted (PackOperand wanted value) | Yes Refl = Right value
  expect wanted (PackOperand actual value) | No _ =
    Left ("expected " ++ show wanted ++ ", received " ++ show actual)

public export
expectVector : SomeOperand → Either String SomeVector
expectVector (PackOperand (TVec n) value) = Right (PackVector n value)
expectVector (PackOperand actual _) =
  Left ("expected a vector, received " ++ show actual)
