module Test.Backend.BadResult

%default total

%export "glsles:fragment|u_time=uniform"
badResult : Double -> Double
badResult time = time

main : IO ()
main = pure ()

