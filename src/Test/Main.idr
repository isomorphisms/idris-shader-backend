module Test.Main

import Data.List.Elem
import Data.String
import Data.Vect
import System
import System.File
import Shader.Types
import Shader.IR
import Shader.Eval
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

pointValues : Double → Double → Double → Values PointContext
pointValues x y z = VCons [x, y, z] VNil

approximately : Double → Double → Bool
approximately expected actual = abs (expected - actual) <= 0.000000001

approximatelyVect : Vect n Double → Vect n Double → Bool
approximatelyVect [] [] = True
approximatelyVect (x :: xs) (y :: ys) = approximately x y && approximatelyVect xs ys

record TestResult where
  constructor MkTestResult
  label : String
  passed : Bool

showResult : TestResult → IO ()
showResult result =
  putStrLn ((if passed result then "PASS  " else "FAIL  ") ++ label result)

shaderTests : String → List TestResult
shaderTests source =
  [ MkTestResult "GLSL ES version directive" (Data.String.isPrefixOf "#version 300 es" source)
  , MkTestResult "typed fragment input declaration" (Data.String.isInfixOf "in vec2 v_uv;" source)
  , MkTestResult "typed uniform declaration" (Data.String.isInfixOf "uniform float u_time;" source)
  , MkTestResult "scalar temporary lowering" (Data.String.isInfixOf "float _idris_t0" source)
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
        Left _ ⇒ True
        Right _ ⇒ False

duplicateNameRejected : Bool
duplicateNameRejected =
  let badSchema : Schema [TFloat, TFloat]
      badSchema = Declare TFloat Uniform "same" $
                  Declare TFloat Uniform "same" Empty
      badShader : FragmentShader [TFloat, TFloat]
      badShader = MkFragmentShader badSchema
                    (Vec4 (FloatLit 0.0) (FloatLit 0.0) (FloatLit 0.0) (FloatLit 1.0))
   in case compileFragment badShader of
        Left _ ⇒ True
        Right _ ⇒ False

covering
goldenTest : String → IO TestResult
goldenTest generated = do
  file <- readFile "generated/sphere.frag"
  pure $ case file of
    Left _ ⇒ MkTestResult "checked-in fragment golden exists" False
    Right golden ⇒ MkTestResult "emitter matches checked-in fragment golden" (generated == golden)

covering
main : IO ()
main = case sphereFragment of
  Left error ⇒ do
    putStrLn ("FAIL  shader generation: " ++ error)
    exitFailure
  Right generated ⇒ do
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
          ] ++ shaderTests generated ++ [golden]
    traverse_ showResult tests
    if all passed tests
       then putStrLn (show (length tests) ++ " tests passed")
       else exitFailure
