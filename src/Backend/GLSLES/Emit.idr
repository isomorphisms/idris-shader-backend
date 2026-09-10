module Backend.GLSLES.Emit

import Backend.GLSLES.FloatSemantics
import Backend.GLSLES.IR
import Data.Fin
import Data.List
import Data.String

%default total

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

arrayElementSemanticType : ArrayElementTy -> String
arrayElementSemanticType AFloat = "F32"
arrayElementSemanticType ABool = "Bool"
arrayElementSemanticType AInt = "Int"
arrayElementSemanticType (AVec n) = "F32x" ++ show n

||| Semantic type spelling used in the checked IR dump. This deliberately does
||| not reuse GLSL's width-erasing `float` / `vecN` spelling.
semanticType : ValueTy -> String
semanticType TFloat = "F32"
semanticType TBool = "Bool"
semanticType TInt = "Int"
semanticType (TVec n) = "F32x" ++ show n
semanticType (TArray n elementTy) =
  arrayElementSemanticType elementTy ++ "[" ++ show n ++ "]"

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
dumpInterface (MkInterfaceVar name storage ty) =
  let storageText = case storage of
                         FragmentInput => "in"
                         Uniform => "uniform"
   in Right (name ++ " : " ++ storageText ++ " " ++ semanticType ty)

dumpBindingAt : String -> Binding -> Either String String
dumpBindingAt indent (MkBinding ty name rhs) =
  Right (indent ++ name ++ " : " ++ semanticType ty ++ " = " ++ rhsText [] rhs)

mutual
  dumpStatementAt : String -> Statement -> Either String (List String)
  dumpStatementAt indent (SBinding binding) = do
    line <- dumpBindingAt indent binding
    Right [line]
  dumpStatementAt indent (SIf ty name condition thenStatements thenResult elseStatements elseResult) = do
    thenLines <- dumpStatementsAt (indent ++ "  ") thenStatements
    elseLines <- dumpStatementsAt (indent ++ "  ") elseStatements
    let header = indent ++ name ++ " : " ++ semanticType ty ++
                 " = if " ++ operandText [] condition ++ " {"
        thenYield = indent ++ "  yield " ++ operandText [] thenResult
        elseHeader = indent ++ "} else {"
        elseYield = indent ++ "  yield " ++ operandText [] elseResult
        footer = indent ++ "}"
    Right (header :: thenLines ++ [thenYield, elseHeader] ++ elseLines ++ [elseYield, footer])
  dumpStatementAt indent
                  (SBoundedLoop ty name indexName stateName maximumIterations activeBound
                                initialState body bodyResult) = do
    bodyLines <- dumpStatementsAt (indent ++ "  ") body
    let activeText = case activeBound of
                          Nothing => ""
                          Just bound => " active < " ++ operandText [] bound
        header = indent ++ name ++ " : " ++ semanticType ty ++
                 " = bounded-loop " ++ indexName ++ " < " ++ show maximumIterations ++
                 activeText ++ " state " ++ stateName ++ " from " ++
                 operandText [] initialState ++ " {"
        bodyYield = indent ++ "  yield " ++ operandText [] bodyResult
        footer = indent ++ "}"
    Right (header :: bodyLines ++ [bodyYield, footer])

  dumpStatementsAt : String -> List Statement -> Either String (List String)
  dumpStatementsAt _ [] = Right []
  dumpStatementsAt indent (statement :: rest) = do
    first <- dumpStatementAt indent statement
    remaining <- dumpStatementsAt indent rest
    Right (first ++ remaining)

||| A stable, human-readable dump of the typed structured IR before GLSL CSE.
||| Floating-point widths are semantic names (F32/F32xN), not GLSL precision
||| qualifiers. Source branches and bounded loops remain visible as structure.
public export
dumpFragmentIR : FragmentProgram -> Either String String
dumpFragmentIR program = do
  arguments <- traverse dumpInterface (entryInterface (spec program))
  body <- dumpStatementsAt "" (statements program)
  let header = "fragment(" ++ concat (intersperse ", " arguments) ++ ") -> F32x4"
      output = "return " ++ operandText [] (result program)
  Right (unlines (header :: body ++ [output, ""]))

identityAlias : Aliases -> Rhs ty -> Maybe String
identityAlias aliases (RSelect condition (OBool True) (OBool False)) =
  Just (operandText aliases condition)
identityAlias _ _ = Nothing

