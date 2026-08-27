#define _POSIX_C_SOURCE 200809L
#include <EGL/egl.h>
#include <GLES3/gl3.h>

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#ifndef EGL_OPENGL_ES3_BIT
#define EGL_OPENGL_ES3_BIT 0x00000040
#endif

enum { SURFACE_WIDTH = 32, SURFACE_HEIGHT = 32, BENCH_DRAWS = 4096 };

static const char *vertex_source =
    "#version 300 es\n"
    "precision highp float;\n"
    "const vec2 p[3]=vec2[3](vec2(-1.0,-1.0),vec2(3.0,-1.0),vec2(-1.0,3.0));\n"
    "out vec2 v_ndc;\n"
    "void main(){v_ndc=p[gl_VertexID];gl_Position=vec4(v_ndc,0.0,1.0);}\n";

static void fail(const char *message) {
  fprintf(stderr, "%s\n", message);
  exit(1);
}

static char *read_text(const char *path) {
  FILE *file = fopen(path, "rb");
  if (file == NULL) {
    fprintf(stderr, "cannot open %s\n", path);
    exit(1);
  }
  if (fseek(file, 0, SEEK_END) != 0) fail("cannot seek shader");
  long size = ftell(file);
  if (size < 0) fail("cannot measure shader");
  rewind(file);
  char *text = malloc((size_t)size + 1);
  if (text == NULL) fail("out of memory");
  if (fread(text, 1, (size_t)size, file) != (size_t)size) fail("cannot read shader");
  text[size] = '\0';
  fclose(file);
  return text;
}

static GLuint compile_shader(GLenum kind, const char *source) {
  GLuint shader = glCreateShader(kind);
  glShaderSource(shader, 1, &source, NULL);
  glCompileShader(shader);
  GLint ok = GL_FALSE;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
  if (ok != GL_TRUE) {
    char log[4096];
    GLsizei used = 0;
    glGetShaderInfoLog(shader, sizeof log, &used, log);
    fprintf(stderr, "shader compile failed:\n%.*s\n", (int)used, log);
    exit(1);
  }
  return shader;
}

static GLuint link_fragment(GLuint vertex, const char *path) {
  char *source = read_text(path);
  GLuint fragment = compile_shader(GL_FRAGMENT_SHADER, source);
  free(source);
  GLuint program = glCreateProgram();
  glAttachShader(program, vertex);
  glAttachShader(program, fragment);
  glLinkProgram(program);
  glDeleteShader(fragment);
  GLint ok = GL_FALSE;
  glGetProgramiv(program, GL_LINK_STATUS, &ok);
  if (ok != GL_TRUE) {
    char log[4096];
    GLsizei used = 0;
    glGetProgramInfoLog(program, sizeof log, &used, log);
    fprintf(stderr, "program link failed for %s:\n%.*s\n", path, (int)used, log);
    exit(1);
  }
  return program;
}

static void draw(GLuint program, int width, int height) {
  glViewport(0, 0, width, height);
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
  glUseProgram(program);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  glFinish();
  if (glGetError() != GL_NO_ERROR) fail("OpenGL ES draw failed");
}

static int near_byte(unsigned char actual, int expected, int tolerance) {
  int delta = (int)actual - expected;
  if (delta < 0) delta = -delta;
  return delta <= tolerance;
}

static void require_pixel(const unsigned char *pixel,
                          int r, int g, int b, int a,
                          int tolerance, const char *label) {
  if (!near_byte(pixel[0], r, tolerance) || !near_byte(pixel[1], g, tolerance) ||
      !near_byte(pixel[2], b, tolerance) || !near_byte(pixel[3], a, tolerance)) {
    fprintf(stderr, "%s: got RGBA (%u,%u,%u,%u), expected (%d,%d,%d,%d) +/- %d\n",
            label, pixel[0], pixel[1], pixel[2], pixel[3], r, g, b, a, tolerance);
    exit(1);
  }
}

static GLint uniform_location(GLuint program, const char *name) {
  GLint location = glGetUniformLocation(program, name);
  if (location < 0) {
    fprintf(stderr, "missing uniform %s\n", name);
    exit(1);
  }
  return location;
}

static double seconds_now(void) {
  struct timespec value;
  if (clock_gettime(CLOCK_MONOTONIC, &value) != 0) fail("clock_gettime failed");
  return (double)value.tv_sec + (double)value.tv_nsec * 1e-9;
}

