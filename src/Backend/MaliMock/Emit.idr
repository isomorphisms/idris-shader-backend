module Backend.MaliMock.Emit

import Backend.GLSLES.IR
import Data.Fin
import Data.String

%default total

floatLiteral : Double -> String
floatLiteral value = show value

operandText : Operand ty -> String
operandText (OLocal name) = "%" ++ name
operandText (OFloat value) = floatLiteral value
operandText (OBool True) = "true"
operandText (OBool False) = "false"

floatUnaryOp : FloatUnary -> String
floatUnaryOp FNeg = "fneg"
floatUnaryOp FAbs = "fabs"
floatUnaryOp FSqrt = "fsqrt"
floatUnaryOp FSin = "fsin"
floatUnaryOp FCos = "fcos"
floatUnaryOp FFloor = "ffloor"
floatUnaryOp FFract = "ffract"
floatUnaryOp FLog = "flog"

floatBinaryOp : FloatBinary -> String
floatBinaryOp FAdd = "fadd"
floatBinaryOp FSub = "fsub"
floatBinaryOp FMul = "fmul"
floatBinaryOp FDiv = "fdiv"
floatBinaryOp FMin = "fmin"
floatBinaryOp FMax = "fmax"
floatBinaryOp FAtan2 = "fatan2"
floatBinaryOp FPow = "fpow"

floatTernaryOp : FloatTernary -> String
floatTernaryOp FClamp = "fclamp"
floatTernaryOp FMix = "fmix"
floatTernaryOp FSmoothstep = "fsmoothstep"

comparisonOp : Comparison -> String
comparisonOp FLt = "fcmp.lt"
comparisonOp FLe = "fcmp.le"
comparisonOp FEq = "fcmp.eq"
comparisonOp FGe = "fcmp.ge"
comparisonOp FGt = "fcmp.gt"

vectorBinaryOp : VectorBinary -> String
vectorBinaryOp VAdd = "vadd"
vectorBinaryOp VSub = "vsub"

rhsText : Rhs ty -> String
rhsText (RFloatUnary operation value) =
  floatUnaryOp operation ++ " " ++ operandText value
rhsText (RFloatBinary operation left right) =
  floatBinaryOp operation ++ " " ++ operandText left ++ ", " ++ operandText right
rhsText (RFloatTernary operation first second third) =
  floatTernaryOp operation ++ " " ++ operandText first ++ ", " ++
  operandText second ++ ", " ++ operandText third
rhsText (RComparison operation left right) =
  comparisonOp operation ++ " " ++ operandText left ++ ", " ++ operandText right
rhsText (RBoolUnary BNot value) = "bnot " ++ operandText value
rhsText (RBoolBinary BAnd left right) =
  "band " ++ operandText left ++ ", " ++ operandText right
rhsText (RBoolBinary BOr left right) =
  "bor " ++ operandText left ++ ", " ++ operandText right
rhsText (RIntToFloat value) = "itof " ++ operandText value
rhsText (RArrayIndex array index) =
  "load.index " ++ operandText array ++ ", " ++ operandText index
rhsText (RVec2 x y) =
  "pack2 " ++ operandText x ++ ", " ++ operandText y
rhsText (RVec3 x y z) =
  "pack3 " ++ operandText x ++ ", " ++ operandText y ++ ", " ++ operandText z
rhsText (RVec4 x y z w) =
  "pack4 " ++ operandText x ++ ", " ++ operandText y ++ ", " ++
  operandText z ++ ", " ++ operandText w
rhsText (RVectorBinary operation left right) =
  vectorBinaryOp operation ++ " " ++ operandText left ++ ", " ++ operandText right
rhsText (RScale scalar vector) =
  "vscale " ++ operandText scalar ++ ", " ++ operandText vector
rhsText (RDot left right) =
  "vdot " ++ operandText left ++ ", " ++ operandText right
rhsText (RLength vector) = "vlength " ++ operandText vector
rhsText (RNormalize vector) = "vnormalize " ++ operandText vector
rhsText (RComponent index vector) =
  "extract " ++ operandText vector ++ ", " ++ show (finToNat index)
rhsText (RSelect condition whenTrue whenFalse) =
  "select " ++ operandText condition ++ ", " ++ operandText whenTrue ++ ", " ++
  operandText whenFalse

storageText : Storage -> String
storageText FragmentInput = "in"
storageText Uniform = "uniform"

interfaceLine : InterfaceVar -> String
interfaceLine (MkInterfaceVar name storage ty) =
  ".interface " ++ storageText storage ++ " %" ++ name ++ " : " ++ show ty

bindingLine : Binding -> String
bindingLine (MkBinding ty name rhs) =
  "  %" ++ name ++ " : " ++ show ty ++ " = " ++ rhsText rhs

||| Emit a deterministic, human-readable stand-in for a Mali backend.
|||
||| This is deliberately NOT Mali machine code.  It exists to exercise the
||| real shader front end, typed IR, and lowering boundary while a hardware
||| generation-specific emitter is absent.
public export
emitMaliMock : FragmentProgram -> String
emitMaliMock program =
  let header =
        [ "; MOCK MALI PSEUDO-ISA"
        , "; NOT EXECUTABLE -- no real Mali encoding, scheduling, or register allocation"
        , "; Real path through checked shader IR/lowering; mocked final emission only"
        , ".stage fragment"
        ]
      interface = map interfaceLine (entryInterface (spec program))
      body = map bindingLine (bindings program)
      output = "  store.frag_color " ++ operandText (result program)
   in unlines (header ++ interface ++ [".begin"] ++ body ++ [output, ".end", ""])
