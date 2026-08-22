module Backend.GLSLES.Signature

import Backend.GLSLES.IR
import Core.Name
import Core.TT

%default covering

parseNat : Term vars -> Either String Nat
parseNat (Ref _ _ name) =
  if nameRoot name == "Z"
     then Right 0
     else Left ("expected a concrete size, received " ++ show name)
parseNat (App _ (Ref _ _ name) predecessor) =
  if nameRoot name == "S"
     then S <$> parseNat predecessor
     else Left ("expected a concrete size, received " ++ show name)
parseNat _ = Left "expected a concrete size"

arrayElement : ValueTy -> Either String ArrayElementTy
arrayElement TFloat = Right AFloat
arrayElement TBool = Right ABool
arrayElement TInt = Right AInt
arrayElement (TVec n) = Right (AVec n)
arrayElement (TArray _ _) = Left "nested shader arrays are not supported"

parseValueTy : Term vars -> Either String ValueTy
parseValueTy (PrimVal _ (PrT DoubleType)) = Right TFloat
parseValueTy (PrimVal _ (PrT IntType)) = Right TInt
parseValueTy (Ref _ _ name) = case nameRoot name of
  "Double" => Right TFloat
  "Bool" => Right TBool
  "Int" => Right TInt
  other => Left ("unsupported shader entry type " ++ other)
parseValueTy (App _ (Ref _ _ name) width) =
  if nameRoot name == "SVec"
     then do
       n <- parseNat width
       if n >= 2 && n <= 4
          then Right (TVec n)
          else Left ("GLSL ES vectors must have width 2, 3, or 4; received " ++ show n)
     else Left ("unsupported shader entry type " ++ show name)
parseValueTy (App _ (App _ (Ref _ _ name) count) elementType) =
  if nameRoot name == "SArray"
     then do
       n <- parseNat count
       if n == 0
          then Left "shader arrays must contain at least one element"
          else do
            element <- parseValueTy elementType >>= arrayElement
            Right (TArray n element)
     else Left ("unsupported shader entry type " ++ show name)
parseValueTy _ = Left "unsupported shader entry type"

||| Read shader types before Idris erases them on the way to ANF.
public export
shaderSignature : ClosedTerm -> Either String (List ValueTy, ValueTy)
shaderSignature = go []
  where
    go : List ValueTy -> Term vars -> Either String (List ValueTy, ValueTy)
    go reversed (Bind _ _ (Pi _ _ Explicit argumentType) scope) = do
      ty <- parseValueTy argumentType
      go (ty :: reversed) scope
    go _ (Bind _ _ (Pi _ _ _ _) _) =
      Left "shader entry points may not have implicit or auto arguments"
    go reversed resultType = do
      result <- parseValueTy resultType
      Right (reverse reversed, result)
