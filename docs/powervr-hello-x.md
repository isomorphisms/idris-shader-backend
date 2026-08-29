# PowerVR hello X

This is the GPU analogue of a tiny `print "X"` program.

A fragment shader has no stdout. Its primitive observable result is a pixel.
So the smallest useful visible program here shades two diagonal strips white,
forming an X on a black framebuffer.

The path is deliberately explicit:

```text
src/Example/PowerVRHelloX.idr
        ↓ Idris2 → GLSL ES backend
generated/powervr-hello-x.frag
        ↓ glCompileShader on the phone
PowerVR vendor shader compiler
        ↓
PowerVR USC instructions
        ↓ glDrawArrays
17 × 17 EGL pbuffer
        ↓ glReadPixels
ASCII X in the terminal
```

`tools/powervr_hello_x.c` is only the launcher. It creates an offscreen GLES 3
context, submits one fullscreen triangle, reads the 17 × 17 result back, and
prints one terminal character per pixel. It also prints `GL_VENDOR`,
`GL_RENDERER`, the GLES version, and the GLSL version so the device identifies
the driver and GPU that actually executed the shader.

This is **native PowerVR execution through the Android graphics driver**, not a
claim that this repository directly emits a loadable PowerVR machine-code
binary. The standard Android/OpenGL ES boundary is GLSL ES plus draw commands;
the vendor driver performs the final architecture-specific compilation.
Imagination publishes a PowerVR instruction-set reference, but precise feature
availability varies by PowerVR generation and some details require the full
vendor documentation.

## The entire shader source

```idris
%export "glsles:fragment|v_ndc=in"
power_vr_hello_x : SVec 2 -> SVec 4
power_vr_hello_x ndc =
  let diagonal = minF (absF (x ndc - y ndc)) (absF (x ndc + y ndc))
      ink = if diagonal < 0.12 then 1.0 else 0.0
   in vec4 ink ink ink 1.0
```

There are no uniforms, textures, buffers, loops, heap objects, strings, or
runtime calls in the fragment. `v_ndc` is merely the interpolated position of
the current fragment. The two absolute values measure distance from the two
diagonals; `minF` unions them; the comparison chooses white or black.

## Build

First build the backend and generate the fragment:

```sh
make powervr-hello-frag
```

On an Android/NDK or Termux environment exposing the standard EGL and GLES 3
headers/libraries, build the tiny native launcher:

```sh
make powervr-hello-host CC=clang
```

Or build both:

```sh
make powervr-hello CC=clang
```

Then run:

```sh
./build/powervr-hello-x generated/powervr-hello-x.frag
```

A successful run reports the real renderer and prints an X-shaped 17 × 17
framebuffer. If EGL is not exposed to the shell environment, the same fragment
can be used unchanged from a normal Android GLES 3 host; that is a host-access
problem, not a shader-language change.

## Why this is a useful boundary probe

The host does not decide whether a pixel belongs to the X. That decision is in
the backend-generated fragment shader and is executed by the GPU. The CPU only
creates the graphics context, submits the draw, and displays the returned pixel
bytes. This makes the example small enough to inspect while still crossing the
real compiler/backend/driver/hardware boundary.

References:

- Imagination PowerVR developer documentation: https://docs.imgtec.com/
- PowerVR instruction-set reference overview: https://docs.imgtec.com/reference-manuals/powervr-instruction-set-reference/html/topics/general-architecture-information.html
- PowerVR lower-precision guidance: https://docs.imgtec.com/starter-guides/powervr-architecture/html/topics/rules/do-prefer-lower-data-precision.html
