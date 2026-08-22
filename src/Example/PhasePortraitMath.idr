module Example.PhasePortraitMath

import Shader.Source

%default total

%export "glsles:fragment|v_ndc=in,u_zero=uniform,u_pole=uniform"
phase_portrait_math : SVec 2 -> SVec 2 -> SVec 2 -> SVec 4
phase_portrait_math point zero pole =
  let zero_delta = vsub point zero
      pole_delta = vsub point pole
      phase = atan2F (y zero_delta) (x zero_delta)
            - atan2F (y pole_delta) (x pole_delta)
      log_modulus = logF (maxF (length zero_delta) 0.000000000001)
                  - logF (maxF (length pole_delta) 0.000000000001)
      phase_band = fractF (phase / 6.283185307179586)
      modulus_band = fractF (log_modulus / 2.302585092994046)
      stepped_phase = floorF (phase_band * 8.0) / 8.0
      gamma_phase = powF (maxF phase_band 0.0) (1.0 / 2.4)
      softened_phase = smoothstepF 0.0 1.0 gamma_phase
   in vec4 stepped_phase modulus_band softened_phase 1.0

main : IO ()
main = pure ()
