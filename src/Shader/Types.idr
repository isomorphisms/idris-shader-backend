module Shader.Types

import Data.List.Elem
import Data.Vect

%default total

||| The value types admitted by the small shader language.
public export
data ShaderTy
  = TFloat
  | TBool
  | TVec2
  | TVec3
  | TVec4

||| Idris meanings for shader value types. The evaluator uses these values as
||| its reference semantics.
public export
Sem : ShaderTy → Type
Sem TFloat = Double
Sem TBool  = Bool
Sem TVec2  = Vect 2 Double
Sem TVec3  = Vect 3 Double
Sem TVec4  = Vect 4 Double

||| A type-aligned environment. An expression can only retrieve a value whose
||| Idris type agrees with the corresponding shader variable.
public export
data Values : List ShaderTy → Type where
  VNil  : Values []
  VCons : Sem ty → Values rest → Values (ty :: rest)

public export
lookupValue : Elem ty context → Values context → Sem ty
lookupValue Here      (VCons value _)    = value
lookupValue (There p) (VCons _     rest) = lookupValue p rest

public export
data Storage = Uniform | FragmentInput

||| A GLSL interface whose list index is also the variable context used by the
||| expression IR. Names and types therefore cannot drift apart.
public export
data Schema : List ShaderTy → Type where
  Empty   : Schema []
  Declare : (ty : ShaderTy) → Storage → String → Schema rest →
            Schema (ty :: rest)

public export
variableName : Schema context → Elem ty context → String
variableName (Declare _ _ name _)    Here      = name
variableName (Declare _ _ _    rest) (There p) = variableName rest p

public export
glslType : ShaderTy → String
glslType TFloat = "float"
glslType TBool  = "bool"
glslType TVec2  = "vec2"
glslType TVec3  = "vec3"
glslType TVec4  = "vec4"

public export
schemaNames : Schema context → List String
schemaNames Empty = []
schemaNames (Declare _ _ name rest) = name :: schemaNames rest

