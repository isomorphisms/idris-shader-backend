module Backend.GLSLES.FloatSemantics

%default total

||| Numerical width requested by shader semantics. This is deliberately
||| separate from CPU soft/softfp/hard ABI selection.
public export
data FloatWidth = F16 | F32

public export
Eq FloatWidth where
  F16 == F16 = True
  F32 == F32 = True
  _ == _ = False

public export
Show FloatWidth where
  show F16 = "F16"
  show F32 = "F32"

||| GLSL ES precision class used by the current lowering.
||| `Medium` is only a portable minimum-precision promise; a target profile
||| such as verified PowerVR may additionally establish native FP16 execution.
public export
data ShaderPrecision = Medium | High

public export
Eq ShaderPrecision where
  Medium == Medium = True
  High == High = True
  _ == _ = False

public export
Show ShaderPrecision where
  show Medium = "mediump"
  show High = "highp"

||| Current GLES lowering policy. F32 is the existing production path.
public export
shaderPrecision : FloatWidth -> ShaderPrecision
shaderPrecision F16 = Medium
shaderPrecision F32 = High

public export
precisionKeyword : FloatWidth -> String
precisionKeyword width = show (shaderPrecision width)

public export
glslScalarType : FloatWidth -> String
glslScalarType width = precisionKeyword width ++ " float"

public export
glslVectorType : FloatWidth -> Nat -> Either String String
glslVectorType width 2 = Right (precisionKeyword width ++ " vec2")
glslVectorType width 3 = Right (precisionKeyword width ++ " vec3")
glslVectorType width 4 = Right (precisionKeyword width ++ " vec4")
glslVectorType _ n = Left ("GLSL ES has no floating vector width " ++ show n)

public export
defaultFloatWidth : FloatWidth
defaultFloatWidth = F32

||| Portable GLES cannot infer exact binary16 merely from `mediump`.
||| A device/profile layer must establish stronger evidence before an exact
||| F16 claim is made.
public export
portableExactF16 : Bool
portableExactF16 = False

||| PowerVR documentation describes mediump shader variables as FP16. This is
||| a target capability fact, not a portable GLSL ES language guarantee.
public export
record FloatTargetProfile where
  constructor MkFloatTargetProfile
  profileName : String
  mediumpNativeF16 : Bool
  vectorF16 : Bool

public export
genericGLES : FloatTargetProfile
genericGLES = MkFloatTargetProfile "generic-gles" False False

public export
powerVR : FloatTargetProfile
powerVR = MkFloatTargetProfile "powervr" True True
