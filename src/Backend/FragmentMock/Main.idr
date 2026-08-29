module Backend.FragmentMock.Main

import Backend.FragmentMock.Codegen
import Backend.FragmentMock.Targets
import Compiler.Common
import Idris.Driver

mockCodegens : List (String, Codegen)
mockCodegens = map (\target => (codegenName target, fragmentMockCodegen target)) fragmentMockTargets

main : IO ()
main = mainWithCodegens mockCodegens
