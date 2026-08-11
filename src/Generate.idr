module Generate

import System
import System.File
import Shader.GLSLES
import Example.Sphere

writeOrFail : String -> String -> IO ()
writeOrFail path contents = do
  result <- writeFile path contents
  case result of
    Left error => do
      putStrLn ("could not write " ++ path ++ ": " ++ show error)
      exitFailure
    Right () => pure ()

main : IO ()
main = case sphereFragment of
  Left error => do
    putStrLn ("shader generation failed: " ++ error)
    exitFailure
  Right fragment => do
    writeOrFail "generated/fullscreen.vert" fullscreenVertex
    writeOrFail "generated/sphere.frag" fragment
    putStrLn "wrote generated/fullscreen.vert and generated/sphere.frag"