static double benchmark_draw(GLuint program, int width, int height) {
  glViewport(0, 0, width, height);
  glUseProgram(program);
  glFinish();
  double start = seconds_now();
  for (int i = 0; i < BENCH_DRAWS; ++i) glDrawArrays(GL_TRIANGLES, 0, 3);
  glFinish();
  double finish = seconds_now();
  return (finish - start) / (double)BENCH_DRAWS;
}

int main(void) {
  const char *paths[6] = {
      "generated/set-pixel-3-rgb-52-39-182.frag",
      "generated/set-block-32x32-rgb-52-39-182.frag",
      "generated/dot-vector4-covector4.frag",
      "generated/dot-vector32-covector32.frag",
      "generated/subtract-vector8-norm.frag",
      "generated/rotate-difference8-to-e1.frag",
  };

  EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  if (display == EGL_NO_DISPLAY) fail("eglGetDisplay failed");
  EGLint major = 0, minor = 0;
  if (!eglInitialize(display, &major, &minor)) fail("eglInitialize failed");
  if (!eglBindAPI(EGL_OPENGL_ES_API)) fail("eglBindAPI failed");

  const EGLint config_attributes[] = {
      EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
      EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
      EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
      EGL_NONE,
  };
  EGLConfig config = NULL;
  EGLint count = 0;
  if (!eglChooseConfig(display, config_attributes, &config, 1, &count) || count != 1)
    fail("no GLES3 RGBA8 pbuffer config");

  const EGLint surface_attributes[] = {
      EGL_WIDTH, SURFACE_WIDTH, EGL_HEIGHT, SURFACE_HEIGHT, EGL_NONE,
  };
  EGLSurface surface = eglCreatePbufferSurface(display, config, surface_attributes);
  if (surface == EGL_NO_SURFACE) fail("eglCreatePbufferSurface failed");
  const EGLint context_attributes[] = {EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE};
  EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
  if (context == EGL_NO_CONTEXT) fail("eglCreateContext failed");
  if (!eglMakeCurrent(display, surface, surface, context)) fail("eglMakeCurrent failed");

  glDisable(GL_DITHER);
  glDisable(GL_BLEND);
  glDisable(GL_DEPTH_TEST);

  printf("EGL %d.%d\n", major, minor);
  printf("GL_VENDOR: %s\n", (const char *)glGetString(GL_VENDOR));
  printf("GL_RENDERER: %s\n", (const char *)glGetString(GL_RENDERER));
  printf("GL_VERSION: %s\n", (const char *)glGetString(GL_VERSION));
  printf("GLSL: %s\n\n", (const char *)glGetString(GL_SHADING_LANGUAGE_VERSION));

  GLuint vertex = compile_shader(GL_VERTEX_SHADER, vertex_source);
  GLuint programs[6];
  for (int i = 0; i < 6; ++i) programs[i] = link_fragment(vertex, paths[i]);

  /* 1. Zero-based pixel 3 of a 4x1 framebuffer. */
  draw(programs[0], 4, 1);
  unsigned char pixels4[4 * 4];
  glReadPixels(0, 0, 4, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixels4);
  for (int i = 0; i < 3; ++i)
    require_pixel(&pixels4[i * 4], 0, 0, 0, 255, 1, "set pixel 3: untouched pixel");
  require_pixel(&pixels4[3 * 4], 52, 39, 182, 255, 1, "set pixel 3");
  puts("1 set_pixel_3_to_rgb_52_39_182: PASS");

  /* 2. A tile-sized 32x32 fill. */
  draw(programs[1], 32, 32);
  unsigned char block[32 * 32 * 4];
  glReadPixels(0, 0, 32, 32, GL_RGBA, GL_UNSIGNED_BYTE, block);
  for (int i = 0; i < 32 * 32; ++i)
    require_pixel(&block[i * 4], 52, 39, 182, 255, 1, "32x32 block fill");
  puts("2 set_block_32x32_to_rgb_52_39_182: PASS");

  /* 3. Deterministic random-looking vec4/covec4 contraction. */
  const GLfloat vector4[4] = {0.13f, 0.27f, 0.41f, 0.59f};
  const GLfloat covector4[4] = {0.31f, 0.17f, 0.23f, 0.47f};
  glUseProgram(programs[2]);
  glUniform4fv(uniform_location(programs[2], "u_vector"), 1, vector4);
  glUniform4fv(uniform_location(programs[2], "u_covector"), 1, covector4);
  draw(programs[2], 1, 1);
  unsigned char pixel[4];
  glReadPixels(0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
  float dot4 = 0.0f;
  for (int i = 0; i < 4; ++i) dot4 += vector4[i] * covector4[i];
  int dot4_byte = (int)lroundf(255.0f * dot4);
  require_pixel(pixel, dot4_byte, dot4_byte, dot4_byte, 255, 2, "vec4 dot");
  printf("3 dot_vector4_covector4: PASS (%.7g)\n", dot4);

  /* 4. A real 32-component contraction, stored as eight vec4 chunks each. */
  GLfloat vector32[32], covector32[32];
  float dot32 = 0.0f;
  for (int i = 0; i < 32; ++i) {
    vector32[i] = (GLfloat)(((i * 17) % 31) + 1) / 128.0f;
    covector32[i] = (GLfloat)(((i * 11 + 7) % 29) + 1) / 128.0f;
    dot32 += vector32[i] * covector32[i];
  }
  glUseProgram(programs[3]);
  for (int chunk = 0; chunk < 8; ++chunk) {
    char vector_name[16];
    char covector_name[16];
    snprintf(vector_name, sizeof vector_name, "u_v%d", chunk);
    snprintf(covector_name, sizeof covector_name, "u_c%d", chunk);
    glUniform4fv(uniform_location(programs[3], vector_name), 1, &vector32[4 * chunk]);
    glUniform4fv(uniform_location(programs[3], covector_name), 1, &covector32[4 * chunk]);
  }
  draw(programs[3], 1, 1);
  glReadPixels(0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
  int dot32_byte = (int)lroundf(255.0f * dot32);
  require_pixel(pixel, dot32_byte, dot32_byte, dot32_byte, 255, 2, "32D dot");
  printf("4 dot_vector32_covector32: PASS (%.7g)\n", dot32);

  /* Shared 8D inputs for subtraction and rotation. */
  const GLfloat a0[4] = {0.10f, 0.20f, 0.30f, 0.40f};
  const GLfloat a1[4] = {0.15f, 0.25f, 0.35f, 0.45f};
  const GLfloat b0[4] = {0.02f, 0.04f, 0.06f, 0.08f};
  const GLfloat b1[4] = {0.01f, 0.03f, 0.05f, 0.07f};

  glUseProgram(programs[4]);
  glUniform4fv(uniform_location(programs[4], "u_a0"), 1, a0);
  glUniform4fv(uniform_location(programs[4], "u_a1"), 1, a1);
  glUniform4fv(uniform_location(programs[4], "u_b0"), 1, b0);
  glUniform4fv(uniform_location(programs[4], "u_b1"), 1, b1);
  draw(programs[4], 1, 1);
  glReadPixels(0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
  float norm2 = 0.0f;
  for (int i = 0; i < 4; ++i) {
    float d0 = a0[i] - b0[i];
    float d1 = a1[i] - b1[i];
    norm2 += d0 * d0 + d1 * d1;
  }
  float norm = sqrtf(norm2);
  int norm_byte = (int)lroundf(255.0f * norm);
  require_pixel(pixel, norm_byte, norm_byte, norm_byte, 255, 2, "8D subtraction norm");
  printf("5 subtract_vector8_norm: PASS (%.7g)\n", norm);

  glUseProgram(programs[5]);
  glUniform4fv(uniform_location(programs[5], "u_a0"), 1, a0);
  glUniform4fv(uniform_location(programs[5], "u_a1"), 1, a1);
  glUniform4fv(uniform_location(programs[5], "u_b0"), 1, b0);
  glUniform4fv(uniform_location(programs[5], "u_b1"), 1, b1);
  draw(programs[5], 1, 1);
  glReadPixels(0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
  require_pixel(pixel, 255, 0, 0, 255, 3, "8D Givens rotation to e1");
  puts("6 rotate_difference8_to_e1: PASS");

  double pixel_seconds = benchmark_draw(programs[0], 4, 1);
  double block_seconds = benchmark_draw(programs[1], 32, 32);
  printf("\n4096-draw wall-time probe (includes driver/submission + GPU completion):\n");
  printf("  4x1 pixel-selection draw: %.3f us/draw\n", pixel_seconds * 1e6);
  printf("  32x32 block-fill draw:    %.3f us/draw\n", block_seconds * 1e6);
  printf("  block/pixel ratio:         %.3fx\n", block_seconds / pixel_seconds);

  for (int i = 0; i < 6; ++i) glDeleteProgram(programs[i]);
  glDeleteShader(vertex);
  eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
  eglDestroyContext(display, context);
  eglDestroySurface(display, surface);
  eglTerminate(display);
  return 0;
}
