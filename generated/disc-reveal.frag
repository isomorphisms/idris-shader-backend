#version 300 es
precision highp float;
precision highp int;

in vec2 v_ndc;
uniform vec2 u_center;
uniform float u_half_height;
uniform float u_aspect;
uniform vec2 u_disc_center;
uniform float u_disc_radius;
uniform vec2 u_resolution;
layout(location = 0) out vec4 _idris_fragColor;

void main() {
  bool _idris_t23 = (u_disc_radius < 0.0);
  float _idris_t37;
  if (_idris_t23) {
    _idris_t37 = 0.0;
  } else {
    float _idris_t0 = u_center.x;
    float _idris_t1 = v_ndc.x;
    float _idris_t2 = (_idris_t1 * u_half_height);
    float _idris_t3 = (_idris_t2 * u_aspect);
    float _idris_t4 = (_idris_t0 + _idris_t3);
    float _idris_t5 = u_center.y;
    float _idris_t6 = v_ndc.y;
    float _idris_t7 = (_idris_t6 * u_half_height);
    float _idris_t8 = (_idris_t5 + _idris_t7);
    float _idris_t9 = u_disc_center.x;
    float _idris_t10 = (_idris_t4 - _idris_t9);
    float _idris_t11 = u_disc_center.y;
    float _idris_t12 = (_idris_t8 - _idris_t11);
    float _idris_t13 = (_idris_t10 * _idris_t10);
    float _idris_t14 = (_idris_t12 * _idris_t12);
    float _idris_t15 = (_idris_t13 + _idris_t14);
    float _idris_t16 = sqrt(_idris_t15);
    float _idris_t17 = (2.0 * u_half_height);
    float _idris_t18 = u_resolution.y;
    float _idris_t19 = max(1.0, _idris_t18);
    float _idris_t20 = (_idris_t17 / _idris_t19);
    float _idris_t21 = (2.0 * _idris_t20);
    float _idris_t22 = max(1e-5, _idris_t21);
    bool _idris_t24 = (1e-5 > u_disc_radius);
    float _idris_t25 = (_idris_t24 ? 1e-5 : u_disc_radius);
    bool _idris_t26 = (1e-5 > _idris_t22);
    float _idris_t27 = (_idris_t26 ? 1e-5 : _idris_t22);
    bool _idris_t28 = (_idris_t25 < _idris_t27);
    float _idris_t29 = (_idris_t28 ? _idris_t25 : _idris_t27);
    float _idris_t30 = (u_disc_radius - _idris_t29);
    float _idris_t31 = (_idris_t16 - _idris_t30);
    float _idris_t32 = (_idris_t31 / _idris_t29);
    bool _idris_t33 = (_idris_t32 < 0.0);
    bool _idris_t34 = (_idris_t32 > 1.0);
    float _idris_t35 = (_idris_t34 ? 1.0 : _idris_t32);
    float _idris_t36 = (_idris_t33 ? 0.0 : _idris_t35);
    _idris_t37 = _idris_t36;
  }
  float _idris_t38 = v_ndc.x;
  float _idris_t39 = (_idris_t38 + 1.0);
  float _idris_t40 = (0.5 * _idris_t39);
  float _idris_t41 = u_resolution.x;
  float _idris_t42 = (_idris_t40 * _idris_t41);
  float _idris_t43 = v_ndc.y;
  float _idris_t44 = (_idris_t43 + 1.0);
  float _idris_t45 = (0.5 * _idris_t44);
  float _idris_t46 = u_resolution.y;
  float _idris_t47 = (_idris_t45 * _idris_t46);
  float _idris_t48 = (0.173 * _idris_t42);
  float _idris_t49 = sin(_idris_t48);
  float _idris_t50 = (0.137 * _idris_t47);
  float _idris_t51 = sin(_idris_t50);
  float _idris_t52 = (_idris_t49 * _idris_t51);
  float _idris_t53 = (0.5 * _idris_t52);
  float _idris_t54 = (0.5 + _idris_t53);
  float _idris_t55 = (1.0 - _idris_t54);
  float _idris_t56 = (0.035 * _idris_t55);
  float _idris_t57 = (0.055 * _idris_t54);
  float _idris_t58 = (_idris_t56 + _idris_t57);
  vec4 _idris_t59 = vec4(_idris_t58, _idris_t58, _idris_t58, _idris_t37);
  _idris_fragColor = _idris_t59;
}

