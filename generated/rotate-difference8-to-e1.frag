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
  vec4 _idris_t6 = vec4(_idris_t5, 0.0, 0.0, 0.0);
  vec4 _idris_t7 = (_idris_t0 - _idris_t6);
  float _idris_t8 = dot(_idris_t7, _idris_t7);
  float _idris_t10 = (_idris_t8 + _idris_t3);
  float _idris_t11 = sqrt(_idris_t10);
  float _idris_t12 = max(1e-6, _idris_t11);
  float _idris_t13 = (1.0 / _idris_t12);
  vec4 _idris_t14 = (_idris_t13 * _idris_t7);
  vec4 _idris_t15 = (_idris_t13 * _idris_t1);
  float _idris_t16 = dot(_idris_t0, _idris_t14);
  float _idris_t17 = dot(_idris_t1, _idris_t15);
  float _idris_t18 = (_idris_t16 + _idris_t17);
  float _idris_t19 = (2.0 * _idris_t18);
  vec4 _idris_t20 = (_idris_t19 * _idris_t14);
  vec4 _idris_t21 = (_idris_t0 - _idris_t20);
  vec4 _idris_t22 = (_idris_t19 * _idris_t15);
  vec4 _idris_t23 = (_idris_t1 - _idris_t22);
  bool _idris_t24 = (_idris_t11 > 1e-6);
  float _idris_t25 = _idris_t21.x;
  float _idris_t26 = _idris_t21.y;
  float _idris_t27 = (0.0 - _idris_t26);
  float _idris_t28 = _idris_t21.z;
  float _idris_t29 = _idris_t21.w;
  vec4 _idris_t30 = vec4(_idris_t25, _idris_t27, _idris_t28, _idris_t29);
  vec4 _idris_t31 = (_idris_t24 ? _idris_t30 : _idris_t21);
  float _idris_t32 = _idris_t31.y;
  float _idris_t33 = _idris_t31.z;
  float _idris_t34 = _idris_t31.w;
  vec3 _idris_t35 = vec3(_idris_t32, _idris_t33, _idris_t34);
  float _idris_t36 = dot(_idris_t35, _idris_t35);
  float _idris_t37 = dot(_idris_t23, _idris_t23);
  float _idris_t38 = (_idris_t36 + _idris_t37);
  float _idris_t39 = sqrt(_idris_t38);
  float _idris_t40 = _idris_t31.x;
  float _idris_t41 = max(1e-6, _idris_t5);
  float _idris_t42 = (_idris_t40 / _idris_t41);
  vec4 _idris_t43 = vec4(_idris_t42, _idris_t39, _idris_t39, 1.0);
  _idris_fragColor = _idris_t43;
}

