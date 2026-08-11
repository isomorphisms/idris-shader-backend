module Shader.Eval

import Data.Vect
import Shader.Types
import Shader.IR

%default total

dotVect : Vect n Double -> Vect n Double -> Double
dotVect [] [] = 0.0
dotVect (x :: xs) (y :: ys) = x * y + dotVect xs ys

scaleVect : Double -> Vect n Double -> Vect n Double
scaleVect scalar = map (\value => scalar * value)

normalizeVect : Vect n Double -> Vect n Double
normalizeVect values =
  let magnitude = sqrt (dotVect values values)
   in map (\value => value / magnitude) values

clampDouble : Double -> Double -> Double -> Double
clampDouble value low high =
  if value < low then low else if value > high then high else value

mixDouble : Double -> Double -> Double -> Double
mixDouble left right weight = left * (1.0 - weight) + right * weight

||| Pure reference evaluator for differential tests against a GPU result.
public export
eval : Values context -> Expr context ty -> Sem ty
eval _   (FloatLit value) = value
eval _   (BoolLit value) = value
eval env (Var position) = lookupValue position env

eval env (Vec2 x y) = [eval env x, eval env y]
eval env (Vec3 x y z) = [eval env x, eval env y, eval env z]
eval env (Vec4 x y z w) = [eval env x, eval env y, eval env z, eval env w]

eval env (AddF left right) = eval env left + eval env right
eval env (SubF left right) = eval env left - eval env right
eval env (MulF left right) = eval env left * eval env right
eval env (DivF left right) = eval env left / eval env right
eval env (NegF value) = negate (eval env value)
eval env (AbsF value) = abs (eval env value)
eval env (SqrtF value) = sqrt (eval env value)
eval env (SinF value) = sin (eval env value)
eval env (CosF value) = cos (eval env value)
eval env (MinF left right) = min (eval env left) (eval env right)
eval env (MaxF left right) = max (eval env left) (eval env right)
eval env (ClampF value low high) =
  clampDouble (eval env value) (eval env low) (eval env high)
eval env (MixF left right weight) =
  mixDouble (eval env left) (eval env right) (eval env weight)

eval env (Add2 left right) = zipWith (+) (eval env left) (eval env right)
eval env (Sub2 left right) = zipWith (-) (eval env left) (eval env right)
eval env (Scale2 scalar value) = scaleVect (eval env scalar) (eval env value)
eval env (Dot2 left right) = dotVect (eval env left) (eval env right)
eval env (Length2 value) = sqrt (dotVect (eval env value) (eval env value))
eval env (Normalize2 value) = normalizeVect (eval env value)

eval env (Add3 left right) = zipWith (+) (eval env left) (eval env right)
eval env (Sub3 left right) = zipWith (-) (eval env left) (eval env right)
eval env (Scale3 scalar value) = scaleVect (eval env scalar) (eval env value)
eval env (Dot3 left right) = dotVect (eval env left) (eval env right)
eval env (Length3 value) = sqrt (dotVect (eval env value) (eval env value))
eval env (Normalize3 value) = normalizeVect (eval env value)

eval env (Add4 left right) = zipWith (+) (eval env left) (eval env right)
eval env (Sub4 left right) = zipWith (-) (eval env left) (eval env right)
eval env (Scale4 scalar value) = scaleVect (eval env scalar) (eval env value)
eval env (Dot4 left right) = dotVect (eval env left) (eval env right)
eval env (Length4 value) = sqrt (dotVect (eval env value) (eval env value))
eval env (Normalize4 value) = normalizeVect (eval env value)

eval env (X2 value) = index 0 (eval env value)
eval env (Y2 value) = index 1 (eval env value)
eval env (X3 value) = index 0 (eval env value)
eval env (Y3 value) = index 1 (eval env value)
eval env (Z3 value) = index 2 (eval env value)
eval env (X4 value) = index 0 (eval env value)
eval env (Y4 value) = index 1 (eval env value)
eval env (Z4 value) = index 2 (eval env value)
eval env (W4 value) = index 3 (eval env value)

eval env (LtF left right) = eval env left < eval env right
eval env (LeF left right) = eval env left <= eval env right
eval env (EqF left right) = eval env left == eval env right
eval env (GeF left right) = eval env left >= eval env right
eval env (GtF left right) = eval env left > eval env right
eval env (AndB left right) = eval env left && eval env right
eval env (OrB left right) = eval env left || eval env right
eval env (NotB value) = not (eval env value)
eval env (Select condition whenTrue whenFalse) =
  if eval env condition then eval env whenTrue else eval env whenFalse

