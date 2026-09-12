#version 300 es
precision highp float;
precision highp int;

uniform vec4 u_vector;
uniform vec4 u_covector;
layout(location = 0) out vec4 _idris_fragColor;

void main() {
  float _idris_t0 = dot(u_vector, u_covector);
  vec4 _idris_t1 = vec4(_idris_t0, _idris_t0, _idris_t0, 1.0);
  _idris_fragColor = _idris_t1;
}

