module Backend.FragmentMock.Codegen

import Backend.FragmentMock.Emit
import Backend.FragmentMock.Targets
import Backend.GLSLES.Interface
import Backend.GLSLES.IR
import Backend.GLSLES.Lower
import Backend.GLSLES.Signature
import Compiler.ANF
import Compiler.Common
import Core.Context
import Core.Core
import Core.FC
import Idris.Syntax
import System.File

%default covering

backendError : MockTarget -> String -> Core a
backendError target message =
  throw (GenericMsg emptyFC (targetName target ++ " mock backend: " ++ message))

fromEither : MockTarget -> Either String a -> Core a
fromEither target (Left message) = backendError target message
fromEither _ (Right value) = pure value

findANF : Name -> List (Name, ANFDef) -> Maybe ANFDef
findANF _ [] = Nothing
findANF wanted ((name, definition) :: rest) =
  if wanted == name then Just definition else findANF wanted rest

entryType : {auto c : Ref Ctxt Defs} -> MockTarget -> Name -> Core ClosedTerm
entryType target name = do
  context <- get Ctxt
  found <- lookupCtxtExact name (gamma context)
  case found of
    Nothing => backendError target ("could not recover the type of exported entry " ++ show name)
    Just global => toFullNames (type global)

writeMock : MockTarget -> String -> String -> Core ()
writeMock target path source = do
  result <- coreLift $ writeFile path source
  case result of
    Left error => backendError target ("could not write " ++ path ++ ": " ++ show error)
    Right () => pure ()

public export
compileFragmentMock :
  MockTarget ->
  Ref Ctxt Defs ->
  Ref Syn SyntaxInfo ->
  (tmpDir : String) -> (outputDir : String) ->
  ClosedTerm -> (outfile : String) -> Core (Maybe String)
compileFragmentMock target defs syn tmpDir outputDir term outfile = do
  cdata <- getCompileDataWith [codegenName target] False ANF term
  (resolvedName, annotation) <- case exported cdata of
    [] => backendError target
      ("no shader entry; add %export \"" ++ codegenName target ++
       ":fragment|name=in,name=uniform\"")
    [entry] => pure entry
    entries => backendError target
      ("expected one " ++ codegenName target ++ " export, received " ++
       show (length entries))
  entryName <- toFullNames resolvedName
  raw <- fromEither target (parseRawEntry annotation)
  signature <- entryType target entryName
  (argumentTypes, resultType) <- fromEither target (shaderSignature signature)
  spec <- fromEither target (makeEntrySpec raw argumentTypes resultType)
  Just definition <- pure (findANF entryName (anf cdata))
    | Nothing => backendError target ("could not find ANF for exported entry " ++ show entryName)
  program <- fromEither target (lowerFragment spec entryName (anf cdata) definition)
  let output = outputDir ++ "/" ++ outfile ++ "." ++ codegenName target ++ ".frag.mock"
  writeMock target output (emitFragmentMock target program)
  pure (Just output)

public export
executeFragmentMock :
  MockTarget ->
  Ref Ctxt Defs ->
  Ref Syn SyntaxInfo ->
  (tmpDir : String) -> ClosedTerm -> Core ()
executeFragmentMock target defs syn tmpDir term =
  coreLift $ putStrLn
    (targetName target ++ " mock output is shared pseudo-assembly and is not executable.")

public export
fragmentMockCodegen : MockTarget -> Codegen
fragmentMockCodegen target =
  MkCG (compileFragmentMock target) (executeFragmentMock target) Nothing Nothing
