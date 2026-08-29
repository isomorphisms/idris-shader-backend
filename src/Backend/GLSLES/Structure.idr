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

without : List String -> List String -> List String
without [] _ = []
without (value :: rest) excluded =
  if elem value excluded then without rest excluded else value :: without rest excluded

common : List String -> List String -> List String
common [] _ = []
common (value :: rest) other =
  if elem value other then value :: common rest other else common rest other

findPlainBinding : String -> List Statement -> Maybe Binding
findPlainBinding _ [] = Nothing
findPlainBinding wanted (SBinding binding :: rest) =
  if bindingNameOf binding == wanted then Just binding else findPlainBinding wanted rest
findPlainBinding wanted (SIf _ :: rest) = findPlainBinding wanted rest

||| Follow local dependencies with explicit fuel. Every IR binding has at most a
||| handful of operands, so eight work-list entries per preceding binding is a
||| conservative bound while keeping the pass total.
dependenciesWork : Nat -> List Statement -> List String -> List String -> List String
dependenciesWork Z _ _ _ = []
dependenciesWork (S fuel) _ _ [] = []
dependenciesWork (S fuel) statements seen (name :: rest) =
  if elem name seen
     then dependenciesWork fuel statements seen rest
     else case findPlainBinding name statements of
       Nothing => dependenciesWork fuel statements seen rest
       Just binding =>
         unique (name :: dependenciesWork fuel statements (name :: seen)
                                          (bindingLocals binding ++ rest))

operandDependencies : List Statement -> Operand ty -> List String
operandDependencies statements (OLocal name) =
  dependenciesWork (S (8 * length statements)) statements [] [name]
operandDependencies _ (OFloat _) = []
operandDependencies _ (OBool _) = []

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

worthStructuring : List Binding -> List Binding -> Bool
worthStructuring thenBody elseBody =
  bindingsCost thenBody + bindingsCost elseBody >= 4

tryStructured : List Statement -> Binding -> List Binding ->
                Maybe (List Statement, Statement)
tryStructured reversedStatements
              (MkBinding ty name (RSelect condition whenTrue whenFalse)) future =
  let thenDependencies = operandDependencies reversedStatements whenTrue
      elseDependencies = operandDependencies reversedStatements whenFalse
      shared = common thenDependencies elseDependencies
      thenExclusive = without thenDependencies shared
      elseExclusive = without elseDependencies shared
      claimed = unique (thenExclusive ++ elseExclusive)
      remaining = removeNamed claimed reversedStatements
      thenBody = bindingsNamedInOrder reversedStatements thenExclusive
      elseBody = bindingsNamedInOrder reversedStatements elseExclusive
   in if claimed == []
         then Nothing
         else if statementsUse claimed remaining
                 then Nothing
                 else if futureUses claimed future
                         then Nothing
                         else if not (worthStructuring thenBody elseBody)
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
public export
structureBindings : List Binding -> List Statement
structureBindings = structure []
