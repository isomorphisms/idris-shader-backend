module Backend.GLSLES.Codegen

import Backend.GLSLES.Emit
import Backend.GLSLES.FloatSemantics
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

floatPrecision : List String -> Either String ShaderPrecision
floatPrecision values = case directiveValue "float-precision=" values of
  Nothing => Right (shaderPrecision defaultFloatWidth)
  Just "lowp" => Right Low
  Just "mediump" => Right Medium
  Just "highp" => Right High
  Just "" => Left "float-precision directive requires lowp, mediump, or highp"
  Just value => Left ("float-precision must be lowp, mediump, or highp, received " ++ value)

requireSingleShaderExport : List (Name, String) -> Core (Name, String)
requireSingleShaderExport [] =
  backendError "no shader entry; add %export \"glsles:fragment|name=in,name=uniform\""
requireSingleShaderExport [entry] = pure entry
requireSingleShaderExport entries =
  backendError ("expected one glsles export, received " ++ show (length entries))

record ExportedShader where
  constructor MkExportedShader
  shaderEntryName : Name
  shaderExportAnnotation : String
  shaderDefinitions : ShaderDefs

prepareExportedShader : Ref Ctxt Defs -> ClosedTerm -> Core ExportedShader
prepareExportedShader defs term = do
  compilation <- getCompileDataWith {c = defs} ["glsles"] False ANF term
  (resolvedName, annotation) <- requireSingleShaderExport (exported compilation)
  entryName <- toFullNames resolvedName
  pure (MkExportedShader entryName annotation (anf compilation))

checkShaderInterface : Ref Ctxt Defs -> ExportedShader -> Core EntrySpec
checkShaderInterface defs shader = do
  raw <- fromEither (parseRawEntry (shaderExportAnnotation shader))
  signature <- entryType {c = defs} (shaderEntryName shader)
  (argumentTypes, resultType) <- fromEither (shaderSignature signature)
  fromEither (makeEntrySpec raw argumentTypes resultType)

lowerExportedShader : EntrySpec -> ExportedShader -> Core FragmentProgram
lowerExportedShader spec shader = do
  let entryName = shaderEntryName shader
  let definitions = shaderDefinitions shader
  Just definition <- pure (findANF entryName definitions)
    | Nothing => backendError ("could not find ANF for exported entry " ++ show entryName)
  fromEither (lowerFragment spec entryName definitions definition)

writeRequestedIR : Ref Ctxt Defs -> FragmentProgram -> Core ()
writeRequestedIR defs program = do
  session <- getSession {c = defs}
  case directiveValue "dump-ir=" (directives session) of
    Nothing => pure ()
    Just "" => backendError "dump-ir directive requires a path"
    Just path => do
      renderedIR <- fromEither (dumpFragmentIR program)
      writeShader path renderedIR

writeFragmentOutput : Ref Ctxt Defs -> String -> String -> FragmentProgram -> Core String
writeFragmentOutput defs outputDir outfile program = do
  session <- getSession {c = defs}
  precision <- fromEither (floatPrecision (directives session))
  source <- fromEither (emitFragmentWithPrecision precision program)
  let output = outputDir ++ "/" ++ outfile ++ ".frag"
  writeShader output source
  pure output

public export
compileGLSLES :
  Ref Ctxt Defs ->
  Ref Syn SyntaxInfo ->
  (tmpDir : String) -> (outputDir : String) ->
  ClosedTerm -> (outfile : String) -> Core (Maybe String)
compileGLSLES defs syn tmpDir outputDir term outfile = do
  shader <- prepareExportedShader defs term
  spec <- checkShaderInterface defs shader
  program <- lowerExportedShader spec shader
  writeRequestedIR defs program
  output <- writeFragmentOutput defs outputDir outfile program
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
