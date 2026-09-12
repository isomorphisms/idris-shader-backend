module Backend.MaliMock.Codegen

import Backend.GLSLES.Interface
import Backend.GLSLES.IR
import Backend.GLSLES.Lower
import Backend.GLSLES.Signature
import Backend.MaliMock.Emit
import Compiler.ANF
import Compiler.Common
import Core.Context
import Core.Core
import Core.FC
import Idris.Syntax
import System.File

%default covering

backendError : String -> Core a
backendError message = throw (GenericMsg emptyFC ("Mali mock backend: " ++ message))

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

writeMock : String -> String -> Core ()
writeMock path source = do
  result <- coreLift $ writeFile path source
  case result of
    Left error => backendError ("could not write " ++ path ++ ": " ++ show error)
    Right () => pure ()

public export
compileMaliMock :
  Ref Ctxt Defs ->
  Ref Syn SyntaxInfo ->
  (tmpDir : String) -> (outputDir : String) ->
  ClosedTerm -> (outfile : String) -> Core (Maybe String)
compileMaliMock defs syn tmpDir outputDir term outfile = do
  cdata <- getCompileDataWith ["mali-mock"] False ANF term
  (resolvedName, annotation) <- case exported cdata of
    [] => backendError "no shader entry; add %export \"mali-mock:fragment|name=in,name=uniform\""
    [entry] => pure entry
    entries => backendError ("expected one mali-mock export, received " ++ show (length entries))
  entryName <- toFullNames resolvedName
  raw <- fromEither (parseRawEntry annotation)
  signature <- entryType entryName
  (argumentTypes, resultType) <- fromEither (shaderSignature signature)
  spec <- fromEither (makeEntrySpec raw argumentTypes resultType)
  Just definition <- pure (findANF entryName (anf cdata))
    | Nothing => backendError ("could not find ANF for exported entry " ++ show entryName)
  program <- fromEither (lowerFragment spec entryName (anf cdata) definition)
  let output = outputDir ++ "/" ++ outfile ++ ".mali.mock"
  writeMock output (emitMaliMock program)
  pure (Just output)

public export
executeMaliMock :
  Ref Ctxt Defs ->
  Ref Syn SyntaxInfo ->
  (tmpDir : String) -> ClosedTerm -> Core ()
executeMaliMock defs syn tmpDir term =
  coreLift $ putStrLn "Mali mock output is pseudo-assembly and is not executable."

public export
maliMockCodegen : Codegen
maliMockCodegen = MkCG compileMaliMock executeMaliMock Nothing Nothing
