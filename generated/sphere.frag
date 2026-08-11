#version 300 es
precision highp float;
precision highp int;

in vec2 v_uv;
uniform float u_time;
layout(location = 0) out vec4 _idris_fragColor;

void main() {
  float _idris_t0 = sin(u_time);
  float _idris_t1 = (0.12 * _idris_t0);
  float _idris_t2 = (0.88 + _idris_t1);
  float _idris_t3 = v_uv.x;
  float _idris_t4 = (1.35 * _idris_t3);
  float _idris_t5 = v_uv.y;
  float _idris_t6 = (1.35 * _idris_t5);
  float _idris_t7 = (0.35 * _idris_t0);
  vec3 _idris_t8 = vec3(_idris_t4, _idris_t6, _idris_t7);
  float _idris_t9 = _idris_t8.x;
  float _idris_t10 = (2.0 * _idris_t9);
  float _idris_t11 = _idris_t8.y;
  float _idris_t12 = (2.0 * _idris_t11);
  float _idris_t13 = _idris_t8.z;
  float _idris_t14 = (2.0 * _idris_t13);
  vec3 _idris_t15 = vec3(_idris_t10, _idris_t12, _idris_t14);
  float _idris_t16 = length(_idris_t15);
  float _idris_t17 = max(1e-5, _idris_t16);
  float _idris_t18 = (1.0 / _idris_t17);
  vec3 _idris_t19 = (_idris_t18 * _idris_t15);
  vec3 _idris_t20 = vec3(0.35, 0.55, 1.0);
  vec3 _idris_t21 = normalize(_idris_t20);
  float _idris_t22 = dot(_idris_t19, _idris_t21);
  float _idris_t23 = max(0.0, _idris_t22);
  float _idris_t24 = (0.75 * _idris_t23);
  float _idris_t25 = (0.25 + _idris_t24);
  float _idris_t26 = (_idris_t2 * _idris_t25);
  float _idris_t27 = (0.95 * _idris_t26);
  float _idris_t28 = (_idris_t9 * _idris_t9);
  float _idris_t29 = (_idris_t11 * _idris_t11);
  float _idris_t30 = (_idris_t13 * _idris_t13);
  float _idris_t31 = (_idris_t30 + -1.0);
  float _idris_t32 = (_idris_t29 + _idris_t31);
  float _idris_t33 = (_idris_t28 + _idris_t32);
  float _idris_t34 = abs(_idris_t33);
  float _idris_t35 = (0.075 - _idris_t34);
  float _idris_t36 = (_idris_t35 / 0.075);
  float _idris_t37 = clamp(_idris_t36, 0.0, 1.0);
  float _idris_t38 = mix(0.015, _idris_t27, _idris_t37);
  float _idris_t39 = (0.72 * _idris_t26);
  float _idris_t40 = mix(0.025, _idris_t39, _idris_t37);
  float _idris_t41 = (0.18 * _idris_t26);
  float _idris_t42 = mix(0.06, _idris_t41, _idris_t37);
  vec4 _idris_t43 = vec4(_idris_t38, _idris_t40, _idris_t42, 1.0);
  _idris_fragColor = _idris_t43;
}

