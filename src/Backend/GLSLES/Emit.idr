module Backend.GLSLES.Emit

import Backend.GLSLES.IR
import Backend.GLSLES.Structure
import Data.Fin
import Data.List
import Data.String

%default total

public export
data FloatPrecision = FloatHigh | FloatMedium

precisionText : FloatPrecision -> String
precisionText FloatHigh = "highp"
precisionText FloatMedium = "mediump"

arrayElementType : ArrayElementTy -> Either String String
arrayElementType AFloat = Right "float"
arrayElementType ABool = Right "bool"
arrayElementType AInt = Right "int"
arrayElementType (AVec 2) = Right "vec2"
arrayElementType (AVec 3) = Right "vec3"
arrayElementType (AVec 4) = Right "vec4"
arrayElementType (AVec n) = Left ("GLSL ES has no vec" ++ show n ++ " array element type")

public export
glslType : ValueTy -> Either String String
glslType TFloat = Right "float"
glslType TBool = Right "bool"
glslType TInt = Right "int"
glslType (TVec 2) = Right "vec2"
glslType (TVec 3) = Right "vec3"
glslType (TVec 4) = Right "vec4"
glslType (TVec n) = Left ("GLSL ES has no vec" ++ show n ++ " value type")
glslType (TArray n elementTy) = do
  rendered <- arrayElementType elementTy
  Right (rendered ++ "[" ++ show n ++ "]")

floatLiteral : Double -> String
floatLiteral value =
  let rendered = show value
      characters = unpack rendered
   in if elem '.' characters || elem 'e' characters || elem 'E' characters
         then rendered
         else rendered ++ ".0"

Aliases : Type
Aliases = List (String, String)

Cache : Type
Cache = List (String, String)

resolveAlias : Aliases -> String -> String
resolveAlias [] name = name
resolveAlias ((source, target) :: rest) name =
  if source == name then target else resolveAlias rest name

operandText : Aliases -> Operand ty -> String
operandText aliases (OLocal name) = resolveAlias aliases name
operandText _ (OFloat value) = floatLiteral value
operandText _ (OBool True) = "true"
operandText _ (OBool False) = "false"

floatUnaryText : FloatUnary -> String -> String
floatUnaryText FNeg value = "(-" ++ value ++ ")"
floatUnaryText FAbs value = "abs(" ++ value ++ ")"
floatUnaryText FSqrt value = "sqrt(" ++ value ++ ")"
floatUnaryText FSin value = "sin(" ++ value ++ ")"
floatUnaryText FCos value = "cos(" ++ value ++ ")"
floatUnaryText FFloor value = "floor(" ++ value ++ ")"
floatUnaryText FFract value = "fract(" ++ value ++ ")"
floatUnaryText FLog value = "log(" ++ value ++ ")"

floatBinaryText : FloatBinary -> String -> String -> String
floatBinaryText FAdd left right = "(" ++ left ++ " + " ++ right ++ ")"
floatBinaryText FSub left right = "(" ++ left ++ " - " ++ right ++ ")"
floatBinaryText FMul left right = "(" ++ left ++ " * " ++ right ++ ")"
floatBinaryText FDiv left right = "(" ++ left ++ " / " ++ right ++ ")"
floatBinaryText FMin left right = "min(" ++ left ++ ", " ++ right ++ ")"
floatBinaryText FMax left right = "max(" ++ left ++ ", " ++ right ++ ")"
floatBinaryText FAtan2 y x = "atan(" ++ y ++ ", " ++ x ++ ")"
floatBinaryText FPow base exponent = "pow(" ++ base ++ ", " ++ exponent ++ ")"

floatTernaryText : FloatTernary -> String -> String -> String -> String
floatTernaryText FClamp value low high =
  "clamp(" ++ value ++ ", " ++ low ++ ", " ++ high ++ ")"
floatTernaryText FMix left right weight =
  "mix(" ++ left ++ ", " ++ right ++ ", " ++ weight ++ ")"
floatTernaryText FSmoothstep low high value =
  "smoothstep(" ++ low ++ ", " ++ high ++ ", " ++ value ++ ")"

comparisonText : Comparison -> String -> String -> String
comparisonText FLt left right = "(" ++ left ++ " < " ++ right ++ ")"
comparisonText FLe left right = "(" ++ left ++ " <= " ++ right ++ ")"
comparisonText FEq left right = "(" ++ left ++ " == " ++ right ++ ")"
comparisonText FGe left right = "(" ++ left ++ " >= " ++ right ++ ")"
comparisonText FGt left right = "(" ++ left ++ " > " ++ right ++ ")"

componentText : Fin n -> String
componentText index = case finToNat index of
  0 => "x"
  1 => "y"
  2 => "z"
  _ => "w"

rhsText : Aliases -> Rhs ty -> String
rhsText aliases (RFloatUnary operation value) =
  floatUnaryText operation (operandText aliases value)
