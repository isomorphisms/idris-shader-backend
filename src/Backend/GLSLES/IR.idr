module Backend.GLSLES.IR

import Data.Fin
import Decidable.Equality

%default total

public export
data ArrayElementTy = AFloat | ABool | AInt | AVec Nat

public export
Eq ArrayElementTy where
  AFloat == AFloat = True
  ABool == ABool = True
  AInt == AInt = True
  AVec n == AVec m = n == m
  _ == _ = False

public export
DecEq ArrayElementTy where
  decEq AFloat AFloat = Yes Refl
  decEq AFloat ABool = No (\Refl impossible)
  decEq AFloat AInt = No (\Refl impossible)
  decEq AFloat (AVec _) = No (\Refl impossible)
  decEq ABool AFloat = No (\Refl impossible)
  decEq ABool ABool = Yes Refl
  decEq ABool AInt = No (\Refl impossible)
  decEq ABool (AVec _) = No (\Refl impossible)
  decEq AInt AFloat = No (\Refl impossible)
  decEq AInt ABool = No (\Refl impossible)
  decEq AInt AInt = Yes Refl
  decEq AInt (AVec _) = No (\Refl impossible)
  decEq (AVec _) AFloat = No (\Refl impossible)
  decEq (AVec _) ABool = No (\Refl impossible)
  decEq (AVec _) AInt = No (\Refl impossible)
  decEq (AVec n) (AVec m) with (decEq n m)
    decEq (AVec n) (AVec n) | Yes Refl = Yes Refl
    decEq (AVec n) (AVec m) | No contra = No (\Refl => contra Refl)

public export
Show ArrayElementTy where
  show AFloat = "float"
  show ABool = "bool"
  show AInt = "int"
  show (AVec n) = "vec" ++ show n

||| Runtime value types admitted by the restricted shader compiler. Vector
||| width and fixed array length remain explicit in the checked shader IR.
public export
data ValueTy = TFloat | TBool | TInt | TVec Nat | TArray Nat ArrayElementTy

public export
arrayElementValueTy : ArrayElementTy -> ValueTy
arrayElementValueTy AFloat = TFloat
arrayElementValueTy ABool = TBool
arrayElementValueTy AInt = TInt
arrayElementValueTy (AVec n) = TVec n

public export
Eq ValueTy where
  TFloat == TFloat = True
  TBool == TBool = True
  TInt == TInt = True
  TVec n == TVec m = n == m
  TArray n a == TArray m b = n == m && a == b
  _ == _ = False

public export
DecEq ValueTy where
  decEq TFloat TFloat = Yes Refl
  decEq TFloat TBool = No (\Refl impossible)
  decEq TFloat TInt = No (\Refl impossible)
  decEq TFloat (TVec _) = No (\Refl impossible)
  decEq TFloat (TArray _ _) = No (\Refl impossible)
  decEq TBool TFloat = No (\Refl impossible)
  decEq TBool TBool = Yes Refl
  decEq TBool TInt = No (\Refl impossible)
  decEq TBool (TVec _) = No (\Refl impossible)
  decEq TBool (TArray _ _) = No (\Refl impossible)
  decEq TInt TFloat = No (\Refl impossible)
  decEq TInt TBool = No (\Refl impossible)
  decEq TInt TInt = Yes Refl
  decEq TInt (TVec _) = No (\Refl impossible)
  decEq TInt (TArray _ _) = No (\Refl impossible)
  decEq (TVec _) TFloat = No (\Refl impossible)
  decEq (TVec _) TBool = No (\Refl impossible)
  decEq (TVec _) TInt = No (\Refl impossible)
  decEq (TVec n) (TVec m) with (decEq n m)
    decEq (TVec n) (TVec n) | Yes Refl = Yes Refl
    decEq (TVec n) (TVec m) | No contra = No (\Refl => contra Refl)
  decEq (TVec _) (TArray _ _) = No (\Refl impossible)
  decEq (TArray _ _) TFloat = No (\Refl impossible)
  decEq (TArray _ _) TBool = No (\Refl impossible)
  decEq (TArray _ _) TInt = No (\Refl impossible)
  decEq (TArray _ _) (TVec _) = No (\Refl impossible)
  decEq (TArray n a) (TArray m b) with (decEq n m)
    decEq (TArray n a) (TArray n b) | Yes Refl with (decEq a b)
      decEq (TArray n a) (TArray n a) | Yes Refl | Yes Refl = Yes Refl
      decEq (TArray n a) (TArray n b) | Yes Refl | No contra =
        No (\Refl => contra Refl)
    decEq (TArray n a) (TArray m b) | No contra = No (\Refl => contra Refl)

