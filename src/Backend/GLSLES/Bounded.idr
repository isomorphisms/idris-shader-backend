module Backend.GLSLES.Bounded

import Compiler.ANF
import Core.Name
import Core.TT
import Data.List
import Data.Vect

%default covering

Bindings : Type
Bindings = List (Int, ANF)

public export
record BoundedLoopShape where
  constructor MkBoundedLoopShape
  loopParameters : List Int
  loopIndexParameter : Int
  loopStateParameter : Int
  loopActiveParameter : Int
  loopMaximum : Nat
  loopBody : ANF

peelLets : ANF -> (Bindings, ANF)
peelLets (ALet _ variable value scope) =
  let (rest, terminal) = peelLets scope
   in ((variable, value) :: rest, terminal)
peelLets expression = ([], expression)

lookupBinding : Int -> Bindings -> Maybe ANF
lookupBinding _ [] = Nothing
lookupBinding wanted ((variable, value) :: rest) =
  if wanted == variable then Just value else lookupBinding wanted rest

localNumber : AVar -> Maybe Int
localNumber (ALocal variable) = Just variable
localNumber ANull = Nothing

floatConstant : Bindings -> AVar -> Maybe Double
floatConstant bindings (ALocal variable) = do
  expression <- lookupBinding variable bindings
  case expression of
    APrimVal _ (Db value) => Just value
    AV _ alias => floatConstant bindings alias
    _ => Nothing
floatConstant _ ANull = Nothing

naturalBound : Double -> Maybe Nat
naturalBound value =
  if value <= 0.0
     then Nothing
     else
       let candidate : Nat = cast value
        in if the Double (cast candidate) == value
              then Just candidate
              else Nothing

matchMinBound : ANF -> Maybe (Int, Nat)
matchMinBound expression =
  let (bindings, terminal) = peelLets expression in
  case terminal of
    AExtPrim _ _ primitive [left, right] =>
      if nameRoot primitive == "minF"
         then case (floatConstant bindings left, floatConstant bindings right) of
                (Nothing, Just maximum) => do
                  active <- localNumber left
                  bound <- naturalBound maximum
                  Just (active, bound)
                (Just maximum, Nothing) => do
                  active <- localNumber right
                  bound <- naturalBound maximum
                  Just (active, bound)
                _ => Nothing
         else Nothing
    _ => Nothing

boundExpression : Bindings -> AVar -> Maybe ANF
boundExpression bindings (ALocal variable) = lookupBinding variable bindings
boundExpression _ ANull = Nothing

matchLessThan : ANF -> Maybe (Int, Int, Nat)
matchLessThan expression =
  let (bindings, terminal) = peelLets expression in
  case terminal of
    AAppName _ _ comparison [index, bound] =>
      if nameRoot comparison == "<"
         then do
           indexParameter <- localNumber index
           boundValue <- boundExpression bindings bound
           (activeParameter, maximum) <- matchMinBound boundValue
           Just (indexParameter, activeParameter, maximum)
         else Nothing
    AOp _ _ (LT DoubleType) arguments =>
      case toList arguments of
        [index, bound] => do
          indexParameter <- localNumber index
          boundValue <- boundExpression bindings bound
          (activeParameter, maximum) <- matchMinBound boundValue
          Just (indexParameter, activeParameter, maximum)
        _ => Nothing
    _ => Nothing

boolConstant : Constant -> Maybe Bool
boolConstant (I 0) = Just False
boolConstant (I 1) = Just True
boolConstant (I8 0) = Just False
boolConstant (I8 1) = Just True
boolConstant (I16 0) = Just False
boolConstant (I16 1) = Just True
boolConstant (I32 0) = Just False
boolConstant (I32 1) = Just True
boolConstant (I64 0) = Just False
boolConstant (I64 1) = Just True
boolConstant (BI 0) = Just False
boolConstant (BI 1) = Just True
boolConstant (B8 0) = Just False
boolConstant (B8 1) = Just True
boolConstant (B16 0) = Just False
boolConstant (B16 1) = Just True
boolConstant (B32 0) = Just False
boolConstant (B32 1) = Just True
boolConstant (B64 0) = Just False
boolConstant (B64 1) = Just True
boolConstant _ = Nothing

findConstBranch : Bool -> List AConstAlt -> Maybe ANF
findConstBranch _ [] = Nothing
findConstBranch wanted (MkAConstAlt constant body :: rest) =
  case boolConstant constant of
    Just actual => if wanted == actual then Just body else findConstBranch wanted rest
    Nothing => findConstBranch wanted rest

