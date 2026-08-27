# PowerVR phone acceptance

PR #16's software acceptance is the six-probe GLES3/EGL harness under Mesa. The remaining architecture-specific gate is the same generated GLSL compiled and executed by a real PowerVR phone driver.

From a clean checkout of the PR branch with one Android device connected over ADB:

```sh
make powervr-phone-accept
```

The host needs the normal Idris 2/backend build prerequisites, `adb`, and an Android NDK. `ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT` may point directly at the NDK; otherwise the script uses the newest NDK below `ANDROID_SDK_ROOT/ndk` or `ANDROID_HOME/ndk`. `ANDROID_SERIAL` selects a device when more than one is connected.

That one target:

1. refuses a tracked dirty tree so the evidence names one exact commit;
2. regenerates the six GLSL fragments from that commit;
3. reads the phone ABI and cross-compiles only `tools/powervr_primitives.c` with the NDK;
4. pushes the runner and six fragments to `/data/local/tmp`;
5. executes the existing framebuffer/readback and timing harness on the phone;
6. requires a non-empty `GL_RENDERER`, PowerVR/Imagination identification, and exactly six framebuffer `PASS` lines;
7. writes the complete evidence record to `artifacts/powervr-phone-acceptance.txt` and removes the temporary phone directory.

The evidence record intentionally includes the source commit, non-unique device description, Android version and ABI, EGL/GLES/GLSL strings, `GL_VENDOR`, `GL_RENDERER`, all six framebuffer readback verdicts, and the 4096-draw wall-time comparison. It does not record the ADB serial or Android build fingerprint.

The framebuffer lines are acceptance results from `glReadPixels`, not screenshots. The timing numbers include driver submission and GPU completion exactly as the native harness reports them; they are not USC cycle counts.

A successful record ends with:

```text
acceptance.renderer: PASS
acceptance.framebuffers: 6/6 PASS
acceptance: PASS
```

Paste the contents of `artifacts/powervr-phone-acceptance.txt` into PR #16 (or attach it unchanged). Until a real PowerVR run produces that final block, the hardware-specific gate remains open.
