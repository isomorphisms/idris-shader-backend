module Test.Main

import Backend.GLSLES.FloatSemantics
import Data.List.Elem
import Data.String
import Data.Vect
import System
import System.File
import Shader.Types
import Shader.IR
import Shader.Eval
import Shader.DiscReveal
import Shader.Polynomial
import Shader.GLSLES
import Example.Sphere

%default total

PointContext : List ShaderTy
PointContext = [TVec3]

point : Expr PointContext TVec3
point = Var Here

sphereField : Expr PointContext TFloat
sphereField = polynomialExpr spherePolynomial point

sphereGradient : Expr PointContext TVec3
sphereGradient = gradientExpr spherePolynomial point

pointValues : Double -> Double -> Double -> Values PointContext
pointValues x y z = VCons [x, y, z] VNil

approximately : Double -> Double -> Bool
approximately expected actual = abs (expected - actual) <= 0.000000001

approximatelyVect : Vect n Double -> Vect n Double -> Bool
approximatelyVect [] [] = True
approximatelyVect (x :: xs) (y :: ys) = approximately x y && approximatelyVect xs ys

record TestResult where
  constructor MkTestResult
  label : String
  passed : Bool

showResult : TestResult -> IO ()
showResult result =
  putStrLn ((if passed result then "PASS  " else "FAIL  ") ++ label result)

floatSemanticsTests : List TestResult
floatSemanticsTests =
  [ MkTestResult "F16 and F32 are distinct semantic widths"
      (not (F16 == F32))
  , MkTestResult "F32 selects explicit highp scalar semantics"
      (glslScalarType F32 == "highp float")
  , MkTestResult "F16 selects mediump scalar lowering"
      (glslScalarType F16 == "mediump float")
  , MkTestResult "F16 and F32 scalar lowerings remain distinct"
      (glslScalarType F16 /= glslScalarType F32)
  , MkTestResult "F32 vec2 lowering preserves width"
      (glslVectorType F32 2 == Right "highp vec2")
  , MkTestResult "F32 vec3 lowering preserves width"
      (glslVectorType F32 3 == Right "highp vec3")
  , MkTestResult "F32 vec4 lowering preserves width"
      (glslVectorType F32 4 == Right "highp vec4")
  , MkTestResult "F16 vec2 lowering preserves width"
      (glslVectorType F16 2 == Right "mediump vec2")
  , MkTestResult "F16 vec3 lowering preserves width"
      (glslVectorType F16 3 == Right "mediump vec3")
  , MkTestResult "F16 vec4 lowering preserves width"
      (glslVectorType F16 4 == Right "mediump vec4")
  , MkTestResult "unsupported F16 vector width is rejected"
      (case glslVectorType F16 1 of
         Left _ => True
         Right _ => False)
  , MkTestResult "unsupported F32 vector width is rejected"
      (case glslVectorType F32 5 of
         Left _ => True
         Right _ => False)
  , MkTestResult "legacy production default remains explicit F32"
      (defaultFloatWidth == F32)
  , MkTestResult "portable GLES does not claim exact binary16"
      (not portableExactF16)
  , MkTestResult "generic GLES profile does not claim native mediump F16"
      (not (mediumpNativeF16 genericGLES))
  , MkTestResult "generic GLES profile does not claim vector F16"
      (not (vectorF16 genericGLES))
  , MkTestResult "PowerVR profile is named explicitly"
      (profileName powerVR == "powervr")
  , MkTestResult "PowerVR profile records native mediump F16"
      (mediumpNativeF16 powerVR)
  , MkTestResult "PowerVR profile records vector F16"
      (vectorF16 powerVR)
  , MkTestResult "PowerVR F16 policy selects mediump without changing F32"
      (precisionKeyword F16 == "mediump" && precisionKeyword F32 == "highp")
  ]

