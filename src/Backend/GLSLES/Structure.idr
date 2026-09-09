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
rhsLocals (RFloatTernary _ first second third) =
  operandLocals first ++ operandLocals second ++ operandLocals third
rhsLocals (RComparison _ left right) = operandLocals left ++ operandLocals right
rhsLocals (RBoolUnary _ value) = operandLocals value
rhsLocals (RBoolBinary _ left right) = operandLocals left ++ operandLocals right
rhsLocals (RIntToFloat value) = operandLocals value
rhsLocals (RArrayIndex array index) = operandLocals array ++ operandLocals index
rhsLocals (RVec2 x y) = operandLocals x ++ operandLocals y
rhsLocals (RVec3 x y z) = operandLocals x ++ operandLocals y ++ operandLocals z
rhsLocals (RVec4 x y z w) =
  operandLocals x ++ operandLocals y ++ operandLocals z ++ operandLocals w
rhsLocals (RVectorBinary _ left right) = operandLocals left ++ operandLocals right
rhsLocals (RScale scalar vector) = operandLocals scalar ++ operandLocals vector
rhsLocals (RDot left right) = operandLocals left ++ operandLocals right
rhsLocals (RLength vector) = operandLocals vector
rhsLocals (RNormalize vector) = operandLocals vector
rhsLocals (RComponent _ vector) = operandLocals vector
rhsLocals (RSelect condition whenTrue whenFalse) =
  operandLocals condition ++ operandLocals whenTrue ++ operandLocals whenFalse

bindingLocals : Binding -> List String
bindingLocals (MkBinding _ _ rhs) = rhsLocals rhs

structuredLocals : StructuredIf -> List String
structuredLocals branch =
  operandLocals (branchCondition branch) ++
  concatMap bindingLocals (thenBindings branch) ++
  operandLocals (thenResult branch) ++
  concatMap bindingLocals (elseBindings branch) ++
  operandLocals (elseResult branch)

statementLocals : Statement -> List String
statementLocals (SBinding binding) = bindingLocals binding
statementLocals (SIf branch) = structuredLocals branch

unique : List String -> List String
unique [] = []
unique (value :: rest) =
  if elem value rest then unique rest else value :: unique rest

addMissing : List String -> List String -> List String
addMissing [] existing = existing
addMissing (value :: rest) existing =
  if elem value existing
     then addMissing rest existing
     else addMissing rest (value :: existing)

||| Follow one operand's dependency chain with one backwards pass over the
||| already-emitted statements. Earlier versions repeatedly searched the whole
||| prefix once per dependency and therefore needed a hard 256-binding cutoff.
||| This walk visits each preceding statement at most once for one result and
||| scales to the large fixed-array shaders used by Analytic Continuation.
dependencyScan : List Statement -> List String -> List String -> List String
dependencyScan [] _ found = found
dependencyScan (SBinding binding :: rest) wanted found =
  let name = bindingNameOf binding
   in if elem name wanted
         then dependencyScan rest
                (addMissing (bindingLocals binding) wanted)
                (name :: found)
         else dependencyScan rest wanted found
dependencyScan (SIf _ :: rest) wanted found =
  -- A previously recovered branch is an intentional structure barrier. Its
  -- result remains outside a later branch rather than being flattened again.
  dependencyScan rest wanted found

operandDependencies : List Statement -> Operand ty -> List String
operandDependencies statements (OLocal name) = dependencyScan statements [name] []
operandDependencies _ (OFloat _) = []
operandDependencies _ (OBool _) = []

without : List String -> List String -> List String
without [] _ = []
without (value :: rest) excluded =
  if elem value excluded then without rest excluded else value :: without rest excluded

common : List String -> List String -> List String
common [] _ = []
common (value :: rest) other =
  if elem value other then value :: common rest other else common rest other

bindingsNamedInOrder : List Statement -> List String -> List Binding
bindingsNamedInOrder reversedStatements wanted = collect (reverse reversedStatements)
  where
    collect : List Statement -> List Binding
    collect [] = []
    collect (SBinding binding :: rest) =
      if elem (bindingNameOf binding) wanted
         then binding :: collect rest
         else collect rest
    collect (SIf _ :: rest) = collect rest

removeNamed : List String -> List Statement -> List Statement
removeNamed _ [] = []
removeNamed names (SBinding binding :: rest) =
  if elem (bindingNameOf binding) names
     then removeNamed names rest
     else SBinding binding :: removeNamed names rest
removeNamed names (statement@(SIf _) :: rest) = statement :: removeNamed names rest

usesAny : List String -> List String -> Bool
usesAny [] _ = False
usesAny (name :: rest) wanted = elem name wanted || usesAny rest wanted

statementsUse : List String -> List Statement -> Bool
statementsUse _ [] = False
statementsUse names (statement :: rest) =
  usesAny (statementLocals statement) names || statementsUse names rest

futureUses : List String -> List Binding -> Bool
futureUses _ [] = False
futureUses names (binding :: rest) =
  usesAny (bindingLocals binding) names || futureUses names rest

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

tryStructured : List Statement -> Binding -> List Binding ->
                Maybe (List Statement, Statement)
tryStructured reversedStatements
              (MkBinding ty name (RSelect condition whenTrue whenFalse)) future =
  let thenDependencies = operandDependencies reversedStatements whenTrue
      elseDependencies = operandDependencies reversedStatements whenFalse
      shared = common thenDependencies elseDependencies
      thenExclusive = without thenDependencies shared
      elseExclusive = without elseDependencies shared
      rawThenBody = bindingsNamedInOrder reversedStatements thenExclusive
      rawElseBody = bindingsNamedInOrder reversedStatements elseExclusive
      -- Only move a side when that side contains enough work to justify real
      -- control flow. Cheap constants and aliases deliberately stay outside.
      -- This is important for fixed-array folds: the common zero value is
      -- reused by many later selects, while each active factor has its own
      -- expensive atan/log dependency chain.
      thenMoved = if worthMoving rawThenBody then thenExclusive else []
      elseMoved = if worthMoving rawElseBody then elseExclusive else []
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
                         else
                           let structured = MkStructuredIf ty name condition
                                                           thenBody whenTrue
                                                           elseBody whenFalse
                            in Just (remaining, SIf structured)
tryStructured _ _ _ = Nothing

structure : List Statement -> List Binding -> List Statement
structure reversedStatements [] = reverse reversedStatements
structure reversedStatements (binding :: rest) =
  case tryStructured reversedStatements binding rest of
    Nothing => structure (SBinding binding :: reversedStatements) rest
    Just (remaining, statement) => structure (statement :: remaining) rest

||| Recover only control flow that is both safe to move and expensive enough
||| to justify a real branch. Cheap selects remain ordinary RSelect bindings.
|||
||| There is intentionally no shader-size cutoff. Dependency discovery is a
||| backwards scan rather than repeated whole-prefix lookup, so large shaders
||| can retain control flow instead of falling back to eager branch evaluation.
public export
structureBindings : List Binding -> List Statement
structureBindings = structure []
