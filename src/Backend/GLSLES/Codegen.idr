module Backend.GLSLES.Codegen

import Backend.GLSLES.Emit
import Backend.GLSLES.Interface
import Backend.GLSLES.IR
import Backend.GLSLES.Lower
import Backend.GLSLES.Signature
import Compiler.ANF
import Compiler.Common
import Core.Context
import Core.Core
import Core.FC
import Core.Options
import Data.String
import Idris.Syntax
import System.File

%default covering

backendError : String -> Core a
backendError message = throw (GenericMsg emptyFC ("GLSL ES backend: " ++ message))

fromEither : Either String a -> Core a
fromEither (Left message) = backendError message
fromEither (Right value) = pure value

findANF : Name -> List (Name, ANFDef) -> Maybe ANFDef
findANF _ [] = Nothing
findANF wanted ((name, definition) :: rest) =
  if wanted == name then Just definition else findANF wanted rest

entryType : {auto c : Ref Ctxt Defs} -> Name -> Core ClosedTerm
entryType name = do
  context <- get Ctxt
  found <- lookupCtxtExact name (gamma context)
  case found of
    Nothing => backendError ("could not recover the type of exported entry " ++ show name)
    Just global => toFullNames (type global)

writeShader : String -> String -> Core ()
writeShader path source = do
  result <- coreLift $ writeFile path source
  case result of
    Left error => backendError ("could not write " ++ path ++ ": " ++ show error)
    Right () => pure ()

directiveValue : String -> List String -> Maybe String
directiveValue _ [] = Nothing
directiveValue needle (value :: rest) =
  if isPrefixOf needle value
     then Just (pack (drop (length (unpack needle)) (unpack value)))
     else directiveValue needle rest

||| Human reading guide for teaching shaders. These are GLSL comments and are
||| ignored by the GLSL compiler and PowerVR driver. The ordinary production
||| emitter remains unchanged unless explain-short-names=true is requested.
explanatoryHeader : String
explanatoryHeader = unlines
  [ "// Reading guide: these comments are for humans; the GLSL compiler ignores them."
  , "// glsles = OpenGL ES Shading Language; fragment = code run for each fragment/pixel candidate."
  , "// SVec n in the Idris source = shader vector with exactly n components."
  , "// NDC / v_ndc = normalized device coordinates, roughly -1 to +1 across the fullscreen fixture."
  , "// u_... = uniform value shared by fragments; v_... = interpolated fragment input naming convention."
  , "// vec2/vec3/vec4 = vectors with 2/3/4 components; a colour vec4 is red, green, blue, alpha."
  , "// x/y/z/w = first/second/third/fourth vector component."
  , "// vadd/vsub/scale = vector add/subtract/scale; dot = dot product; length = Euclidean length."
  , "// F suffix = floating-point helper: absF, sqrtF, minF, maxF, atan2F, powF, clampF, mixF, etc."
  , "// In emitted GLSL those become abs, sqrt, min, max, atan, pow, clamp, mix, and related built-ins."
  , "// _idris_t0, _idris_t1, ... = compiler-created temporary intermediate values."
  , ""
  ]

||| GLSL ES requires #version to be the first statement, before even comments.
||| Keep that line first and insert the opt-in reading guide immediately after it.
explainSource : String -> String
explainSource source =
  case lines source of
    [] => source
    version :: body => unlines (version :: (lines explanatoryHeader ++ body))

public export
compileGLSLES :
  Ref Ctxt Defs ->
  Ref Syn SyntaxInfo ->
  (tmpDir : String) -> (outputDir : String) ->
  ClosedTerm -> (outfile : String) -> Core (Maybe String)
compileGLSLES defs syn tmpDir outputDir term outfile = do
  cdata <- getCompileDataWith ["glsles"] False ANF term
  (resolvedName, annotation) <- case exported cdata of
    [] => backendError "no shader entry; add %export \"glsles:fragment|name=in,name=uniform\""
    [entry] => pure entry
    entries => backendError ("expected one glsles export, received " ++ show (length entries))
  entryName <- toFullNames resolvedName
  raw <- fromEither (parseRawEntry annotation)
  signature <- entryType entryName
  (argumentTypes, resultType) <- fromEither (shaderSignature signature)
  spec <- fromEither (makeEntrySpec raw argumentTypes resultType)
  Just definition <- pure (findANF entryName (anf cdata))
    | Nothing => backendError ("could not find ANF for exported entry " ++ show entryName)
  program <- fromEither (lowerFragment spec entryName (anf cdata) definition)
  session <- getSession
  case directiveValue "dump-ir=" (directives session) of
    Nothing => pure ()
    Just "" => backendError "dump-ir directive requires a path"
    Just path => do
      renderedIR <- fromEither (dumpFragmentIR program)
      writeShader path renderedIR
  emitted <- fromEither (emitFragment program)
  source <- case directiveValue "explain-short-names=" (directives session) of
    Nothing => pure emitted
    Just "false" => pure emitted
    Just "true" => pure (explainSource emitted)
    Just value => backendError
      ("explain-short-names directive expects true or false, received '" ++ value ++ "'")
  let output = outputDir ++ "/" ++ outfile ++ ".frag"
  writeShader output source
  pure (Just output)

public export
executeGLSLES :
  Ref Ctxt Defs ->
  Ref Syn SyntaxInfo ->
  (tmpDir : String) -> ClosedTerm -> Core ()
executeGLSLES defs syn tmpDir term =
  coreLift $ putStrLn "GLSL ES shaders are compiled, not executed by Idris2."

public export
glslesCodegen : Codegen
glslesCodegen = MkCG compileGLSLES executeGLSLES Nothing Nothing
