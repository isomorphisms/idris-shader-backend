module Backend.GLSLES.Interface

import Backend.GLSLES.IR
import Data.List
import Data.List1
import Data.String

%default total

public export
record InterfaceName where
  constructor MkInterfaceName
  sourceName : String
  sourceStorage : Storage

public export
record RawEntry where
  constructor MkRawEntry
  rawEntryName : String
  rawInterface : List InterfaceName

parts : Char → String → List String
parts delimiter value = forget (split (== delimiter) value)

asciiLetter : Char → Bool
asciiLetter character =
  (character >= 'a' && character <= 'z') ||
  (character >= 'A' && character <= 'Z')

identifierTail : Char → Bool
identifierTail character =
  asciiLetter character || isDigit character || character == '_'

reservedWords : List String
reservedWords =
  [ "attribute", "const", "uniform", "varying", "buffer", "shared", "coherent"
  , "volatile", "restrict", "readonly", "writeonly", "layout", "centroid"
  , "flat", "smooth", "noperspective", "patch", "sample", "break"
  , "continue", "do", "for", "while", "switch", "case", "default", "if"
  , "else", "subroutine", "in", "out", "inout", "float", "double", "int"
  , "void", "bool", "true", "false", "invariant", "precise", "discard"
  , "return", "mat2", "mat3", "mat4", "vec2", "vec3", "vec4", "ivec2"
  , "ivec3", "ivec4", "bvec2", "bvec3", "bvec4", "uint", "uvec2"
  , "uvec3", "uvec4", "lowp", "mediump", "highp", "precision"
  , "sampler2D", "sampler3D", "samplerCube", "struct" ]

public export
validateIdentifier : String → Either String ()
validateIdentifier value = case unpack value of
  [] ⇒ Left "GLSL identifier cannot be empty"
  first :: rest ⇒
    if not (asciiLetter first || first == '_')
       then Left ("invalid first character in GLSL identifier: " ++ value)
       else if not (all identifierTail rest)
               then Left ("invalid character in GLSL identifier: " ++ value)
               else if isPrefixOf "gl_" value
                       then Left ("GLSL reserves the gl_ prefix: " ++ value)
                       else if isPrefixOf "_idris_" value
                               then Left ("backend reserves the _idris_ prefix: " ++ value)
                               else if elem value reservedWords
                                       then Left ("GLSL keyword used as identifier: " ++ value)
                                       else Right ()

parseStorage : String → Either String Storage
parseStorage "in" = Right FragmentInput
parseStorage "uniform" = Right Uniform
parseStorage value =
  Left ("unknown interface storage '" ++ value ++ "'; expected in or uniform")

parseInterfaceName : String → Either String InterfaceName
parseInterfaceName value = case parts '=' value of
  [name, storage] ⇒ do
    validateIdentifier name
    kind <- parseStorage storage
    Right (MkInterfaceName name kind)
  _ ⇒ Left ("invalid interface item '" ++ value ++ "'; expected name=in or name=uniform")

firstDuplicate : List String → Maybe String
firstDuplicate [] = Nothing
firstDuplicate (x :: xs) =
  if elem x xs then Just x else firstDuplicate xs

||| Parse the non-type part of an export annotation. Types come from the Idris
||| signature, so an entry looks like:
|||   %export "glsles:fragment|v_uv=in,u_time=uniform"
public export
parseRawEntry : String → Either String RawEntry
parseRawEntry value = case parts '|' value of
  [stage, interfaceText] ⇒
    if stage /= "fragment"
       then Left "only fragment shader exports are supported"
       else do
         parsed <- if interfaceText == ""
                      then Right []
                      else traverse parseInterfaceName (parts ',' interfaceText)
         case firstDuplicate (map sourceName parsed) of
           Nothing ⇒ Right (MkRawEntry "fragment" parsed)
           Just name ⇒ Left ("duplicate GLSL interface name: " ++ name)
  _ ⇒ Left "invalid glsles export; expected fragment|name=in,name=uniform"

attach : List InterfaceName → List ValueTy → Either String (List InterfaceVar)
attach [] [] = Right []
attach (MkInterfaceName name storage :: names) (ty :: types) = do
  rest <- attach names types
  Right (MkInterfaceVar name storage ty :: rest)
attach names types =
  Left ("entry annotation describes " ++ show (length names) ++
        " arguments, but the Idris function has " ++ show (length types))

public export
makeEntrySpec : RawEntry → List ValueTy → ValueTy → Either String EntrySpec
makeEntrySpec raw argumentTypes resultType =
  let names = rawInterface raw in
  if length names /= length argumentTypes
     then Left ("entry annotation describes " ++ show (length names) ++
                " arguments, but the Idris function has " ++ show (length argumentTypes))
     else do
       variables <- attach names argumentTypes
       case resultType of
         TVec 4 ⇒ Right (MkEntrySpec (rawEntryName raw) variables resultType)
         _ ⇒ Left ("fragment entry must return SVec 4, received " ++ show resultType)