rhsText aliases (RFloatBinary operation left right) =
  floatBinaryText operation (operandText aliases left) (operandText aliases right)
rhsText aliases (RFloatTernary operation first second third) =
  floatTernaryText operation (operandText aliases first)
                             (operandText aliases second)
                             (operandText aliases third)
rhsText aliases (RComparison operation left right) =
  comparisonText operation (operandText aliases left) (operandText aliases right)
rhsText aliases (RBoolUnary BNot value) = "(!" ++ operandText aliases value ++ ")"
rhsText aliases (RBoolBinary BAnd left right) =
  "(" ++ operandText aliases left ++ " && " ++ operandText aliases right ++ ")"
rhsText aliases (RBoolBinary BOr left right) =
  "(" ++ operandText aliases left ++ " || " ++ operandText aliases right ++ ")"
rhsText aliases (RIntToFloat value) = "float(" ++ operandText aliases value ++ ")"
rhsText aliases (RArrayIndex array index) =
  operandText aliases array ++ "[int(" ++ operandText aliases index ++ ")]"
rhsText aliases (RVec2 x y) =
  "vec2(" ++ operandText aliases x ++ ", " ++ operandText aliases y ++ ")"
rhsText aliases (RVec3 x y z) =
  "vec3(" ++ operandText aliases x ++ ", " ++ operandText aliases y ++ ", " ++
  operandText aliases z ++ ")"
rhsText aliases (RVec4 x y z w) =
  "vec4(" ++ operandText aliases x ++ ", " ++ operandText aliases y ++ ", " ++
  operandText aliases z ++ ", " ++ operandText aliases w ++ ")"
rhsText aliases (RVectorBinary VAdd left right) =
  "(" ++ operandText aliases left ++ " + " ++ operandText aliases right ++ ")"
rhsText aliases (RVectorBinary VSub left right) =
  "(" ++ operandText aliases left ++ " - " ++ operandText aliases right ++ ")"
rhsText aliases (RScale scalar vector) =
  "(" ++ operandText aliases scalar ++ " * " ++ operandText aliases vector ++ ")"
rhsText aliases (RDot left right) =
  "dot(" ++ operandText aliases left ++ ", " ++ operandText aliases right ++ ")"
rhsText aliases (RLength vector) = "length(" ++ operandText aliases vector ++ ")"
rhsText aliases (RNormalize vector) = "normalize(" ++ operandText aliases vector ++ ")"
rhsText aliases (RComponent index vector) =
  operandText aliases vector ++ "." ++ componentText index
rhsText aliases (RSelect condition whenTrue whenFalse) =
  "(" ++ operandText aliases condition ++ " ? " ++ operandText aliases whenTrue ++
  " : " ++ operandText aliases whenFalse ++ ")"

declaration : InterfaceVar -> Either String String
declaration (MkInterfaceVar name FragmentInput (TArray _ _)) =
  Left ("fixed shader arrays must be uniforms: " ++ name)
declaration (MkInterfaceVar name FragmentInput TBool) =
  Right ("flat in bool " ++ name ++ ";")
declaration (MkInterfaceVar name FragmentInput TInt) =
  Right ("flat in int " ++ name ++ ";")
declaration (MkInterfaceVar name FragmentInput ty) = do
  rendered <- glslType ty
  Right ("in " ++ rendered ++ " " ++ name ++ ";")
declaration (MkInterfaceVar name Uniform (TArray n elementTy)) = do
  rendered <- arrayElementType elementTy
  Right ("uniform " ++ rendered ++ " " ++ name ++ "[" ++ show n ++ "];")
declaration (MkInterfaceVar name Uniform ty) = do
  rendered <- glslType ty
  Right ("uniform " ++ rendered ++ " " ++ name ++ ";")

dumpInterface : InterfaceVar -> Either String String
dumpInterface (MkInterfaceVar name storage ty) = do
  rendered <- glslType ty
  let storageText = case storage of
                         FragmentInput => "in"
                         Uniform => "uniform"
  Right (name ++ " : " ++ storageText ++ " " ++ rendered)

dumpBinding : Binding -> Either String String
dumpBinding (MkBinding ty name rhs) = do
  rendered <- glslType ty
  Right (name ++ " : " ++ rendered ++ " = " ++ rhsText [] rhs)

||| A stable, human-readable dump of the typed IR immediately before GLSL CSE
||| and structured-control-flow recovery.
public export
dumpFragmentIR : FragmentProgram -> Either String String
dumpFragmentIR program = do
  arguments <- traverse dumpInterface (entryInterface (spec program))
  body <- traverse dumpBinding (bindings program)
  let header = "fragment(" ++ concat (intersperse ", " arguments) ++ ") -> vec4"
      output = "return " ++ operandText [] (result program)
  Right (unlines (header :: body ++ [output, ""]))

identityAlias : Aliases -> Rhs ty -> Maybe String
identityAlias aliases (RSelect condition (OBool True) (OBool False)) =
  Just (operandText aliases condition)
