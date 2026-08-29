#!/usr/bin/env python3
from pathlib import Path
import sys

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
# HCL -> sRGB workload.  This is deliberately an IR/lowering receipt, not an
# architecture-specific instruction receipt.
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


def fail(message: str) -> None:
    raise SystemExit(f"fragment mock check failed: {message}")


def main() -> None:
    if len(sys.argv) != 2:
        fail("expected the output directory")

    output_dir = Path(sys.argv[1])

    for codegen, target_name in TARGETS.items():
        path = output_dir / f"wegert.{codegen}.frag.mock"
        if not path.exists():
            fail(f"missing {path}")

        text = path.read_text()
        required_headers = [
            "; FRAGMENT TARGET MOCK",
            f"; TARGET: {target_name}",
            f"; CODEGEN: {codegen}",
            "; NOT EXECUTABLE",
            "; SHARED PSEUDO-ISA -- architecture-specific optimization deferred",
            ".stage fragment",
            ".interface in %value : vec2",
        ]

        for token in required_headers + WEGERT_OPS:
            if token not in text:
                fail(f"{codegen}: missing {token!r}")

        # A mock target must never be mistaken for one of the real dialects.
        forbidden = ["#version", "void main", "@fragment", "fn main", "OpEntryPoint"]
        for token in forbidden:
            if token in text:
                fail(f"{codegen}: accidentally emitted real-dialect marker {token!r}")

    print(f"Wegert fragment mock matrix OK: {len(TARGETS)} targets")


if __name__ == "__main__":
    main()
