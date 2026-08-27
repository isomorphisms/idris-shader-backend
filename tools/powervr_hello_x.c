#include <EGL/egl.h>
#include <GLES3/gl3.h>

#include <stdio.h>
#include <stdlib.h>

#ifndef EGL_OPENGL_ES3_BIT
#define EGL_OPENGL_ES3_BIT 0x00000040
#endif

enum { WIDTH = 17, HEIGHT = 17 };

static const char *vertex_source =
    "#version 300 es\n"
    "precision highp float;\n"
    "const vec2 p[3] = vec2[3](vec2(-1.0,-1.0),vec2(3.0,-1.0),vec2(-1.0,3.0));\n"
    "out vec2 v_ndc;\n"
    "void main(){v_ndc=p[gl_VertexID];gl_Position=vec4(v_ndc,0.0,1.0);}\n";

static void fail(const char *message) {
  fprintf(stderr, "%s\n", message);
  exit(1);
}

static char *read_text(const char *path) {
  FILE *file = fopen(path, "rb");
  if (file == NULL) fail("cannot open generated fragment shader");
  if (fseek(file, 0, SEEK_END) != 0) fail("cannot seek fragment shader");
  long size = ftell(file);
  if (size < 0) fail("cannot measure fragment shader");
  rewind(file);

  char *text = malloc((size_t)size + 1);
  if (text == NULL) fail("out of memory");
  if (fread(text, 1, (size_t)size, file) != (size_t)size)
    fail("cannot read fragment shader");
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

static GLuint link_program(GLuint vertex, GLuint fragment) {
  GLuint program = glCreateProgram();
  glAttachShader(program, vertex);
  glAttachShader(program, fragment);
  glLinkProgram(program);

  GLint ok = GL_FALSE;
  glGetProgramiv(program, GL_LINK_STATUS, &ok);
  if (ok != GL_TRUE) {
    char log[4096];
    GLsizei used = 0;
    glGetProgramInfoLog(program, sizeof log, &used, log);
    fprintf(stderr, "program link failed:\n%.*s\n", (int)used, log);
    exit(1);
  }
  return program;
}

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "usage: %s generated/powervr-hello-x.frag\n", argv[0]);
    return 2;
  }

  EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  if (display == EGL_NO_DISPLAY) fail("eglGetDisplay failed");

  EGLint major = 0, minor = 0;
  if (!eglInitialize(display, &major, &minor)) fail("eglInitialize failed");
  if (!eglBindAPI(EGL_OPENGL_ES_API)) fail("eglBindAPI failed");

  const EGLint config_attributes[] = {
      EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
      EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
      EGL_RED_SIZE, 8,
      EGL_GREEN_SIZE, 8,
      EGL_BLUE_SIZE, 8,
      EGL_ALPHA_SIZE, 8,
      EGL_NONE,
  };
  EGLConfig config = NULL;
  EGLint count = 0;
  if (!eglChooseConfig(display, config_attributes, &config, 1, &count) || count != 1)
    fail("no GLES3 pbuffer EGL config");

  const EGLint surface_attributes[] = {
      EGL_WIDTH, WIDTH,
      EGL_HEIGHT, HEIGHT,
      EGL_NONE,
  };
  EGLSurface surface = eglCreatePbufferSurface(display, config, surface_attributes);
  if (surface == EGL_NO_SURFACE) fail("eglCreatePbufferSurface failed");

  const EGLint context_attributes[] = {
      EGL_CONTEXT_CLIENT_VERSION, 3,
      EGL_NONE,
  };
  EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
  if (context == EGL_NO_CONTEXT) fail("eglCreateContext failed");
  if (!eglMakeCurrent(display, surface, surface, context)) fail("eglMakeCurrent failed");

  printf("EGL %d.%d\n", major, minor);
  printf("GL_VENDOR: %s\n", (const char *)glGetString(GL_VENDOR));
  printf("GL_RENDERER: %s\n", (const char *)glGetString(GL_RENDERER));
  printf("GL_VERSION: %s\n", (const char *)glGetString(GL_VERSION));
  printf("GLSL: %s\n\n", (const char *)glGetString(GL_SHADING_LANGUAGE_VERSION));

  char *fragment_source = read_text(argv[1]);
  GLuint vertex = compile_shader(GL_VERTEX_SHADER, vertex_source);
  GLuint fragment = compile_shader(GL_FRAGMENT_SHADER, fragment_source);
  GLuint program = link_program(vertex, fragment);
  free(fragment_source);

  glViewport(0, 0, WIDTH, HEIGHT);
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
  glUseProgram(program);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  glFinish();

  GLubyte pixels[WIDTH * HEIGHT * 4];
  glReadPixels(0, 0, WIDTH, HEIGHT, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
  if (glGetError() != GL_NO_ERROR) fail("OpenGL ES draw/readback failed");

  for (int row = HEIGHT - 1; row >= 0; --row) {
    for (int column = 0; column < WIDTH; ++column) {
      size_t offset = ((size_t)row * WIDTH + (size_t)column) * 4;
      putchar(pixels[offset] > 127 ? 'X' : ' ');
    }
    putchar('\n');
  }

  glDeleteProgram(program);
  glDeleteShader(fragment);
  glDeleteShader(vertex);
  eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
  eglDestroyContext(display, context);
  eglDestroySurface(display, surface);
  eglTerminate(display);
  return 0;
}
