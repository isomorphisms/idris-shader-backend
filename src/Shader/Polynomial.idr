module Shader.Polynomial

import Data.List
import Shader.Types
import Shader.IR

%default total

||| c * x^px * y^py * z^pz
public export
record Monomial where
  constructor MkMonomial
  coefficient : Double
  xPower : Nat
  yPower : Nat
  zPower : Nat

public export
Polynomial : Type
Polynomial = List Monomial

multiplyAll : List (Expr context TFloat) → Expr context TFloat
multiplyAll [] = FloatLit 1.0
multiplyAll [single] = single
multiplyAll (first :: rest) = MulF first (multiplyAll rest)

powerFactor : Expr context TFloat → Nat → List (Expr context TFloat)
powerFactor _ Z = []
powerFactor value power = [powNat value power]

monomialExpr : Monomial → Expr context TVec3 → Expr context TFloat
monomialExpr monomial point =
  let coefficientFactors =
        if coefficient monomial == 1.0
           then []
           else [FloatLit (coefficient monomial)]
      factors = coefficientFactors
             ++ powerFactor (X3 point) (xPower monomial)
             ++ powerFactor (Y3 point) (yPower monomial)
             ++ powerFactor (Z3 point) (zPower monomial)
   in multiplyAll factors

sumAll : List (Expr context TFloat) → Expr context TFloat
sumAll [] = FloatLit 0.0
sumAll [single] = single
sumAll (first :: rest) = AddF first (sumAll rest)

||| Specialize a sparse polynomial into a straight-line typed expression.
public export
polynomialExpr : Polynomial → Expr context TVec3 → Expr context TFloat
polynomialExpr polynomial point = sumAll (map (\term ⇒ monomialExpr term point) polynomial)

deriveX : Monomial → Maybe Monomial
deriveX term = case xPower term of
  Z   ⇒ Nothing
  S k ⇒ Just (MkMonomial (coefficient term * cast (S k))
                             k (yPower term) (zPower term))

deriveY : Monomial → Maybe Monomial
deriveY term = case yPower term of
  Z   ⇒ Nothing
  S k ⇒ Just (MkMonomial (coefficient term * cast (S k))
                             (xPower term) k (zPower term))

deriveZ : Monomial → Maybe Monomial
deriveZ term = case zPower term of
  Z   ⇒ Nothing
  S k ⇒ Just (MkMonomial (coefficient term * cast (S k))
                             (xPower term) (yPower term) k)

public export
gradientPolynomials : Polynomial → (Polynomial, Polynomial, Polynomial)
gradientPolynomials polynomial =
  (mapMaybe deriveX polynomial,
   mapMaybe deriveY polynomial,
   mapMaybe deriveZ polynomial)

||| Symbolically differentiate first, then specialize all three components.
public export
gradientExpr : Polynomial → Expr context TVec3 → Expr context TVec3
gradientExpr polynomial point =
  let (dx, dy, dz) = gradientPolynomials polynomial
   in Vec3 (polynomialExpr dx point)
           (polynomialExpr dy point)
           (polynomialExpr dz point)
