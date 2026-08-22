module Shader.Source

%default total

||| An opaque shader vector. Its width is checked by Idris while the GLSL ES
||| backend recovers the concrete width from the exported entry-point schema
||| and the primitive dataflow.
public export
data SVec : Nat -> Type where

public export %extern
vec2 : Double -> Double -> SVec 2

public export %extern
vec3 : Double -> Double -> Double -> SVec 3

public export %extern
vec4 : Double -> Double -> Double -> Double -> SVec 4

public export %extern
x : SVec (S n) -> Double

public export %extern
y : SVec (S (S n)) -> Double

public export %extern
z : SVec (S (S (S n))) -> Double

public export %extern
w : SVec (S (S (S (S n)))) -> Double

public export %extern
vadd : SVec n -> SVec n -> SVec n

public export %extern
vsub : SVec n -> SVec n -> SVec n

public export %extern
scale : Double -> SVec n -> SVec n

public export %extern
dot : SVec n -> SVec n -> Double

public export %extern
length : SVec n -> Double

public export %extern
normalize : SVec n -> SVec n

public export %extern
absF : Double -> Double

public export %extern
sqrtF : Double -> Double

public export %extern
sinF : Double -> Double

public export %extern
cosF : Double -> Double

public export %extern
floor_f : Double -> Double

public export %extern
fract_f : Double -> Double

public export %extern
log_f : Double -> Double

public export %extern
minF : Double -> Double -> Double

public export %extern
maxF : Double -> Double -> Double

public export %extern
atan2_f : Double -> Double -> Double

public export %extern
pow_f : Double -> Double -> Double

public export %extern
clampF : Double -> Double -> Double -> Double

public export %extern
mixF : Double -> Double -> Double -> Double

public export %extern
smoothstep_f : Double -> Double -> Double -> Double
