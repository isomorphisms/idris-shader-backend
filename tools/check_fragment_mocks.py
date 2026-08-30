#!/usr/bin/env python3
from pathlib import Path
import math
import sys

from fragment_mock_vm import execute, parse_program

TARGETS = {
    "powervr-ge8322-mock": "PowerVR GE8322",
    "mali-g57-valhall-mock": "Arm Mali-G57 MC1 / Valhall",
    "switch-maxwell-sm53-mock": "Nintendo Switch / Tegra X1",
    "steam-rdna2-vulkan-mock": "Steam-class AMD RDNA2",
    "webgpu-wgsl-mock": "WebGPU",
    "apple-metal-mock": "Apple GPU",
    "nvidia-hopper-sm90-mock": "NVIDIA Hopper",
    "nvidia-blackwell-sm100-mock": "NVIDIA Blackwell",
    "adreno-tile-mock": "Qualcomm Adreno",
}

# These operations are required by the canonical Wegert phase/log-modulus ->
# HCL -> sRGB workload.  This is an IR/lowering receipt plus an executable mock
# semantics check; it is still not an architecture-specific instruction receipt.
WEGERT_OPS = [
    "ffloor",
    "fmax",
    "fcmp.le",
    "select",
    "fpow",
    "fcos",
    "fsin",
    "fdiv",
    "fmul",
    "fadd",
    "fsub",
    "fclamp",
    "fatan2",
    "vlength",
    "flog",
    "pack3",
    "extract",
    "pack4",
    "store.frag_color",
]

GIVENS_OPS = [
    "fsqrt",
    "fmax",
    "fcmp.le",
    "select",
    "fdiv",
    "fneg",
    "fmul",
    "fadd",
    "pack4",
    "store.frag_color",
]


def fail(message: str) -> None:
    raise SystemExit(f"fragment mock check failed: {message}")


def close(actual: float, expected: float, tolerance: float = 1.0e-10) -> bool:
    return abs(actual - expected) <= tolerance * max(1.0, abs(actual), abs(expected))


def positive_fract(value: float) -> float:
    return value - math.floor(value)


def srgb_component(linear_value: float) -> float:
    value = max(linear_value, 0.0)
    if value <= 0.0031308:
        return 12.92 * value
    return 1.055 * math.pow(value, 1.0 / 2.4) - 0.055


def wegert_oracle(real: float, imag: float) -> tuple[float, float, float, float]:
    tau = 6.28318530717958647692
    log_10 = 2.30258509299404568402
    phase = math.atan2(imag, real)
    log_modulus = math.log(max(math.hypot(real, imag), 1.0e-12))
    hue_degrees = 360.0 * positive_fract(phase / tau)
    log_modulus_band = positive_fract(log_modulus / log_10)
    lightness = (
        66.0
        + 4.0 * log_modulus_band
        + 3.0 * positive_fract(hue_degrees / 100.0)
    )

    hue = hue_degrees * (math.pi / 180.0)
    chroma = 45.0
    u_star = chroma * math.cos(hue)
    v_star = chroma * math.sin(hue)
    white_u_prime = 0.19783982482140777
    white_v_prime = 0.46833630293240974
    y = (
        math.pow((lightness + 16.0) / 116.0, 3.0)
        if lightness > 8.0
        else lightness / 903.2962962962963
    )
    u_prime = u_star / (13.0 * lightness) + white_u_prime
    v_prime = v_star / (13.0 * lightness) + white_v_prime
    x = (9.0 * y * u_prime) / (4.0 * v_prime)
    z = y * (12.0 - 3.0 * u_prime - 20.0 * v_prime) / (4.0 * v_prime)

    linear_r = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z
    linear_g = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z
    linear_b = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z

    return (
        min(max(srgb_component(linear_r), 0.0), 1.0),
        min(max(srgb_component(linear_g), 0.0), 1.0),
        min(max(srgb_component(linear_b), 0.0), 1.0),
        1.0,
    )


def require_tokens(codegen: str, text: str, tokens: list[str]) -> None:
    for token in tokens:
        if token not in text:
            fail(f"{codegen}: missing {token!r}")


def check_mock_boundary(codegen: str, target_name: str, text: str) -> None:
    require_tokens(
        codegen,
        text,
        [
            "; FRAGMENT TARGET MOCK",
            f"; TARGET: {target_name}",
            f"; CODEGEN: {codegen}",
            "; NOT EXECUTABLE",
            "; SHARED PSEUDO-ISA -- architecture-specific optimization deferred",
            ".stage fragment",
        ],
    )

    # A mock target must never be mistaken for one of the real dialects.
    for token in ["#version", "void main", "@fragment", "fn main", "OpEntryPoint"]:
        if token in text:
            fail(f"{codegen}: accidentally emitted real-dialect marker {token!r}")


def check_wegert(output_dir: Path, codegen: str, target_name: str) -> None:
    path = output_dir / f"wegert.{codegen}.frag.mock"
    if not path.exists():
        fail(f"missing {path}")

    text = path.read_text()
    check_mock_boundary(codegen, target_name, text)
    require_tokens(codegen, text, [".interface in %value : vec2"] + WEGERT_OPS)

    program = parse_program(path)
    for real, imag in [(1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.3, 0.4), (2.0, -3.0)]:
        actual = execute(program, {"value": (real, imag)})
        expected = wegert_oracle(real, imag)
        if len(actual) != 4 or any(not math.isfinite(value) for value in actual):
            fail(f"{codegen}: non-finite Wegert mock result at {(real, imag)}: {actual}")
        for index, (got, want) in enumerate(zip(actual, expected)):
            if not close(got, want):
                fail(
                    f"{codegen}: Wegert channel {index} mismatch at {(real, imag)}: "
                    f"got {got}, expected {want}"
                )


def check_givens(output_dir: Path, codegen: str, target_name: str) -> None:
    path = output_dir / f"givens.{codegen}.frag.mock"
    if not path.exists():
        fail(f"missing {path}")

    text = path.read_text()
    check_mock_boundary(codegen, target_name, text)
    require_tokens(codegen, text, [".interface in %ab : vec2"] + GIVENS_OPS)

    program = parse_program(path)
    cases = [(0.3, 0.4), (-0.3, 0.4), (0.5, 0.0), (0.0, 0.0)]
    for a, b in cases:
        actual = execute(program, {"ab": (a, b)})
        radius = math.hypot(a, b)
        expected = (radius, 0.0, radius, radius)
        if len(actual) != 4 or any(not math.isfinite(value) for value in actual):
            fail(f"{codegen}: non-finite Givens mock result at {(a, b)}: {actual}")
        for index, (got, want) in enumerate(zip(actual, expected)):
            if not close(got, want, 1.0e-9):
                fail(
                    f"{codegen}: Givens component {index} mismatch at {(a, b)}: "
                    f"got {got}, expected {want}"
                )


def main() -> None:
    if len(sys.argv) != 2:
        fail("expected the output directory")

    output_dir = Path(sys.argv[1])
    for codegen, target_name in TARGETS.items():
        check_wegert(output_dir, codegen, target_name)
        check_givens(output_dir, codegen, target_name)

    print(
        f"fragment mock execution OK: {len(TARGETS)} targets, "
        "5 Wegert samples and 4 genuine Givens cases each"
    )


if __name__ == "__main__":
    main()
