#version 300 es
precision highp float;
precision highp int;

uniform vec4 u_a0;
uniform vec4 u_a1;
uniform vec4 u_b0;
uniform vec4 u_b1;
layout(location = 0) out vec4 _idris_fragColor;

void main() {
  vec4 _idris_t0 = (u_a0 - u_b0);
  vec4 _idris_t1 = (u_a1 - u_b1);
  float _idris_t2 = dot(_idris_t0, _idris_t0);
  float _idris_t3 = dot(_idris_t1, _idris_t1);
  float _idris_t4 = (_idris_t2 + _idris_t3);
  float _idris_t5 = sqrt(_idris_t4);
  vec4 _idris_t6 = vec4(_idris_t5, _idris_t5, _idris_t5, 1.0);
  _idris_fragColor = _idris_t6;
}

