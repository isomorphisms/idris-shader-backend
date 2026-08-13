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

backendError : String → Core a
backendError message = throw (GenericMsg emptyFC ("GLSL ES backend: " ++ message))

fromEither : Either String a → Core a
fromEither (Left message) = backendError message
fromEither (Right value) = pure value

findANF : Name → List (Name, ANFDef) → Maybe ANFDef
findANF _ [] = Nothing
findANF wanted ((name, definition) :: rest) =
  if wanted == name then Just definition else findANF wanted rest

entryType : {auto c : Ref Ctxt Defs} → Name → Core ClosedTerm
entryType name = do
  context <- get Ctxt
  found <- lookupCtxtExact name (gamma context)
  case found of
    Nothing ⇒ backendError ("could not recover the type of exported entry " ++ show name)
    Just global ⇒ toFullNames (type global)

writeShader : String → String → Core ()
writeShader path source = do
  result <- coreLift $ writeFile path source
  case result of
    Left error ⇒ backendError ("could not write " ++ path ++ ": " ++ show error)
    Right () ⇒ pure ()

directiveValue : String → List String → Maybe String
directiveValue _ [] = Nothing
directiveValue needle (value :: rest) =
  if isPrefixOf needle value
     then Just (pack (drop (length (unpack needle)) (unpack value)))
     else directiveValue needle rest

public export
compileGLSLES :
  Ref Ctxt Defs →
  Ref Syn SyntaxInfo →
  (tmpDir : String) → (outputDir : String) →
  ClosedTerm → (outfile : String) → Core (Maybe String)
compileGLSLES defs syn tmpDir outputDir term outfile = do
  cdata <- getCompileDataWith ["glsles"] False ANF term
  (resolvedName, annotation) <- case exported cdata of
    [] ⇒ backendError "no shader entry; add %export \"glsles:fragment|name=in,name=uniform\""
    [entry] ⇒ pure entry
    entries ⇒ backendError ("expected one glsles export, received " ++ show (length entries))
  entryName <- toFullNames resolvedName
  raw <- fromEither (parseRawEntry annotation)
  signature <- entryType entryName
  (argumentTypes, resultType) <- fromEither (shaderSignature signature)
  spec <- fromEither (makeEntrySpec raw argumentTypes resultType)
  Just definition <- pure (findANF entryName (anf cdata))
    | Nothing ⇒ backendError ("could not find ANF for exported entry " ++ show entryName)
  program <- fromEither (lowerFragment spec entryName (anf cdata) definition)
  session <- getSession
  case directiveValue "dump-ir=" (directives session) of
    Nothing ⇒ pure ()
    Just "" ⇒ backendError "dump-ir directive requires a path"
    Just path ⇒ do
      renderedIR <- fromEither (dumpFragmentIR program)
      writeShader path renderedIR
  source <- fromEither (emitFragment program)
  let output = outputDir ++ "/" ++ outfile ++ ".frag"
  writeShader output source
  pure (Just output)

public export
executeGLSLES :
  Ref Ctxt Defs →
  Ref Syn SyntaxInfo →
  (tmpDir : String) → ClosedTerm → Core ()
executeGLSLES defs syn tmpDir term =
  coreLift $ putStrLn "GLSL ES shaders are compiled, not executed by Idris2."

public export
glslesCodegen : Codegen
glslesCodegen = MkCG compileGLSLES executeGLSLES Nothing Nothing
