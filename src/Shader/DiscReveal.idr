module Shader.DiscReveal

%default total

smaller : Double -> Double -> Double
smaller left right = if left < right then left else right

larger : Double -> Double -> Double
larger left right = if left > right then left else right

clamp_zero_one : Double -> Double
clamp_zero_one value = if value < 0.0 then 0.0 else if value > 1.0 then 1.0 else value

||| Alpha for a dark mask drawn over a supplied disc. The transition remains
||| inside the radius: the mathematical boundary and every point outside it
||| are fully obscured. A negative radius is the host sentinel for no mask.
public export
%noinline
disc_reveal_alpha : Double -> Double -> Double -> Double
disc_reveal_alpha distance radius requested_width =
  if radius < 0.0
     then 0.0
     else
       let safe_radius = larger 0.00001 radius
           safe_width = larger 0.00001 requested_width
           transition_width = smaller safe_radius safe_width
           transparent_radius = radius - transition_width
        in clamp_zero_one ((distance - transparent_radius) / transition_width)

||| Subtle dark gray for the unrevealed region. `crossing` is the product of
||| two sine waves and therefore lies between -1 and 1.
public export
%noinline
disc_reveal_gray : Double -> Double
disc_reveal_gray crossing =
  let weight = 0.5 + 0.5 * crossing
   in 0.035 * (1.0 - weight) + 0.055 * weight
