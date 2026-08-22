module Example.AnalyticContinuation

import Shader.ContinuationOverlay
import Shader.PhasePortrait
import Shader.Source

%default total

%export "glsles:fragment|v_ndc=in,u_center=uniform,u_half_height=uniform,u_aspect=uniform,u_resolution=uniform,u_zero_count=uniform,u_pole_count=uniform,u_zeros=uniform,u_poles=uniform,u_view_kind=uniform,u_continuation_count=uniform,u_continuation_centers=uniform,u_continuation_radii=uniform"
analytic_continuation : SVec 2 -> SVec 2 -> Double -> Double -> SVec 2 ->
                        Int -> Int -> SArray 64 (SVec 2) -> SArray 64 (SVec 2) ->
                        Int -> Int -> SArray 24 (SVec 2) -> SArray 24 Double -> SVec 4
analytic_continuation ndc center half_height aspect resolution
                      zero_count pole_count zeros poles
                      view_kind continuation_count continuation_centers continuation_radii =
  let point = vadd center (vec2 (x ndc * half_height * aspect)
                                (y ndc * half_height))
      base_color = wegert_rgb point
                              (int_to_double zero_count) zeros
                              (int_to_double pole_count) poles
      world_per_pixel = (2.0 * half_height) / maxF (y resolution) 1.0
      overlay_color = continuation_overlay ndc resolution point world_per_pixel
                                             (int_to_double continuation_count)
                                             continuation_centers continuation_radii
                                             base_color
      color = if int_to_double view_kind == 1.0 then overlay_color else base_color
   in vec4 (x color) (y color) (z color) 1.0

main : IO ()
main = pure ()
