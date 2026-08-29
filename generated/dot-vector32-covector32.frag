#version 300 es
precision highp float;
precision highp int;

uniform vec4 u_v0;
uniform vec4 u_v1;
uniform vec4 u_v2;
uniform vec4 u_v3;
uniform vec4 u_v4;
uniform vec4 u_v5;
uniform vec4 u_v6;
uniform vec4 u_v7;
uniform vec4 u_c0;
uniform vec4 u_c1;
uniform vec4 u_c2;
uniform vec4 u_c3;
uniform vec4 u_c4;
uniform vec4 u_c5;
uniform vec4 u_c6;
uniform vec4 u_c7;
layout(location = 0) out vec4 _idris_fragColor;

void main() {
  float _idris_t0 = dot(u_v0, u_c0);
  float _idris_t1 = dot(u_v1, u_c1);
  float _idris_t2 = dot(u_v2, u_c2);
  float _idris_t3 = dot(u_v3, u_c3);
  float _idris_t4 = dot(u_v4, u_c4);
  float _idris_t5 = dot(u_v5, u_c5);
  float _idris_t6 = dot(u_v6, u_c6);
  float _idris_t7 = dot(u_v7, u_c7);
  float _idris_t8 = (_idris_t0 + _idris_t1);
  float _idris_t9 = (_idris_t8 + _idris_t2);
  float _idris_t10 = (_idris_t9 + _idris_t3);
  float _idris_t11 = (_idris_t10 + _idris_t4);
  float _idris_t12 = (_idris_t11 + _idris_t5);
  float _idris_t13 = (_idris_t12 + _idris_t6);
  float _idris_t14 = (_idris_t13 + _idris_t7);
  vec4 _idris_t15 = vec4(_idris_t14, _idris_t14, _idris_t14, 1.0);
  _idris_fragColor = _idris_t15;
}

