# PowerVR phone acceptance

PR #16's software acceptance is the six-probe GLES3/EGL harness under Mesa. The remaining architecture-specific gate is the same generated GLSL compiled and executed by a real PowerVR phone driver.

From a clean checkout of the PR branch with one Android device connected over ADB:

```sh
make powervr-phone-accept
```

The host needs the normal Idris 2/backend build prerequisites, `adb`, and an Android NDK. `ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT` may point directly at the NDK; otherwise the script uses the newest NDK below `ANDROID_SDK_ROOT/ndk` or `ANDROID_HOME/ndk`. `ANDROID_SERIAL` selects a device when more than one is connected.

A short preflight avoids losing time to the common setup failures:

```sh
adb devices
adb shell getprop ro.product.cpu.abilist
printf '%s\n' "${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-auto-detect}}"
git status --short
```

The intended phone reports `armeabi-v7a` in its ABI list. Authorize the host when Android shows the USB-debugging prompt, leave only that phone connected, and run the acceptance target from the PR branch. If more than one device must remain connected, export the chosen serial as `ANDROID_SERIAL`; the serial is used for routing but is not written to the receipt.

That one target:

1. refuses a tracked dirty tree so the evidence names one exact commit;
2. regenerates the six GLSL fragments and refuses the run if they differ from that commit;
3. reads the phone ABI and cross-compiles only `tools/powervr_primitives.c` with the NDK;
4. pushes the runner and six fragments to `/data/local/tmp`;
5. executes the existing framebuffer/readback and timing harness on the phone;
6. requires a non-empty `GL_RENDERER`, PowerVR/Imagination identification, exactly six shader compile/link `PASS` lines, and exactly six framebuffer `PASS` lines;
7. writes the complete evidence record to `artifacts/powervr-phone-acceptance.txt` and removes the temporary phone directory.

The evidence record intentionally includes the source commit, confirmation that regenerated GLSL matches that commit, a non-unique device description, Android version/API/ABI, runner exit status, EGL/GLES/GLSL strings, `GL_VENDOR`, `GL_RENDERER`, six explicit shader compile/link verdicts, all six framebuffer readback verdicts, and the 4096-draw wall-time comparison. It does not record the ADB serial or Android build fingerprint.

The framebuffer lines are acceptance results from `glReadPixels`, not screenshots. The timing numbers include driver submission and GPU completion exactly as the native harness reports them; they are not USC cycle counts.

The hardware gate is closed only by one unchanged receipt from the real phone that contains all of the following:

- the PR HEAD commit;
- `source.generated: matches commit` and `runner.exit: 0`;
- non-empty EGL, GLES, GLSL, `GL_VENDOR`, and `GL_RENDERER` identity lines;
- `GL_VENDOR` or `GL_RENDERER` naming PowerVR or Imagination;
- six numbered `shader_compile_link: PASS` lines;
- the six numbered framebuffer `PASS` lines for pixel selection, 32×32 fill, dot4, dot32, subtract8/norm, and rotation-to-e1;
- all three 4096-draw timing lines;
- this final block:

```text
acceptance.generated: PASS
acceptance.renderer: PASS
acceptance.compile_link: 6/6 PASS
acceptance.framebuffers: 6/6 PASS
acceptance: PASS
```

No performance threshold is part of this gate: the timings are characterization evidence. A screenshot, SwiftShader/Mesa output, `glslc` success, a partial transcript, or a hand-edited receipt does not close it.

Paste the contents of `artifacts/powervr-phone-acceptance.txt` into PR #16 (or attach it unchanged). Until a real PowerVR run produces that final block, the hardware-specific gate remains open.
