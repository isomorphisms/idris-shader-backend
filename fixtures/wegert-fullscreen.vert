#version 300 es
precision highp float;
precision highp int;

const vec2 POSITIONS[3] = vec2[3](
  vec2(-1.0, -1.0),
  vec2( 3.0, -1.0),
  vec2(-1.0,  3.0)
);
out vec2 v_ndc;

void main() {
  vec2 position = POSITIONS[gl_VertexID];
  v_ndc = position;
  gl_Position = vec4(position, 0.0, 1.0);
}
