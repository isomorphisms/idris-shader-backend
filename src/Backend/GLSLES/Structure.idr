module Backend.GLSLES.Structure

import Backend.GLSLES.IR
import Data.List

%default total

||| A typed structured conditional recovered from the linear shader IR before
||| GLSL emission. Branch-local bindings may be emitted inside real control
||| flow instead of being evaluated eagerly before a ternary select.
public export
record StructuredIf where
  constructor MkStructuredIf
  branchResultTy : ValueTy
  branchName : String
  branchCondition : Operand TBool
  thenBindings : List Binding
  thenResult : Operand branchResultTy
  elseBindings : List Binding
  elseResult : Operand branchResultTy

public export
data Statement = SBinding Binding | SIf StructuredIf

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
rhsLocals (RArrayIndex array index) = operandLocals array ++ operandLocals index
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

structuredLocals : StructuredIf -> List String
structuredLocals branch =
  operandLocals (branchCondition branch) ++
  concatMap bindingLocals (thenBindings branch) ++ operandLocals (thenResult branch) ++
  concatMap bindingLocals (elseBindings branch) ++ operandLocals (elseResult branch)

statementLocals : Statement -> List String
statementLocals (SBinding binding) = bindingLocals binding
statementLocals (SIf branch) = structuredLocals branch

unique : List String -> List String
unique [] = []
unique (value :: rest) = if elem value rest then unique rest else value :: unique rest

addMissing : List String -> List String -> List String
addMissing [] existing = existing
addMissing (value :: rest) existing =
  if elem value existing then addMissing rest existing else addMissing rest (value :: existing)

||| Follow a set of result names backwards through the already-emitted linear
||| prefix. Each statement is visited at most once for one dependency query.
dependencyScan : List Statement -> List String -> List String -> List String
dependencyScan [] _ found = found
dependencyScan (SBinding binding :: rest) wanted found =
  let name = bindingNameOf binding in
  if elem name wanted
     then dependencyScan rest (addMissing (bindingLocals binding) wanted) (name :: found)
     else dependencyScan rest wanted found
dependencyScan (SIf _ :: rest) wanted found = dependencyScan rest wanted found

operandDependencies : List Statement -> Operand ty -> List String
operandDependencies statements (OLocal name) = dependencyScan statements [name] []
operandDependencies _ (OFloat _) = []
operandDependencies _ (OBool _) = []

without : List String -> List String -> List String
without [] _ = []
without (value :: rest) excluded = if elem value excluded then without rest excluded else value :: without rest excluded

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
    collect (SIf _ :: rest) = collect rest

removeNamed : List String -> List Statement -> List Statement
removeNamed _ [] = []
removeNamed names (SBinding binding :: rest) =
  if elem (bindingNameOf binding) names then removeNamed names rest else SBinding binding :: removeNamed names rest
removeNamed names (statement@(SIf _) :: rest) = statement :: removeNamed names rest

usesAny : List String -> List String -> Bool
usesAny [] _ = False
usesAny (name :: rest) wanted = elem name wanted || usesAny rest wanted

statementsUse : List String -> List Statement -> Bool
statementsUse _ [] = False
statementsUse names (statement :: rest) = usesAny (statementLocals statement) names || statementsUse names rest

futureUses : List String -> List Binding -> Bool
futureUses _ [] = False
futureUses names (binding :: rest) = usesAny (bindingLocals binding) names || futureUses names rest

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
      -- If a value must remain outside the branch, every dependency needed to
      -- compute that value must remain outside too. Protecting the full closure
      -- of externally used roots leaves only a closed, genuinely branch-local
      -- subgraph to move. In the factor fold this keeps the common point outside
      -- while allowing each factor's array lookup / atan / log chain to move.
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
                         else Just (remaining, SIf (MkStructuredIf ty name condition thenBody whenTrue elseBody whenFalse))
tryStructured _ _ _ = Nothing

structure : List Statement -> List Binding -> List Statement
structure reversedStatements [] = reverse reversedStatements
structure reversedStatements (binding :: rest) =
  case tryStructured reversedStatements binding rest of
    Nothing => structure (SBinding binding :: reversedStatements) rest
    Just (remaining, statement) => structure (statement :: remaining) rest

||| Recover expensive branch-local work without a global shader-size cutoff.
||| Cheap selections stay RSelect/ternary; expensive closed subgraphs move into
||| real GLSL control flow.
public export
structureBindings : List Binding -> List Statement
structureBindings = structure []
