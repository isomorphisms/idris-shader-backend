#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

CC=${CC:-clang}
GETPROP=${GETPROP:-/system/bin/getprop}
EVIDENCE=${POWERVR_EVIDENCE:-artifacts/powervr-phone-acceptance.txt}
TMP=
RUN_TMP=
MANIFEST_TMP=

cleanup() {
  if [ -n "$TMP" ]; then rm -f "$TMP"; fi
  if [ -n "$RUN_TMP" ]; then rm -f "$RUN_TMP"; fi
  if [ -n "$MANIFEST_TMP" ]; then rm -f "$MANIFEST_TMP"; fi
}
trap cleanup EXIT HUP INT TERM

fail() {
  echo "PowerVR Termux acceptance: $*" >&2
  exit 1
}

if ! command -v git >/dev/null 2>&1; then fail "git not found"; fi
if ! command -v "$CC" >/dev/null 2>&1; then fail "clang not found; run: pkg install clang"; fi
if [ ! -x "$GETPROP" ]; then
  fail "Android getprop not found; this target must run on the phone in Termux"
fi
if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
  fail "working tree is dirty; acceptance evidence must name an exact commit"
fi

COMMIT=$(git rev-parse HEAD)
CC_VERSION=$("$CC" --version | head -n 1 | tr -d '\r')
ABI=$("$GETPROP" ro.product.cpu.abi | tr -d '\r')
ABI_LIST=$("$GETPROP" ro.product.cpu.abilist | tr -d '\r')
DEVICE_SDK=$("$GETPROP" ro.build.version.sdk | tr -d '\r')
case "$DEVICE_SDK" in
  ''|*[!0-9]*) fail "device reported an invalid Android API: $DEVICE_SDK" ;;
esac

SHADERS='set-pixel-3-rgb-52-39-182.frag
set-block-32x32-rgb-52-39-182.frag
dot-vector4-covector4.frag
dot-vector32-covector32.frag
subtract-vector8-norm.frag
rotate-difference8-to-e1.frag'

# Git blob identities bind the shaders exercised below to the exact commit.
# Regeneration from checked Idris source remains a separate exact-head CI gate.
MANIFEST_TMP=$(mktemp)
for shader in $SHADERS; do
  path="generated/$shader"
  if [ ! -f "$path" ]; then fail "missing $path"; fi
  if expected_blob=$(git rev-parse "$COMMIT:$path" 2>/dev/null); then
    :
  else
    fail "$path is not tracked by commit $COMMIT"
  fi
  actual_blob=$(git hash-object "$path")
  if [ "$actual_blob" != "$expected_blob" ]; then
    fail "$path differs from commit $COMMIT"
  fi
  printf 'shader.blob: %s %s\n' "$actual_blob" "$path" >>"$MANIFEST_TMP"
done

mkdir -p build "$(dirname -- "$EVIDENCE")"
"$CC" -std=c11 -O2 -Wall -Wextra tools/powervr_primitives.c \
  -o build/powervr-primitives-termux -lEGL -lGLESv3 -lm

TMP=$(mktemp)
RUN_TMP=$(mktemp)
if ./build/powervr-primitives-termux >"$RUN_TMP" 2>&1; then
  STATUS=0
else
  STATUS=$?
fi

{
  echo "idris-shader-backend PowerVR phone acceptance"
  echo "command: make powervr-termux-accept"
  echo "execution: local Termux process on device"
  echo "utc: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "commit: $COMMIT"
  echo "source.generated: tracked shader blobs match commit"
  echo "source.regeneration: exact-head CI evidence required separately"
  echo "host.cc: $CC_VERSION"
  echo "termux.version: ${TERMUX_VERSION:-unknown}"
  echo "device.manufacturer: $("$GETPROP" ro.product.manufacturer | tr -d '\r')"
  echo "device.model: $("$GETPROP" ro.product.model | tr -d '\r')"
  echo "device.android: $("$GETPROP" ro.build.version.release | tr -d '\r')"
  echo "device.sdk: $DEVICE_SDK"
  echo "device.abi: $ABI"
  echo "device.abilist: $ABI_LIST"
  echo "runner.exit: $STATUS"
  cat "$MANIFEST_TMP"
  echo
  cat "$RUN_TMP"
} >"$TMP"

cat "$TMP"
cp "$TMP" "$EVIDENCE"

if [ "$STATUS" -ne 0 ]; then
  fail "runner failed with status $STATUS; evidence saved to $EVIDENCE"
fi

for identity in '^EGL [0-9]+\.[0-9]+$' '^GL_VENDOR: .+' '^GL_RENDERER: .+' \
                '^GL_VERSION: .+' '^GLSL: .+'; do
  if ! grep -Eq "$identity" "$TMP"; then
    fail "incomplete EGL/GLES identity; evidence saved to $EVIDENCE"
  fi
done
if ! grep -Eiq '^GL_(VENDOR|RENDERER):.*(PowerVR|Imagination)' "$TMP"; then
  fail "GL_VENDOR/GL_RENDERER does not identify PowerVR/Imagination; evidence saved to $EVIDENCE"
fi

if COMPILE_LINK_COUNT=$(grep -Ec '^[1-6] shader_compile_link: PASS' "$TMP"); then :; fi
if [ "$COMPILE_LINK_COUNT" -ne 6 ]; then
  fail "expected six shader compile/link PASS lines, found $COMPILE_LINK_COUNT; evidence saved to $EVIDENCE"
fi

FRAMEBUFFER_PATTERN='^(1 set_pixel_3_to_rgb_52_39_182|2 set_block_32x32_to_rgb_52_39_182|3 dot_vector4_covector4|4 dot_vector32_covector32|5 subtract_vector8_norm|6 rotate_difference8_to_e1): PASS( \(|$)'
if PASS_COUNT=$(grep -Ec "$FRAMEBUFFER_PATTERN" "$TMP"); then :; fi
if [ "$PASS_COUNT" -ne 6 ]; then
  fail "expected six framebuffer PASS lines, found $PASS_COUNT; evidence saved to $EVIDENCE"
fi

if TIMING_COUNT=$(grep -Ec '^  (4x1 pixel-selection draw:|32x32 block-fill draw:|block/pixel ratio:)' "$TMP"); then :; fi
if [ "$TIMING_COUNT" -ne 3 ]; then
  fail "expected the complete three-line timing block, found $TIMING_COUNT lines; evidence saved to $EVIDENCE"
fi

printf '\nacceptance.generated_blobs: PASS\nacceptance.renderer: PASS\nacceptance.compile_link: 6/6 PASS\nacceptance.framebuffers: 6/6 PASS\nacceptance: PASS\n' >>"$EVIDENCE"
printf '\nPowerVR Termux acceptance: PASS\nevidence: %s\n' "$EVIDENCE"