mutual
  emitStatementBindingAt : String -> Binding -> List Statement -> Aliases -> Cache -> List String ->
                           Either String (Aliases, List String)
  emitStatementBindingAt indent (MkBinding ty name rhs) rest aliases cache reversedLines =
    case identityAlias aliases rhs of
      Just existing => emitStatementsAt indent rest ((name, existing) :: aliases) cache reversedLines
      Nothing => do
        renderedTy <- glslType ty
        let renderedRhs = rhsText aliases rhs
            key = renderedTy ++ ":" ++ renderedRhs
        case lookup key cache of
          Just existing =>
            emitStatementsAt indent rest ((name, existing) :: aliases) cache reversedLines
          Nothing =>
            let line = indent ++ renderedTy ++ " " ++ name ++ " = " ++ renderedRhs ++ ";"
             in emitStatementsAt indent rest ((name, name) :: aliases)
                                  ((key, name) :: cache) (line :: reversedLines)

  emitStructuredIfAt : String -> ValueTy -> String -> Operand TBool ->
                       List Statement -> Operand ty ->
                       List Statement -> Operand ty ->
                       List Statement -> Aliases -> Cache -> List String ->
                       Either String (Aliases, List String)
  emitStructuredIfAt indent ty name condition
                     thenStatements thenResult elseStatements elseResult
                     rest aliases cache reversedLines = do
    renderedTy <- glslType ty
    (thenAliases, thenLines) <-
      emitStatementsAt (indent ++ "  ") thenStatements aliases cache []
    (elseAliases, elseLines) <-
      emitStatementsAt (indent ++ "  ") elseStatements aliases cache []
    let conditionText = operandText aliases condition
        thenValue = operandText thenAliases thenResult
        elseValue = operandText elseAliases elseResult
        block =
          [ indent ++ renderedTy ++ " " ++ name ++ ";"
          , indent ++ "if (" ++ conditionText ++ ") {"
          ] ++ thenLines ++
          [ indent ++ "  " ++ name ++ " = " ++ thenValue ++ ";"
          , indent ++ "} else {"
          ] ++ elseLines ++
          [ indent ++ "  " ++ name ++ " = " ++ elseValue ++ ";"
          , indent ++ "}"
          ]
    emitStatementsAt indent rest ((name, name) :: aliases) cache
                     (reverse block ++ reversedLines)

  emitBoundedLoopAt : String -> ValueTy -> String -> String -> String -> Nat ->
                      Maybe (Operand TFloat) -> Operand ty ->
                      List Statement -> Operand ty ->
                      List Statement -> Aliases -> Cache -> List String ->
                      Either String (Aliases, List String)
  emitBoundedLoopAt indent ty name indexName stateName maximumIterations activeBound
                    initialState body bodyResult rest aliases cache reversedLines = do
    renderedTy <- glslType ty
    let rawIndexName = name ++ "_index"
        loopAliases =
          (indexName, "float(" ++ rawIndexName ++ ")") ::
          (stateName, name) :: aliases
    (bodyAliases, bodyLines) <-
      emitStatementsAt (indent ++ "  ") body loopAliases cache []
    let activeText = case activeBound of
                          Nothing => ""
                          Just bound =>
                            " && float(" ++ rawIndexName ++ ") < " ++ operandText aliases bound
        initialLine =
          indent ++ renderedTy ++ " " ++ name ++ " = " ++
          operandText aliases initialState ++ ";"
        loopHeader =
          indent ++ "for (int " ++ rawIndexName ++ " = 0; " ++ rawIndexName ++
          " < " ++ show maximumIterations ++ activeText ++ "; ++" ++ rawIndexName ++ ") {"
        updateLine = indent ++ "  " ++ name ++ " = " ++ operandText bodyAliases bodyResult ++ ";"
        footer = indent ++ "}"
        block = [initialLine, loopHeader] ++ bodyLines ++ [updateLine, footer]
    emitStatementsAt indent rest ((name, name) :: aliases) cache
                     (reverse block ++ reversedLines)

  emitStatementsAt : String -> List Statement -> Aliases -> Cache -> List String ->
                     Either String (Aliases, List String)
  emitStatementsAt _ [] aliases _ reversedLines = Right (aliases, reverse reversedLines)
  emitStatementsAt indent (SBinding binding :: rest) aliases cache reversedLines =
    emitStatementBindingAt indent binding rest aliases cache reversedLines
  emitStatementsAt indent (SIf ty name condition thenStatements thenResult elseStatements elseResult :: rest)
                   aliases cache reversedLines =
    emitStructuredIfAt indent ty name condition
                       thenStatements thenResult elseStatements elseResult
                       rest aliases cache reversedLines
  emitStatementsAt indent
                   (SBoundedLoop ty name indexName stateName maximumIterations activeBound
                                 initialState body bodyResult :: rest)
                   aliases cache reversedLines =
    emitBoundedLoopAt indent ty name indexName stateName maximumIterations activeBound
                      initialState body bodyResult rest aliases cache reversedLines

||| Emit deterministic GLSL ES 3.00 with an explicit default floating-point
||| precision. Structured source control flow is emitted directly from the
||| checked IR; it is not reconstructed from an eager linear select graph.
public export
emitFragmentWithPrecision : ShaderPrecision -> FragmentProgram -> Either String String
emitFragmentWithPrecision precision program = do
  declarations <- traverse declaration (entryInterface (spec program))
  (aliases, body) <- emitStatementsAt "  " (statements program) [] [] []
  let output = operandText aliases (result program)
      source =
        [ "#version 300 es"
        , "precision " ++ shaderPrecisionKeyword precision ++ " float;"
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

||| Default emission follows the current semantic-width policy. Callers whose
||| rendering contract tolerates lower precision may request it explicitly.
public export
emitFragment : FragmentProgram -> Either String String
emitFragment = emitFragmentWithPrecision (shaderPrecision defaultFloatWidth)
