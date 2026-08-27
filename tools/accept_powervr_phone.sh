#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

ADB=${ADB:-adb}
EVIDENCE=${POWERVR_EVIDENCE:-artifacts/powervr-phone-acceptance.txt}
REMOTE=/data/local/tmp/idris-shader-powervr-acceptance
ANDROID_API=${ANDROID_API:-21}
TMP=
RUN_TMP=
REMOTE_READY=0

adb_cmd() {
  if [ -n "${ANDROID_SERIAL:-}" ]; then
    "$ADB" -s "$ANDROID_SERIAL" "$@"
  else
    "$ADB" "$@"
  fi
}

cleanup() {
  [ -z "$TMP" ] || rm -f "$TMP"
  [ -z "$RUN_TMP" ] || rm -f "$RUN_TMP"
  if [ "$REMOTE_READY" -eq 1 ]; then
    adb_cmd shell "rm -rf '$REMOTE'" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT HUP INT TERM

fail() {
  echo "PowerVR phone acceptance: $*" >&2
  exit 1
}

command -v "$ADB" >/dev/null 2>&1 || fail "adb not found"
adb_cmd get-state >/dev/null 2>&1 || fail "no usable adb device"
command -v git >/dev/null 2>&1 || fail "git not found"
git diff --quiet && git diff --cached --quiet || \
  fail "tracked working tree is dirty; acceptance evidence must name an exact commit"
COMMIT=$(git rev-parse HEAD)

# Generate the exact GLSL exercised by this branch before anything is copied.
make powervr-primitives-frag

NDK=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}
if [ -z "$NDK" ]; then
  SDK=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}
  if [ -n "$SDK" ] && [ -d "$SDK/ndk" ]; then
    for candidate in "$SDK"/ndk/*; do
      [ ! -d "$candidate" ] || NDK=$candidate
    done
  fi
fi
[ -n "$NDK" ] && [ -d "$NDK" ] || \
  fail "Android NDK not found; set ANDROID_NDK_HOME"

case "$(uname -s)" in
  Linux) HOST_TAG=linux-x86_64 ;;
  Darwin) HOST_TAG=darwin-x86_64 ;;
  *) fail "unsupported NDK host: $(uname -s)" ;;
esac

ABI=$(adb_cmd shell getprop ro.product.cpu.abi | tr -d '\r')
case "$ABI" in
  armeabi-v7a) TRIPLE=armv7a-linux-androideabi ;;
  arm64-v8a) TRIPLE=aarch64-linux-android ;;
  x86) TRIPLE=i686-linux-android ;;
  x86_64) TRIPLE=x86_64-linux-android ;;
  *) fail "unsupported Android ABI: $ABI" ;;
esac

TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG"
CC="$TOOLCHAIN/bin/clang"
[ -x "$CC" ] || fail "NDK compiler not found: $CC"

mkdir -p build "$(dirname -- "$EVIDENCE")"
"$CC" --target="${TRIPLE}${ANDROID_API}" \
  -std=c11 -O2 -Wall -Wextra tools/powervr_primitives.c \
  -o build/powervr-primitives-android -lEGL -lGLESv3 -lm

SHADERS='set-pixel-3-rgb-52-39-182.frag
set-block-32x32-rgb-52-39-182.frag
dot-vector4-covector4.frag
dot-vector32-covector32.frag
subtract-vector8-norm.frag
rotate-difference8-to-e1.frag'

adb_cmd shell "rm -rf '$REMOTE' && mkdir -p '$REMOTE/generated'"
REMOTE_READY=1
adb_cmd push build/powervr-primitives-android "$REMOTE/powervr-primitives" >/dev/null
for shader in $SHADERS; do
  [ -f "generated/$shader" ] || fail "missing generated/$shader"
  adb_cmd push "generated/$shader" "$REMOTE/generated/$shader" >/dev/null
done
adb_cmd shell "chmod 755 '$REMOTE/powervr-primitives'"

TMP=$(mktemp)
RUN_TMP=$(mktemp)
adb_cmd shell \
  "cd '$REMOTE' && ./powervr-primitives; rc=\$?; printf '\n__POWERVR_EXIT__=%d\n' \$rc" \
  >"$RUN_TMP" 2>&1 || true
STATUS=$(sed -n 's/^__POWERVR_EXIT__=//p' "$RUN_TMP" | tail -n 1 | tr -d '\r')
case "$STATUS" in
  ''|*[!0-9]*) STATUS=125 ;;
esac

{
  echo "idris-shader-backend PowerVR phone acceptance"
  echo "command: make powervr-phone-accept"
  echo "utc: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "commit: $COMMIT"
  echo "device.manufacturer: $(adb_cmd shell getprop ro.product.manufacturer | tr -d '\r')"
  echo "device.model: $(adb_cmd shell getprop ro.product.model | tr -d '\r')"
  echo "device.android: $(adb_cmd shell getprop ro.build.version.release | tr -d '\r')"
  echo "device.abi: $ABI"
  echo
  sed '/^__POWERVR_EXIT__=/d' "$RUN_TMP"
} >"$TMP"

cat "$TMP"
cp "$TMP" "$EVIDENCE"

[ "$STATUS" -eq 0 ] || \
  fail "runner failed with status $STATUS; evidence saved to $EVIDENCE"

grep -Eq '^GL_RENDERER: .+' "$TMP" || \
  fail "GL_RENDERER is missing; evidence saved to $EVIDENCE"
grep -Eiq '^GL_(VENDOR|RENDERER):.*(PowerVR|Imagination)' "$TMP" || \
  fail "GL_VENDOR/GL_RENDERER does not identify PowerVR/Imagination; evidence saved to $EVIDENCE"

PASS_COUNT=$(grep -Ec '^[1-6] .*: PASS' "$TMP" || true)
[ "$PASS_COUNT" -eq 6 ] || \
  fail "expected six framebuffer PASS lines, found $PASS_COUNT; evidence saved to $EVIDENCE"

printf '\nacceptance.renderer: PASS\nacceptance.framebuffers: 6/6 PASS\nacceptance: PASS\n' >>"$EVIDENCE"
printf '\nPowerVR phone acceptance: PASS\nevidence: %s\n' "$EVIDENCE"