identityAlias _ _ = Nothing

emitBindingsAt : String -> List Binding -> Aliases -> Cache -> List String ->
                 Either String (Aliases, List String)
emitBindingsAt _ [] aliases _ reversedLines = Right (aliases, reverse reversedLines)
emitBindingsAt indent (MkBinding ty name rhs :: rest) aliases cache reversedLines =
  case identityAlias aliases rhs of
    Just existing => emitBindingsAt indent rest ((name, existing) :: aliases) cache reversedLines
    Nothing => do
      renderedTy <- glslType ty
      let renderedRhs = rhsText aliases rhs
          key = renderedTy ++ ":" ++ renderedRhs
      case lookup key cache of
        Just existing =>
          emitBindingsAt indent rest ((name, existing) :: aliases) cache reversedLines
        Nothing =>
          let line = indent ++ renderedTy ++ " " ++ name ++ " = " ++ renderedRhs ++ ";"
           in emitBindingsAt indent rest ((name, name) :: aliases)
                                          ((key, name) :: cache) (line :: reversedLines)

mutual
  emitStatementBinding : Binding -> List Statement -> Aliases -> Cache -> List String ->
                         Either String (Aliases, List String)
  emitStatementBinding (MkBinding ty name rhs) rest aliases cache reversedLines =
    case identityAlias aliases rhs of
      Just existing => emitStatements rest ((name, existing) :: aliases) cache reversedLines
      Nothing => do
        renderedTy <- glslType ty
        let renderedRhs = rhsText aliases rhs
            key = renderedTy ++ ":" ++ renderedRhs
        case lookup key cache of
          Just existing => emitStatements rest ((name, existing) :: aliases) cache reversedLines
          Nothing =>
            let line = "  " ++ renderedTy ++ " " ++ name ++ " = " ++ renderedRhs ++ ";"
             in emitStatements rest ((name, name) :: aliases)
                                    ((key, name) :: cache) (line :: reversedLines)

  emitStructuredIf : StructuredIf -> List Statement -> Aliases -> Cache -> List String ->
                     Either String (Aliases, List String)
  emitStructuredIf branch rest aliases cache reversedLines = do
    renderedTy <- glslType (branchResultTy branch)
    (thenAliases, thenLines) <-
      emitBindingsAt "    " (thenBindings branch) aliases cache []
    (elseAliases, elseLines) <-
      emitBindingsAt "    " (elseBindings branch) aliases cache []
    let name = branchName branch
        condition = operandText aliases (branchCondition branch)
        thenValue = operandText thenAliases (thenResult branch)
        elseValue = operandText elseAliases (elseResult branch)
        block =
          [ "  " ++ renderedTy ++ " " ++ name ++ ";"
          , "  if (" ++ condition ++ ") {"
          ] ++ thenLines ++
          [ "    " ++ name ++ " = " ++ thenValue ++ ";"
          , "  } else {"
          ] ++ elseLines ++
          [ "    " ++ name ++ " = " ++ elseValue ++ ";"
          , "  }"
          ]
    emitStatements rest ((name, name) :: aliases) cache
                   (reverse block ++ reversedLines)

  emitStatements : List Statement -> Aliases -> Cache -> List String ->
                   Either String (Aliases, List String)
  emitStatements [] aliases _ reversedLines = Right (aliases, reverse reversedLines)
  emitStatements (SBinding binding :: rest) aliases cache reversedLines =
    emitStatementBinding binding rest aliases cache reversedLines
  emitStatements (SIf branch :: rest) aliases cache reversedLines =
    emitStructuredIf branch rest aliases cache reversedLines

||| Emit deterministic GLSL ES 3.00 with an explicit default floating-point
||| precision. Expensive, branch-local pure computations are recovered into
||| structured GLSL control flow; cheap selects stay as ternary expressions.
public export
emitFragmentWithPrecision : FloatPrecision -> FragmentProgram -> Either String String
emitFragmentWithPrecision precision program = do
  declarations <- traverse declaration (entryInterface (spec program))
  let statements = structureBindings (bindings program)
  (aliases, body) <- emitStatements statements [] [] []
  let output = operandText aliases (result program)
      source =
        [ "#version 300 es"
        , "precision " ++ precisionText precision ++ " float;"
        , "precision highp int;"
        , ""
        ] ++ declarations ++
        [ "layout(location = 0) out vec4 _idris_fragColor;"
        , ""
        , "void main() {"
        ] ++ body ++
        [ "  _idris_fragColor = " ++ output ++ ";"
        , "}"
        , ""
        ]
  Right (unlines source)

||| Emit deterministic GLSL ES 3.00. High precision remains the compatibility
||| default; target-specific callers must opt into narrower arithmetic explicitly.
public export
emitFragment : FragmentProgram -> Either String String
emitFragment = emitFragmentWithPrecision FloatHigh
