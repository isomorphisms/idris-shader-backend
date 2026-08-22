module Example.DiscReveal

import Shader.DiscReveal
import Shader.Source

%default total

%noinline
square : Double -> Double
square value = value * value

%noinline
dark_pattern : SVec 2 -> SVec 2 -> Double
dark_pattern ndc resolution =
  let pixel_x = 0.5 * (x ndc + 1.0) * x resolution
      pixel_y = 0.5 * (y ndc + 1.0) * y resolution
      crossing = sinF (0.173 * pixel_x) * sinF (0.137 * pixel_y)
   in disc_reveal_gray crossing

%export "glsles:fragment|v_ndc=in,u_center=uniform,u_half_height=uniform,u_aspect=uniform,u_disc_center=uniform,u_disc_radius=uniform,u_resolution=uniform"
disc_reveal :
  SVec 2 -> SVec 2 -> Double -> Double -> SVec 2 -> Double -> SVec 2 -> SVec 4
disc_reveal ndc center half_height aspect disc_center disc_radius resolution =
  let world_x = x center + x ndc * half_height * aspect
      world_y = y center + y ndc * half_height
      difference_x = world_x - x disc_center
      difference_y = world_y - y disc_center
      distance = sqrtF (square difference_x + square difference_y)
      world_per_pixel = (2.0 * half_height) / maxF 1.0 (y resolution)
      boundary_width = maxF 0.00001 (2.0 * world_per_pixel)
      outside_alpha = disc_reveal_alpha distance disc_radius boundary_width
      gray = dark_pattern ndc resolution
   in vec4 gray gray gray outside_alpha

main : IO ()
main = pure ()
