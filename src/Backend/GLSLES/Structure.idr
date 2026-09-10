module Backend.GLSLES.Structure

import Backend.GLSLES.IR
import Data.List

%default total

bindingNameOf : Binding -> String
bindingNameOf (MkBinding _ name _) = name

operandLocals : Operand ty -> List String
operandLocals (OLocal name) = [name]
operandLocals (OFloat _) = []
operandLocals (OBool _) = []

rhsLocals : Rhs ty -> List String
rhsLocals (RFloatUnary _ value) = operandLocals value
rhsLocals (RFloatBinary _ left right) = operandLocals left ++ operandLocals right
rhsLocals (RFloatTernary _ first second third) = operandLocals first ++ operandLocals second ++ operandLocals third
rhsLocals (RComparison _ left right) = operandLocals left ++ operandLocals right
rhsLocals (RBoolUnary _ value) = operandLocals value
rhsLocals (RBoolBinary _ left right) = operandLocals left ++ operandLocals right
rhsLocals (RIntToFloat value) = operandLocals value
rhsLocals (RArrayIndex _ array index) = operandLocals array ++ operandLocals index
rhsLocals (RVec2 x y) = operandLocals x ++ operandLocals y
rhsLocals (RVec3 x y z) = operandLocals x ++ operandLocals y ++ operandLocals z
rhsLocals (RVec4 x y z w) = operandLocals x ++ operandLocals y ++ operandLocals z ++ operandLocals w
rhsLocals (RVectorBinary _ left right) = operandLocals left ++ operandLocals right
rhsLocals (RScale scalar vector) = operandLocals scalar ++ operandLocals vector
rhsLocals (RDot left right) = operandLocals left ++ operandLocals right
rhsLocals (RLength vector) = operandLocals vector
rhsLocals (RNormalize vector) = operandLocals vector
rhsLocals (RComponent _ vector) = operandLocals vector
rhsLocals (RSelect condition whenTrue whenFalse) = operandLocals condition ++ operandLocals whenTrue ++ operandLocals whenFalse

bindingLocals : Binding -> List String
bindingLocals (MkBinding _ _ rhs) = rhsLocals rhs

without : List String -> List String -> List String
without [] _ = []
without (value :: rest) excluded = if elem value excluded then without rest excluded else value :: without rest excluded

maybeOperandLocals : Maybe (Operand ty) -> List String
maybeOperandLocals Nothing = []
maybeOperandLocals (Just value) = operandLocals value

covering
statementLocals : Statement -> List String
statementLocals (SBinding binding) = bindingLocals binding
statementLocals (SIf _ _ condition thenStatements thenResult elseStatements elseResult) =
  operandLocals condition ++
  concatMap statementLocals thenStatements ++ operandLocals thenResult ++
  concatMap statementLocals elseStatements ++ operandLocals elseResult
statementLocals (SBoundedLoop _ _ indexName stateName _ activeBound initialState body bodyResult) =
  maybeOperandLocals activeBound ++ operandLocals initialState ++
  without (concatMap statementLocals body ++ operandLocals bodyResult)
          [indexName, stateName]

unique : List String -> List String
unique [] = []
unique (value :: rest) = if elem value rest then unique rest else value :: unique rest

addMissing : List String -> List String -> List String
addMissing [] existing = existing
addMissing (value :: rest) existing =
  if elem value existing then addMissing rest existing else addMissing rest (value :: existing)

||| Follow a set of result names backwards through an already-emitted legacy
||| linear prefix. This module is retained only for old RSelect producers while
||| source cases migrate to first-class structured IR.
dependencyScan : List Statement -> List String -> List String -> List String
dependencyScan [] _ found = found
dependencyScan (SBinding binding :: rest) wanted found =
  let name = bindingNameOf binding in
  if elem name wanted
     then dependencyScan rest (addMissing (bindingLocals binding) wanted) (name :: found)
     else dependencyScan rest wanted found
dependencyScan (SIf _ _ _ _ _ _ _ :: rest) wanted found = dependencyScan rest wanted found
dependencyScan (SBoundedLoop _ _ _ _ _ _ _ _ _ :: rest) wanted found =
  dependencyScan rest wanted found

operandDependencies : List Statement -> Operand ty -> List String
operandDependencies statements (OLocal name) = dependencyScan statements [name] []
operandDependencies _ (OFloat _) = []
operandDependencies _ (OBool _) = []

common : List String -> List String -> List String
common [] _ = []
common (value :: rest) other = if elem value other then value :: common rest other else common rest other