public export
Show ValueTy where
  show TFloat = "float"
  show TBool = "bool"
  show TInt = "int"
  show (TVec n) = "vec" ++ show n
  show (TArray n elementTy) = show elementTy ++ "[" ++ show n ++ "]"

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
data Operand : ValueTy -> Type where
  OLocal : String -> Operand ty
  OFloat : Double -> Operand TFloat
  OBool : Bool -> Operand TBool

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
record SomeArray where
  constructor PackArray
  length : Nat
  elementTy : ArrayElementTy
  array : Operand (TArray length elementTy)

public export
data FloatUnary =
    FNeg
  | FAbs
  | FSqrt
  | FSin
  | FCos
  | FFloor
  | FFract
  | FLog

public export
data FloatBinary =
    FAdd
  | FSub
  | FMul
  | FDiv
  | FMin
  | FMax
  | FAtan2
  | FPow

public export
data FloatTernary = FClamp | FMix | FSmoothstep

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
data Rhs : ValueTy -> Type where
  RFloatUnary : FloatUnary -> Operand TFloat -> Rhs TFloat
  RFloatBinary : FloatBinary -> Operand TFloat -> Operand TFloat -> Rhs TFloat
  RFloatTernary : FloatTernary -> Operand TFloat -> Operand TFloat ->
                  Operand TFloat -> Rhs TFloat
  RComparison : Comparison -> Operand TFloat -> Operand TFloat -> Rhs TBool
  RBoolUnary : BoolUnary -> Operand TBool -> Rhs TBool
  RBoolBinary : BoolBinary -> Operand TBool -> Operand TBool -> Rhs TBool
  RIntToFloat : Operand TInt -> Rhs TFloat
  RArrayIndex : Operand (TArray n elementTy) -> Operand TFloat ->
                Rhs (arrayElementValueTy elementTy)
  RVec2 : Operand TFloat -> Operand TFloat -> Rhs (TVec 2)
  RVec3 : Operand TFloat -> Operand TFloat -> Operand TFloat -> Rhs (TVec 3)
  RVec4 : Operand TFloat -> Operand TFloat -> Operand TFloat ->
          Operand TFloat -> Rhs (TVec 4)
  RVectorBinary : VectorBinary -> Operand (TVec n) -> Operand (TVec n) ->
                  Rhs (TVec n)
  RScale : Operand TFloat -> Operand (TVec n) -> Rhs (TVec n)
  RDot : Operand (TVec n) -> Operand (TVec n) -> Rhs TFloat
  RLength : Operand (TVec n) -> Rhs TFloat
  RNormalize : Operand (TVec n) -> Rhs (TVec n)
  RComponent : Fin n -> Operand (TVec n) -> Rhs TFloat
  RSelect : Operand TBool -> Operand ty -> Operand ty -> Rhs ty

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
expect : (wanted : ValueTy) -> SomeOperand -> Either String (Operand wanted)
expect wanted (PackOperand actual value) with (decEq wanted actual)
  expect wanted (PackOperand wanted value) | Yes Refl = Right value
  expect wanted (PackOperand actual value) | No _ =
    Left ("expected " ++ show wanted ++ ", received " ++ show actual)

public export
expectVector : SomeOperand -> Either String SomeVector
expectVector (PackOperand (TVec n) value) = Right (PackVector n value)
expectVector (PackOperand actual _) =
  Left ("expected a vector, received " ++ show actual)

public export
expectArray : SomeOperand -> Either String SomeArray
expectArray (PackOperand (TArray n elementTy) value) =
  Right (PackArray n elementTy value)
expectArray (PackOperand actual _) =
  Left ("expected a fixed array, received " ++ show actual)