findConBranch : Bool -> List AConAlt -> Maybe ANF
findConBranch _ [] = Nothing
findConBranch wanted (MkAConAlt name _ _ _ body :: rest) =
  case nameRoot name of
    "False" => if not wanted then Just body else findConBranch wanted rest
    "True" => if wanted then Just body else findConBranch wanted rest
    _ => findConBranch wanted rest

matchCase : ANF -> Maybe (ANF, ANF, ANF)
matchCase expression =
  let (bindings, terminal) = peelLets expression in
  case terminal of
    AConstCase _ scrutinee alternatives defaultBranch => do
      condition <- boundExpression bindings scrutinee
      let falseBranch = case findConstBranch False alternatives of
                             Just body => Just body
                             Nothing => defaultBranch
      let trueBranch = case findConstBranch True alternatives of
                            Just body => Just body
                            Nothing => defaultBranch
      falseBody <- falseBranch
      trueBody <- trueBranch
      Just (condition, trueBody, falseBody)
    AConCase _ scrutinee alternatives defaultBranch => do
      condition <- boundExpression bindings scrutinee
      let falseBranch = case findConBranch False alternatives of
                             Just body => Just body
                             Nothing => defaultBranch
      let trueBranch = case findConBranch True alternatives of
                            Just body => Just body
                            Nothing => defaultBranch
      falseBody <- falseBranch
      trueBody <- trueBranch
      Just (condition, trueBody, falseBody)
    _ => Nothing

stateReturn : ANF -> Maybe Int
stateReturn (AV _ (ALocal variable)) = Just variable
stateReturn _ = Nothing

argumentFor : Int -> List Int -> List AVar -> Maybe AVar
argumentFor _ [] [] = Nothing
argumentFor wanted (parameter :: parameters) (argument :: arguments) =
  if wanted == parameter
     then Just argument
     else argumentFor wanted parameters arguments
argumentFor _ _ _ = Nothing

sameInvariantArguments : Int -> Int -> List Int -> List AVar -> Bool
sameInvariantArguments _ _ [] [] = True
sameInvariantArguments indexParameter stateParameter
                       (parameter :: parameters) (argument :: arguments) =
  let current =
        if parameter == indexParameter || parameter == stateParameter
           then True
           else argument == ALocal parameter
   in current &&
      sameInvariantArguments indexParameter stateParameter parameters arguments
sameInvariantArguments _ _ _ _ = False

isOne : Bindings -> AVar -> Bool
isOne bindings variable = case floatConstant bindings variable of
  Just value => value == 1.0
  Nothing => False

matchIncrement : Int -> Bindings -> AVar -> Bool
matchIncrement indexParameter bindings (ALocal variable) =
  case lookupBinding variable bindings of
    Nothing => False
    Just expression =>
      let (innerBindings, terminal) = peelLets expression in
      case terminal of
        AOp _ _ (Add DoubleType) arguments =>
          case toList arguments of
            [left, right] =>
              (left == ALocal indexParameter && isOne innerBindings right) ||
              (right == ALocal indexParameter && isOne innerBindings left)
            _ => False
        _ => False
matchIncrement _ _ ANull = False

public export
matchBoundedLoop : Name -> ANFDef -> Maybe BoundedLoopShape
matchBoundedLoop self (MkAFun parameters body) = do
  (condition, trueBody, falseBody) <- matchCase body
  (indexParameter, activeParameter, maximum) <- matchLessThan condition
  stateParameter <- stateReturn falseBody
  if indexParameter == stateParameter ||
     indexParameter == activeParameter ||
     stateParameter == activeParameter ||
     not (elem indexParameter parameters) ||
     not (elem stateParameter parameters) ||
     not (elem activeParameter parameters)
     then Nothing
     else pure ()
  let (bodyBindings, terminal) = peelLets trueBody
  recursiveArguments <- case terminal of
    AAppName _ _ called arguments =>
      if called == self then Just arguments else Nothing
    _ => Nothing
  if sameInvariantArguments indexParameter stateParameter
                            parameters recursiveArguments
     then pure ()
     else Nothing
  nextIndex <- argumentFor indexParameter parameters recursiveArguments
  if matchIncrement indexParameter bodyBindings nextIndex
     then pure ()
     else Nothing
  Just (MkBoundedLoopShape parameters indexParameter stateParameter
                           activeParameter maximum trueBody)
matchBoundedLoop _ _ = Nothing
