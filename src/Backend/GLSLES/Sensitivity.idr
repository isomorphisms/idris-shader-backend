module Backend.GLSLES.Sensitivity

%default total

||| Physical vocabulary for local numerical sensitivity.
|||
||| A "shock" is a small perturbation: input uncertainty, rounding error,
||| quantization, or another small disturbance.  The local gain can come from
||| an absolute derivative, a Jacobian norm, a condition estimate, or another
||| justified bound.
|||
||| This is deliberately separate from F16/F32 policy.  Describing a region as
||| a shock amplifier or absorber does not itself authorize narrowing; backend
||| precision decisions still need explicit error bounds and tests.
public export
data ShockResponse
  = ShockAbsorber
  | ShockTransmitter
  | ShockAmplifier
  | ShockUnknown

||| Classify a first-order local perturbation gain.
|||
||| gain < 1 : disturbances shrink
||| gain = 1 : disturbances pass through at the same first-order magnitude
||| gain > 1 : disturbances grow
|||
||| NaN is left unknown rather than silently treated as neutral.
public export
classifyLocalGain : Double -> ShockResponse
classifyLocalGain gain =
  let magnitude = abs gain in
  if magnitude < 1.0
     then ShockAbsorber
     else if magnitude > 1.0
             then ShockAmplifier
             else if magnitude == 1.0
                     then ShockTransmitter
                     else ShockUnknown
