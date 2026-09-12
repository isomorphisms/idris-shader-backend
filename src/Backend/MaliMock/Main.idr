module Backend.MaliMock.Main

import Backend.MaliMock.Codegen
import Compiler.Common
import Idris.Driver

main : IO ()
main = mainWithCodegens [("mali-mock", maliMockCodegen)]
