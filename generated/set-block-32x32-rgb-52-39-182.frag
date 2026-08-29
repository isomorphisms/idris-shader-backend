#version 300 es
precision highp float;
precision highp int;

in vec2 v_ndc;
layout(location = 0) out vec4 _idris_fragColor;

void main() {
  float _idris_t0 = v_ndc.x;
  float _idris_t1 = (0.0 * _idris_t0);
  float _idris_t2 = (52.0 / 255.0);
  float _idris_t3 = (_idris_t2 + _idris_t1);
  float _idris_t4 = (39.0 / 255.0);
  float _idris_t5 = (_idris_t4 + _idris_t1);
  float _idris_t6 = (182.0 / 255.0);
  float _idris_t7 = (_idris_t6 + _idris_t1);
  vec4 _idris_t8 = vec4(_idris_t3, _idris_t5, _idris_t7, 1.0);
  _idris_fragColor = _idris_t8;
}