bindingsNamedInOrder : List Statement -> List String -> List Binding
bindingsNamedInOrder reversedStatements wanted = collect (reverse reversedStatements)
  where
    collect : List Statement -> List Binding
    collect [] = []
    collect (SBinding binding :: rest) =
      if elem (bindingNameOf binding) wanted then binding :: collect rest else collect rest
    collect (SIf _ _ _ _ _ _ _ :: rest) = collect rest
    collect (SBoundedLoop _ _ _ _ _ _ _ _ _ :: rest) = collect rest

removeNamed : List String -> List Statement -> List Statement
removeNamed _ [] = []
removeNamed names (SBinding binding :: rest) =
  if elem (bindingNameOf binding) names then removeNamed names rest else SBinding binding :: removeNamed names rest
removeNamed names (statement@(SIf _ _ _ _ _ _ _) :: rest) = statement :: removeNamed names rest
removeNamed names (statement@(SBoundedLoop _ _ _ _ _ _ _ _ _) :: rest) =
  statement :: removeNamed names rest

usesAny : List String -> List String -> Bool
usesAny [] _ = False
usesAny (name :: rest) wanted = elem name wanted || usesAny rest wanted

covering
statementsUse : List String -> List Statement -> Bool
statementsUse _ [] = False
statementsUse names (statement :: rest) = usesAny (statementLocals statement) names || statementsUse names rest

futureUses : List String -> List Binding -> Bool
futureUses _ [] = False
futureUses names (binding :: rest) = usesAny (bindingLocals binding) names || futureUses names rest

covering
externalRoots : List String -> List Statement -> List Binding -> List String
externalRoots [] _ _ = []
externalRoots (name :: rest) outside future =
  if statementsUse [name] outside || futureUses [name] future
     then name :: externalRoots rest outside future
     else externalRoots rest outside future

rhsCost : Rhs ty -> Nat
rhsCost (RFloatUnary FSin _) = 4
rhsCost (RFloatUnary FCos _) = 4
rhsCost (RFloatUnary FSqrt _) = 4
rhsCost (RFloatUnary FLog _) = 5
rhsCost (RFloatBinary FAtan2 _ _) = 5
rhsCost (RFloatBinary FPow _ _) = 6
rhsCost (RLength _) = 3
rhsCost (RNormalize _) = 4
rhsCost _ = 1

bindingCost : Binding -> Nat
bindingCost (MkBinding _ _ rhs) = rhsCost rhs

bindingsCost : List Binding -> Nat
bindingsCost [] = 0
bindingsCost (binding :: rest) = bindingCost binding + bindingsCost rest

worthMoving : List Binding -> Bool
worthMoving body = bindingsCost body >= 4

asStatements : List Binding -> List Statement
asStatements = map SBinding

covering
tryStructured : List Statement -> Binding -> List Binding -> Maybe (List Statement, Statement)
tryStructured reversedStatements (MkBinding ty name (RSelect condition whenTrue whenFalse)) future =
  let thenDependencies = operandDependencies reversedStatements whenTrue
      elseDependencies = operandDependencies reversedStatements whenFalse
      shared = common thenDependencies elseDependencies
      thenExclusive = without thenDependencies shared
      elseExclusive = without elseDependencies shared
      allExclusive = unique (thenExclusive ++ elseExclusive)
      outsideExclusive = removeNamed allExclusive reversedStatements
      roots = externalRoots allExclusive outsideExclusive future
      protected = dependencyScan reversedStatements roots []
      safeThen = without thenExclusive protected
      safeElse = without elseExclusive protected
      safeThenBody = bindingsNamedInOrder reversedStatements safeThen
      safeElseBody = bindingsNamedInOrder reversedStatements safeElse
      thenMoved = if worthMoving safeThenBody then safeThen else []
      elseMoved = if worthMoving safeElseBody then safeElse else []
      claimed = unique (thenMoved ++ elseMoved)
      remaining = removeNamed claimed reversedStatements
      thenBody = bindingsNamedInOrder reversedStatements thenMoved
      elseBody = bindingsNamedInOrder reversedStatements elseMoved
   in if claimed == []
         then Nothing
         else if statementsUse claimed remaining
                 then Nothing
                 else if futureUses claimed future
                         then Nothing
                         else Just (
                           remaining,
                           SIf ty name condition
                             (asStatements thenBody) whenTrue
                             (asStatements elseBody) whenFalse
                         )
tryStructured _ _ _ = Nothing

covering
structure : List Statement -> List Binding -> List Statement
structure reversedStatements [] = reverse reversedStatements
structure reversedStatements (binding :: rest) =
  case tryStructured reversedStatements binding rest of
    Nothing => structure (SBinding binding :: reversedStatements) rest
    Just (remaining, statement) => structure (statement :: remaining) rest

||| Transitional compatibility for legacy linear RSelect producers. New source
||| control flow should already be represented by Statement before this point.
covering
public export
structureBindings : List Binding -> List Statement
structureBindings = structure []
