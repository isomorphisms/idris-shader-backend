module Backend.GLSLES.Main

import Backend.GLSLES.Codegen
import Compiler.Common
import Idris.Driver

main : IO ()
main = mainWithCodegens [("glsles", glslesCodegen)]