shaderTests : String -> List TestResult
shaderTests source =
  [ MkTestResult "GLSL ES version directive" (Data.String.isPrefixOf "#version 300 es" source)
  , MkTestResult "typed fragment input declaration" (Data.String.isInfixOf "in vec2 v_uv;" source)
  , MkTestResult "typed uniform declaration" (Data.String.isInfixOf "uniform float u_time;" source)
  , MkTestResult "scalar temporary lowering" (Data.String.isInfixOf "float _idris_t0" source)
  , MkTestResult "production float declaration is explicit F32/highp"
      (Data.String.isInfixOf "precision highp float;" source)
  , MkTestResult "F16 policy does not silently demote existing F32 shader"
      (not (Data.String.isInfixOf "precision mediump float;" source))
  , MkTestResult "integer powers are expanded" (not (Data.String.isInfixOf "pow(" source))
  , MkTestResult "fragment result is assigned" (Data.String.isInfixOf "_idris_fragColor =" source)
  ]

invalidNameRejected : Bool
invalidNameRejected =
  let badSchema : Schema [TFloat]
      badSchema = Declare TFloat Uniform "float" Empty
      badShader : FragmentShader [TFloat]
      badShader = MkFragmentShader badSchema
                    (Vec4 (FloatLit 0.0) (FloatLit 0.0) (FloatLit 0.0) (FloatLit 1.0))
   in case compileFragment badShader of
        Left _ => True
        Right _ => False

duplicateNameRejected : Bool
duplicateNameRejected =
  let badSchema : Schema [TFloat, TFloat]
      badSchema = Declare TFloat Uniform "same" $
                  Declare TFloat Uniform "same" Empty
      badShader : FragmentShader [TFloat, TFloat]
      badShader = MkFragmentShader badSchema
                    (Vec4 (FloatLit 0.0) (FloatLit 0.0) (FloatLit 0.0) (FloatLit 1.0))
   in case compileFragment badShader of
        Left _ => True
        Right _ => False

covering
goldenTest : String -> IO TestResult
goldenTest generated = do
  file <- readFile "generated/sphere.frag"
  pure $ case file of
    Left _ => MkTestResult "checked-in fragment golden exists" False
    Right golden => MkTestResult "emitter matches checked-in fragment golden" (generated == golden)

covering
main : IO ()
main = case sphereFragment of
  Left error => do
    putStrLn ("FAIL  shader generation: " ++ error)
    exitFailure
  Right generated => do
    golden <- goldenTest generated
    let tests =
          [ MkTestResult "sphere vanishes at (1,0,0)"
              (approximately 0.0 (eval (pointValues 1.0 0.0 0.0) sphereField))
          , MkTestResult "sphere is -1 at the origin"
              (approximately (-1.0) (eval (pointValues 0.0 0.0 0.0) sphereField))
          , MkTestResult "symbolic gradient at (1,0,0)"
              (approximatelyVect [2.0, 0.0, 0.0]
                                 (eval (pointValues 1.0 0.0 0.0) sphereGradient))
          , MkTestResult "symbolic gradient at (1,2,3)"
              (approximatelyVect [2.0, 4.0, 6.0]
                                 (eval (pointValues 1.0 2.0 3.0) sphereGradient))
          , MkTestResult "GLSL keyword rejected as variable name" invalidNameRejected
          , MkTestResult "duplicate interface name rejected" duplicateNameRejected
          , MkTestResult "negative disc radius removes the mask"
              (approximately 0.0 (disc_reveal_alpha 100.0 (-1.0) 0.1))
          , MkTestResult "disc interior is transparent"
              (approximately 0.0 (disc_reveal_alpha 0.5 1.0 0.1))
          , MkTestResult "disc fade stays inside the radius"
              (approximately 0.5 (disc_reveal_alpha 0.95 1.0 0.1))
          , MkTestResult "disc boundary is fully obscured"
              (approximately 1.0 (disc_reveal_alpha 1.0 1.0 0.1))
          , MkTestResult "disc exterior is fully obscured"
              (approximately 1.0 (disc_reveal_alpha 1.05 1.0 0.1))
          , MkTestResult "dark mask stays within its gray range"
              (approximately 0.035 (disc_reveal_gray (-1.0)) &&
               approximately 0.055 (disc_reveal_gray 1.0))
          ] ++ floatSemanticsTests ++ shaderTests generated ++ [golden]
    traverse_ showResult tests
    if all passed tests
       then putStrLn (show (length tests) ++ " tests passed")
       else exitFailure
