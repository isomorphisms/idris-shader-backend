module Shader.GLSLES

import Data.List
import Data.String
import Shader.Types
import Shader.IR

%default total

public export
record FragmentShader (context : List ShaderTy) where
  constructor MkFragmentShader
  schema : Schema context
  color : Expr context TVec4

record CG a where
  constructor MkCG
  runCG : Nat -> List String -> List (String, String) ->
          (Nat, List String, List (String, String), a)

Functor CG where
  map f (MkCG action) = MkCG $ \next, lines, cache =>
    let (next', lines', cache', value) = action next lines cache
     in (next', lines', cache', f value)

Applicative CG where
  pure value = MkCG $ \next, lines, cache => (next, lines, cache, value)
  (MkCG function) <*> (MkCG argument) = MkCG $ \next, lines, cache =>
    let (next', lines', cache', f) = function next lines cache
        (next'', lines'', cache'', value) = argument next' lines' cache'
     in (next'', lines'', cache'', f value)

Monad CG where
  (MkCG action) >>= continuation = MkCG $ \next, lines, cache =>
    let (next', lines', cache', value) = action next lines cache
        MkCG following = continuation value
     in following next' lines' cache'

floatLiteral : Double -> String
floatLiteral value =
  let rendered = show value
      characters = unpack rendered
   in if elem '.' characters || elem 'e' characters || elem 'E' characters
         then rendered
         else rendered ++ ".0"

emitTemp : ShaderTy -> String -> CG String
emitTemp ty rightHandSide = MkCG $ \next, reversedLines, cache =>
  let key = glslType ty ++ ":" ++ rightHandSide
   in case Data.List.lookup key cache of
        Just existing => (next, reversedLines, cache, existing)
        Nothing =>
          let name = "_idris_t" ++ show next
              line = "  " ++ glslType ty ++ " " ++ name ++ " = " ++ rightHandSide ++ ";"
           in (S next, line :: reversedLines, (key, name) :: cache, name)

unary : ShaderTy -> String -> CG String -> CG String
unary resultTy operator value = do
  value' <- value
  emitTemp resultTy (operator ++ value')

binary : ShaderTy -> String -> CG String -> CG String -> CG String
binary resultTy operator left right = do
  left' <- left
  right' <- right
  emitTemp resultTy ("(" ++ left' ++ " " ++ operator ++ " " ++ right' ++ ")")

call1 : ShaderTy -> String -> CG String -> CG String
call1 resultTy function argument = do
  argument' <- argument
  emitTemp resultTy (function ++ "(" ++ argument' ++ ")")

call2 : ShaderTy -> String -> CG String -> CG String -> CG String
call2 resultTy function first second = do
  first' <- first
  second' <- second
  emitTemp resultTy (function ++ "(" ++ first' ++ ", " ++ second' ++ ")")

call3 : ShaderTy -> String -> CG String -> CG String -> CG String -> CG String
call3 resultTy function first second third = do
  first' <- first
  second' <- second
  third' <- third
  emitTemp resultTy
    (function ++ "(" ++ first' ++ ", " ++ second' ++ ", " ++ third' ++ ")")

swizzle : String -> CG String -> CG String
swizzle component value = do
  value' <- value
  emitTemp TFloat (value' ++ "." ++ component)

lower : {ty : ShaderTy} -> Schema context -> Expr context ty -> CG String
lower _      (FloatLit value) = pure (floatLiteral value)
lower _      (BoolLit True) = pure "true"
lower _      (BoolLit False) = pure "false"
lower schema (Var position) = pure (variableName schema position)

lower schema (Vec2 x y) = call2 TVec2 "vec2" (lower schema x) (lower schema y)
lower schema (Vec3 x y z) = call3 TVec3 "vec3" (lower schema x) (lower schema y)
                                             (lower schema z)
lower schema (Vec4 x y z w) = do
  x' <- lower schema x
  y' <- lower schema y
  z' <- lower schema z
  w' <- lower schema w
  emitTemp TVec4 ("vec4(" ++ x' ++ ", " ++ y' ++ ", " ++ z' ++ ", " ++ w' ++ ")")

lower schema (AddF left right) = binary TFloat "+" (lower schema left) (lower schema right)
lower schema (SubF left right) = binary TFloat "-" (lower schema left) (lower schema right)
lower schema (MulF left right) = binary TFloat "*" (lower schema left) (lower schema right)
lower schema (DivF left right) = binary TFloat "/" (lower schema left) (lower schema right)
lower schema (NegF value) = unary TFloat "-" (lower schema value)
lower schema (AbsF value) = call1 TFloat "abs" (lower schema value)
lower schema (SqrtF value) = call1 TFloat "sqrt" (lower schema value)
lower schema (SinF value) = call1 TFloat "sin" (lower schema value)
lower schema (CosF value) = call1 TFloat "cos" (lower schema value)
lower schema (MinF left right) = call2 TFloat "min" (lower schema left) (lower schema right)
lower schema (MaxF left right) = call2 TFloat "max" (lower schema left) (lower schema right)
lower schema (ClampF value low high) =
  call3 TFloat "clamp" (lower schema value) (lower schema low) (lower schema high)
lower schema (MixF left right weight) =
  call3 TFloat "mix" (lower schema left) (lower schema right) (lower schema weight)

lower schema (Add2 left right) = binary TVec2 "+" (lower schema left) (lower schema right)
lower schema (Sub2 left right) = binary TVec2 "-" (lower schema left) (lower schema right)
lower schema (Scale2 scalar value) = binary TVec2 "*" (lower schema scalar) (lower schema value)
lower schema (Dot2 left right) = call2 TFloat "dot" (lower schema left) (lower schema right)
lower schema (Length2 value) = call1 TFloat "length" (lower schema value)
lower schema (Normalize2 value) = call1 TVec2 "normalize" (lower schema value)

lower schema (Add3 left right) = binary TVec3 "+" (lower schema left) (lower schema right)
lower schema (Sub3 left right) = binary TVec3 "-" (lower schema left) (lower schema right)
lower schema (Scale3 scalar value) = binary TVec3 "*" (lower schema scalar) (lower schema value)
lower schema (Dot3 left right) = call2 TFloat "dot" (lower schema left) (lower schema right)
lower schema (Length3 value) = call1 TFloat "length" (lower schema value)
lower schema (Normalize3 value) = call1 TVec3 "normalize" (lower schema value)

lower schema (Add4 left right) = binary TVec4 "+" (lower schema left) (lower schema right)
lower schema (Sub4 left right) = binary TVec4 "-" (lower schema left) (lower schema right)
lower schema (Scale4 scalar value) = binary TVec4 "*" (lower schema scalar) (lower schema value)
lower schema (Dot4 left right) = call2 TFloat "dot" (lower schema left) (lower schema right)
lower schema (Length4 value) = call1 TFloat "length" (lower schema value)
lower schema (Normalize4 value) = call1 TVec4 "normalize" (lower schema value)

lower schema (X2 value) = swizzle "x" (lower schema value)
lower schema (Y2 value) = swizzle "y" (lower schema value)
lower schema (X3 value) = swizzle "x" (lower schema value)
lower schema (Y3 value) = swizzle "y" (lower schema value)
lower schema (Z3 value) = swizzle "z" (lower schema value)
lower schema (X4 value) = swizzle "x" (lower schema value)
lower schema (Y4 value) = swizzle "y" (lower schema value)
lower schema (Z4 value) = swizzle "z" (lower schema value)
lower schema (W4 value) = swizzle "w" (lower schema value)

lower schema (LtF left right) = binary TBool "<" (lower schema left) (lower schema right)
lower schema (LeF left right) = binary TBool "<=" (lower schema left) (lower schema right)
lower schema (EqF left right) = binary TBool "==" (lower schema left) (lower schema right)
lower schema (GeF left right) = binary TBool ">=" (lower schema left) (lower schema right)
lower schema (GtF left right) = binary TBool ">" (lower schema left) (lower schema right)
lower schema (AndB left right) = binary TBool "&&" (lower schema left) (lower schema right)
lower schema (OrB left right) = binary TBool "||" (lower schema left) (lower schema right)
lower schema (NotB value) = unary TBool "!" (lower schema value)
lower {ty} schema (Select condition whenTrue whenFalse) = do
  condition' <- lower schema condition
  true' <- lower schema whenTrue
  false' <- lower schema whenFalse
  emitTemp ty ("(" ++ condition' ++ " ? " ++ true' ++ " : " ++ false' ++ ")")

asciiLetter : Char -> Bool
asciiLetter character =
  (character >= 'a' && character <= 'z') ||
  (character >= 'A' && character <= 'Z')

identifierTail : Char -> Bool
identifierTail character = asciiLetter character || isDigit character || character == '_'

reservedWords : List String
reservedWords =
  [ "attribute", "const", "uniform", "varying", "buffer", "shared", "coherent"
  , "volatile", "restrict", "readonly", "writeonly", "atomic_uint", "layout"
  , "centroid", "flat", "smooth", "noperspective", "patch", "sample", "break"
  , "continue", "do", "for", "while", "switch", "case", "default", "if", "else"
  , "subroutine", "in", "out", "inout", "float", "double", "int", "void", "bool"
  , "true", "false", "invariant", "precise", "discard", "return", "mat2", "mat3"
  , "mat4", "dmat2", "dmat3", "dmat4", "mat2x2", "mat2x3", "mat2x4", "mat3x2"
  , "mat3x3", "mat3x4", "mat4x2", "mat4x3", "mat4x4", "vec2", "vec3", "vec4"
  , "ivec2", "ivec3", "ivec4", "bvec2", "bvec3", "bvec4", "uint", "uvec2"
  , "uvec3", "uvec4", "lowp", "mediump", "highp", "precision", "sampler2D"
  , "sampler3D", "samplerCube", "struct" ]

validateIdentifier : String -> Either String ()
validateIdentifier name = case unpack name of
  [] => Left "GLSL identifier cannot be empty"
  first :: rest =>
    if not (asciiLetter first || first == '_')
       then Left ("invalid first character in GLSL identifier: " ++ name)
       else if not (all identifierTail rest)
               then Left ("invalid character in GLSL identifier: " ++ name)
               else if Data.String.isPrefixOf "gl_" name
                       then Left ("GLSL reserves the gl_ prefix: " ++ name)
                       else if Data.String.isPrefixOf "_idris_" name
                               then Left ("backend reserves the _idris_ prefix: " ++ name)
                               else if elem name reservedWords
                                       then Left ("GLSL keyword used as identifier: " ++ name)
                                       else Right ()

validateSchema : Schema context -> Either String ()
validateSchema = validate []
  where
    validate : List String -> Schema remaining -> Either String ()
    validate _ Empty = Right ()
    validate seen (Declare _ _ name rest) = do
      validateIdentifier name
      if elem name seen
         then Left ("duplicate GLSL interface identifier: " ++ name)
         else validate (name :: seen) rest

declaration : ShaderTy -> Storage -> String -> String
declaration TBool FragmentInput name = "flat in bool " ++ name ++ ";"
declaration ty FragmentInput name = "in " ++ glslType ty ++ " " ++ name ++ ";"
declaration ty Uniform name = "uniform " ++ glslType ty ++ " " ++ name ++ ";"

declarations : Schema context -> List String
declarations Empty = []
declarations (Declare ty storage name rest) =
  declaration ty storage name :: declarations rest

||| Lower a typed fragment expression to scalar-temporary GLSL ES 3.00 source.
public export
compileFragment : FragmentShader context -> Either String String
compileFragment shader = do
  validateSchema (schema shader)
  let (_, reversedLines, _, result) = runCG (lower (schema shader) (color shader)) 0 [] []
      sourceLines =
        [ "#version 300 es"
        , "precision highp float;"
        , "precision highp int;"
        , ""
        ] ++ declarations (schema shader) ++
        [ "layout(location = 0) out vec4 _idris_fragColor;"
        , ""
        , "void main() {"
        ] ++ reverse reversedLines ++
        [ "  _idris_fragColor = " ++ result ++ ";"
        , "}"
        , ""
        ]
  Right (unlines sourceLines)

||| Matching full-screen-triangle vertex stage. `v_uv` ranges over NDC, so a
||| fragment program can use it directly as a two-dimensional slice coordinate.
public export
fullscreenVertex : String
fullscreenVertex = unlines
  [ "#version 300 es"
  , "precision highp float;"
  , "precision highp int;"
  , ""
  , "const vec2 POSITIONS[3] = vec2[3]("
  , "  vec2(-1.0, -1.0),"
  , "  vec2( 3.0, -1.0),"
  , "  vec2(-1.0,  3.0)"
  , ");"
  , "out vec2 v_uv;"
  , ""
  , "void main() {"
  , "  vec2 position = POSITIONS[gl_VertexID];"
  , "  v_uv = position;"
  , "  gl_Position = vec4(position, 0.0, 1.0);"
  , "}"
  , ""
  ]
