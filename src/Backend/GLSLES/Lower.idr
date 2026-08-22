module Backend.GLSLES.Lower

import Backend.GLSLES.IR
import Compiler.ANF
import Core.Name
import Core.TT
import Data.Fin
import Data.List
import Data.Vect
import Decidable.Equality

%default covering

Env : Type
Env = List (Int, SomeOperand)

public export
ShaderDefs : Type
ShaderDefs = List (Name, ANFDef)

record LowerState where
  constructor MkLowerState
  nextTemp : Nat
  reversedBindings : List Binding

record Lower a where
  constructor MkLower
  runLower : LowerState -> Either String (LowerState, a)

Functor Lower where
  map function (MkLower action) = MkLower $ \state => do
    (state', value) <- action state
    Right (state', function value)

Applicative Lower where
  pure value = MkLower $ \state => Right (state, value)
  (MkLower function) <*> (MkLower argument) = MkLower $ \state => do
    (state', f) <- function state
    (state'', value) <- argument state'
    Right (state'', f value)

Monad Lower where
  (MkLower action) >>= continuation = MkLower $ \state => do
    (state', value) <- action state
    runLower (continuation value) state'

failLower : String -> Lower a
failLower message = MkLower $ \_ => Left message

liftEither : Either String a -> Lower a
liftEither (Left message) = failLower message
liftEither (Right value) = pure value

emit : {ty : ValueTy} -> Rhs ty -> Lower (Operand ty)
emit {ty} rhs = MkLower $ \state =>
  let name = "_idris_t" ++ show (nextTemp state)
      binding = MkBinding ty name rhs
      state' = MkLowerState (S (nextTemp state))
                            (binding :: reversedBindings state)
   in Right (state', OLocal name)

lookupLocal : Int -> Env -> Either String SomeOperand
lookupLocal variable [] = Left ("unbound ANF local v" ++ show variable)
lookupLocal variable ((candidate, value) :: rest) =
  if variable == candidate then Right value else lookupLocal variable rest

resolveVar : Env -> AVar -> Either String SomeOperand
resolveVar _ ANull = Left "erased value used at runtime in shader code"
resolveVar env (ALocal variable) = lookupLocal variable env

resolveRuntimeArgs : Env -> List AVar -> Either String (List SomeOperand)
resolveRuntimeArgs _ [] = Right []
resolveRuntimeArgs env (ANull :: rest) = resolveRuntimeArgs env rest
resolveRuntimeArgs env (variable :: rest) = do
  value <- resolveVar env variable
  values <- resolveRuntimeArgs env rest
  Right (value :: values)

expectFloat : SomeOperand -> Either String (Operand TFloat)
expectFloat = expect TFloat

expectBool : SomeOperand -> Either String (Operand TBool)
expectBool = expect TBool

record VectorPair where
  constructor PackVectorPair
  pairWidth : Nat
  leftVector : Operand (TVec pairWidth)
  rightVector : Operand (TVec pairWidth)

matchingVectors : SomeOperand -> SomeOperand -> Either String VectorPair
matchingVectors left right = do
  PackVector n left' <- expectVector left
  PackVector m right' <- expectVector right
  case decEq n m of
    Yes Refl => Right (PackVectorPair n left' right')
    No _ => Left ("vector width mismatch: vec" ++ show n ++ " and vec" ++ show m)

one : String -> List SomeOperand -> Either String SomeOperand
one _ [value] = Right value
one operation values =
  Left (operation ++ " expects one runtime argument, received " ++ show (length values))

two : String -> List SomeOperand -> Either String (SomeOperand, SomeOperand)
two _ [left, right] = Right (left, right)
two operation values =
  Left (operation ++ " expects two runtime arguments, received " ++ show (length values))

three : String -> List SomeOperand ->
        Either String (SomeOperand, SomeOperand, SomeOperand)
three _ [first, second, third] = Right (first, second, third)
three operation values =
  Left (operation ++ " expects three runtime arguments, received " ++ show (length values))

four : String -> List SomeOperand ->
       Either String (SomeOperand, SomeOperand, SomeOperand, SomeOperand)
four _ [first, second, third, fourth] = Right (first, second, third, fourth)
four operation values =
  Left (operation ++ " expects four runtime arguments, received " ++ show (length values))

floatUnary : String -> FloatUnary -> List SomeOperand -> Lower SomeOperand
floatUnary operation constructor values = do
  value <- liftEither (one operation values >>= expectFloat)
  result <- emit (RFloatUnary constructor value)
  pure (PackOperand TFloat result)

floatBinary : String -> FloatBinary -> List SomeOperand -> Lower SomeOperand
floatBinary operation constructor values = do
  (left, right) <- liftEither (two operation values)
  left' <- liftEither (expectFloat left)
  right' <- liftEither (expectFloat right)
  result <- emit (RFloatBinary constructor left' right')
  pure (PackOperand TFloat result)

floatTernary : String -> FloatTernary -> List SomeOperand -> Lower SomeOperand
floatTernary operation constructor values = do
  (first, second, third) <- liftEither (three operation values)
  first' <- liftEither (expectFloat first)
  second' <- liftEither (expectFloat second)
  third' <- liftEither (expectFloat third)
  result <- emit (RFloatTernary constructor first' second' third')
  pure (PackOperand TFloat result)

comparison : String -> Comparison -> List SomeOperand -> Lower SomeOperand
comparison operation constructor values = do
  (left, right) <- liftEither (two operation values)
  left' <- liftEither (expectFloat left)
  right' <- liftEither (expectFloat right)
  result <- emit (RComparison constructor left' right')
  pure (PackOperand TBool result)

lowerPrim : Env -> PrimFn arity -> List AVar -> Lower SomeOperand
lowerPrim env primitive arguments = do
  values <- liftEither (resolveRuntimeArgs env arguments)
  case primitive of
    Add DoubleType => floatBinary "+" FAdd values
    Sub DoubleType => floatBinary "-" FSub values
    Mul DoubleType => floatBinary "*" FMul values
    Div DoubleType => floatBinary "/" FDiv values
    Neg DoubleType => floatUnary "negate" FNeg values
    LT DoubleType => comparison "<" FLt values
    LTE DoubleType => comparison "<=" FLe values
    EQ DoubleType => comparison "==" FEq values
    GTE DoubleType => comparison ">=" FGe values
    GT DoubleType => comparison ">" FGt values
    DoubleSin => floatUnary "sin" FSin values
    DoubleCos => floatUnary "cos" FCos values
    DoubleSqrt => floatUnary "sqrt" FSqrt values
    other => failLower ("unsupported Idris primitive in shader: " ++ show other)

component : String -> Nat -> List SomeOperand -> Lower SomeOperand
component operation index values = do
  value <- liftEither (one operation values)
  PackVector n vector <- liftEither (expectVector value)
  Just position <- pure (natToFin index n)
    | Nothing => failLower (operation ++ " is invalid for vec" ++ show n)
  result <- emit (RComponent position vector)
  pure (PackOperand TFloat result)

vectorConstructor2 : List SomeOperand -> Lower SomeOperand
vectorConstructor2 values = do
  (x, y) <- liftEither (two "vec2" values)
  x' <- liftEither (expectFloat x)
  y' <- liftEither (expectFloat y)
  result <- emit (RVec2 x' y')
  pure (PackOperand (TVec 2) result)

vectorConstructor3 : List SomeOperand -> Lower SomeOperand
vectorConstructor3 values = do
  (x, y, z) <- liftEither (three "vec3" values)
  x' <- liftEither (expectFloat x)
  y' <- liftEither (expectFloat y)
  z' <- liftEither (expectFloat z)
  result <- emit (RVec3 x' y' z')
  pure (PackOperand (TVec 3) result)

vectorConstructor4 : List SomeOperand -> Lower SomeOperand
vectorConstructor4 values = do
  (x, y, z, w) <- liftEither (four "vec4" values)
  x' <- liftEither (expectFloat x)
  y' <- liftEither (expectFloat y)
  z' <- liftEither (expectFloat z)
  w' <- liftEither (expectFloat w)
  result <- emit (RVec4 x' y' z' w')
  pure (PackOperand (TVec 4) result)

vectorBinary : String -> VectorBinary -> List SomeOperand -> Lower SomeOperand
vectorBinary operation constructor values = do
  (left, right) <- liftEither (two operation values)
  PackVectorPair n left' right' <- liftEither (matchingVectors left right)
  result <- emit (RVectorBinary constructor left' right')
  pure (PackOperand (TVec n) result)

vectorScale : List SomeOperand -> Lower SomeOperand
vectorScale values = do
  (scalar, vector) <- liftEither (two "scale" values)
  scalar' <- liftEither (expectFloat scalar)
  PackVector n vector' <- liftEither (expectVector vector)
  result <- emit (RScale scalar' vector')
  pure (PackOperand (TVec n) result)

vectorDot : List SomeOperand -> Lower SomeOperand
vectorDot values = do
  (left, right) <- liftEither (two "dot" values)
  PackVectorPair _ left' right' <- liftEither (matchingVectors left right)
  result <- emit (RDot left' right')
  pure (PackOperand TFloat result)

vectorLength : List SomeOperand -> Lower SomeOperand
vectorLength values = do
  value <- liftEither (one "length" values)
  PackVector _ vector <- liftEither (expectVector value)
  result <- emit (RLength vector)
  pure (PackOperand TFloat result)

vectorNormalize : List SomeOperand -> Lower SomeOperand
vectorNormalize values = do
  value <- liftEither (one "normalize" values)
  PackVector n vector <- liftEither (expectVector value)
  result <- emit (RNormalize vector)
  pure (PackOperand (TVec n) result)

lowerExtPrim : Env -> Name -> List AVar -> Lower SomeOperand
lowerExtPrim env primitive arguments = do
  values <- liftEither (resolveRuntimeArgs env arguments)
  case nameRoot primitive of
    "vec2" => vectorConstructor2 values
    "vec3" => vectorConstructor3 values
    "vec4" => vectorConstructor4 values
    "x" => component "x" 0 values
    "y" => component "y" 1 values
    "z" => component "z" 2 values
    "w" => component "w" 3 values
    "vadd" => vectorBinary "vadd" VAdd values
    "vsub" => vectorBinary "vsub" VSub values
    "scale" => vectorScale values
    "dot" => vectorDot values
    "length" => vectorLength values
    "normalize" => vectorNormalize values
    "absF" => floatUnary "absF" FAbs values
    "sqrtF" => floatUnary "sqrtF" FSqrt values
    "sinF" => floatUnary "sinF" FSin values
    "cosF" => floatUnary "cosF" FCos values
    "floorF" => floatUnary "floorF" FFloor values
    "fractF" => floatUnary "fractF" FFract values
    "logF" => floatUnary "logF" FLog values
    "minF" => floatBinary "minF" FMin values
    "maxF" => floatBinary "maxF" FMax values
    "atan2F" => floatBinary "atan2F" FAtan2 values
    "powF" => floatBinary "powF" FPow values
    "clampF" => floatTernary "clampF" FClamp values
    "mixF" => floatTernary "mixF" FMix values
    "smoothstepF" => floatTernary "smoothstepF" FSmoothstep values
    other => failLower ("unsupported external primitive in shader: " ++ show primitive)

findDef : Name -> ShaderDefs -> Maybe ANFDef
findDef _ [] = Nothing
findDef wanted ((name, definition) :: rest) =
  if wanted == name then Just definition else findDef wanted rest

bindArguments : List Int -> List SomeOperand -> Either String Env
bindArguments [] [] = Right []
bindArguments (parameter :: params) (value :: values) = do
  rest <- bindArguments params values
  Right ((parameter, value) :: rest)
bindArguments params values =
  Left ("function expected " ++ show (length params) ++
        " runtime arguments, received " ++ show (length values))

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

selectOperands : Operand TBool -> SomeOperand -> SomeOperand -> Lower SomeOperand
selectOperands condition (PackOperand TBool (OBool True))
                         (PackOperand TBool (OBool False)) =
  pure (PackOperand TBool condition)
selectOperands condition (PackOperand leftTy left) (PackOperand rightTy right) =
  case decEq leftTy rightTy of
    Yes Refl => do
      result <- emit (RSelect condition left right)
      pure (PackOperand leftTy result)
    No _ => failLower ("case branches have different shader types: " ++
                       show leftTy ++ " and " ++ show rightTy)

mutual
  lowerCall : ShaderDefs -> List Name -> Env -> Name -> List AVar -> Lower SomeOperand
  lowerCall definitions stack env name arguments = do
    if elem name stack
       then failLower ("recursive shader call is not supported: " ++ show name)
       else pure ()
    values <- liftEither (resolveRuntimeArgs env arguments)
    Just definition <- pure (findDef name definitions)
      | Nothing => failLower ("shader calls unknown definition " ++ show name)
    case definition of
      MkAFun params body => do
        callEnv <- liftEither (bindArguments params values)
        lowerANF definitions (name :: stack) callEnv body
      _ => failLower ("shader call does not name a first-order function: " ++ show name)

  lowerConstCase : ShaderDefs -> List Name -> Env -> AVar ->
                   List AConstAlt -> Maybe ANF -> Lower SomeOperand
  lowerConstCase definitions stack env scrutinee alternatives defaultBranch = do
    conditionValue <- liftEither (resolveVar env scrutinee)
    condition <- liftEither (expectBool conditionValue)
    let falseBranch = case findConstBranch False alternatives of
                           Just body => Just body
                           Nothing => defaultBranch
    let trueBranch = case findConstBranch True alternatives of
                          Just body => Just body
                          Nothing => defaultBranch
    Just falseBody <- pure falseBranch
      | Nothing => failLower "boolean case has no false/default branch"
    Just trueBody <- pure trueBranch
      | Nothing => failLower "boolean case has no true/default branch"
    falseValue <- lowerANF definitions stack env falseBody
    trueValue <- lowerANF definitions stack env trueBody
    selectOperands condition trueValue falseValue

  lowerConCase : ShaderDefs -> List Name -> Env -> AVar ->
                 List AConAlt -> Maybe ANF -> Lower SomeOperand
  lowerConCase definitions stack env scrutinee alternatives defaultBranch = do
    conditionValue <- liftEither (resolveVar env scrutinee)
    condition <- liftEither (expectBool conditionValue)
    let falseBranch = case findConBranch False alternatives of
                           Just body => Just body
                           Nothing => defaultBranch
    let trueBranch = case findConBranch True alternatives of
                          Just body => Just body
                          Nothing => defaultBranch
    Just falseBody <- pure falseBranch
      | Nothing => failLower "boolean case has no false/default branch"
    Just trueBody <- pure trueBranch
      | Nothing => failLower "boolean case has no true/default branch"
    falseValue <- lowerANF definitions stack env falseBody
    trueValue <- lowerANF definitions stack env trueBody
    selectOperands condition trueValue falseValue

  lowerANF : ShaderDefs -> List Name -> Env -> ANF -> Lower SomeOperand
  lowerANF _ _ env (AV _ variable) = liftEither (resolveVar env variable)
  lowerANF _ _ _ (APrimVal _ (Db value)) = pure (PackOperand TFloat (OFloat value))
  lowerANF _ _ _ (APrimVal _ constant) =
    case boolConstant constant of
      Just value => pure (PackOperand TBool (OBool value))
      Nothing => failLower ("unsupported literal in shader: " ++ show constant)
  lowerANF definitions stack env (ALet _ variable value scope) = do
    lowered <- lowerANF definitions stack env value
    lowerANF definitions stack ((variable, lowered) :: env) scope
  lowerANF _ _ env (AOp _ _ primitive arguments) =
    lowerPrim env primitive (toList arguments)
  lowerANF _ _ env (AExtPrim _ _ primitive arguments) =
    lowerExtPrim env primitive arguments
  lowerANF definitions stack env (AAppName _ _ name arguments) =
    lowerCall definitions stack env name arguments
  lowerANF definitions stack env (AConstCase _ scrutinee alternatives defaultBranch) =
    lowerConstCase definitions stack env scrutinee alternatives defaultBranch
  lowerANF definitions stack env (AConCase _ scrutinee alternatives defaultBranch) =
    lowerConCase definitions stack env scrutinee alternatives defaultBranch
  lowerANF _ _ _ (ACon _ name _ _ []) = case nameRoot name of
    "False" => pure (PackOperand TBool (OBool False))
    "True" => pure (PackOperand TBool (OBool True))
    _ => failLower ("heap-shaped constructor values are not supported in shaders: " ++ show name)
  lowerANF _ _ _ (ACon _ name _ _ _) =
    failLower ("heap-shaped constructor values are not supported in shaders: " ++ show name)
  lowerANF _ _ _ (AUnderApp _ name _ _) =
    failLower ("partial application is not supported in shaders: " ++ show name)
  lowerANF _ _ _ (AApp _ _ _ _) =
    failLower "closure application is not supported in shaders"
  lowerANF _ _ _ (AErased _) = failLower "erased value used as shader result"
  lowerANF _ _ _ (ACrash _ message) = failLower ("shader contains a crash: " ++ message)

interfaceEnv : List Int -> List InterfaceVar -> Either String Env
interfaceEnv [] [] = Right []
interfaceEnv (parameter :: params) (MkInterfaceVar name _ ty :: variables) = do
  rest <- interfaceEnv params variables
  Right ((parameter, PackOperand ty (OLocal name)) :: rest)
interfaceEnv params variables =
  Left ("entry ANF has " ++ show (length params) ++
        " arguments, but its checked Idris signature has " ++ show (length variables))

public export
lowerFragment : EntrySpec -> Name -> ShaderDefs -> ANFDef ->
                Either String FragmentProgram
lowerFragment spec entryName definitions (MkAFun params body) = do
  env <- interfaceEnv params (entryInterface spec)
  let initial = MkLowerState 0 []
  (final, value) <- runLower (lowerANF definitions [entryName] env body) initial
  output <- expect (TVec 4) value
  Right (MkFragmentProgram spec (reverse (reversedBindings final)) output)
lowerFragment _ entryName _ _ =
  Left ("exported shader entry is not a function: " ++ show entryName)
