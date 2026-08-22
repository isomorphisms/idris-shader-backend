#!/usr/bin/env python3
"""Compile and validate the analytic-continuation renderer contract."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "build" / "exec" / "idris2-glsles"
VERTEX = ROOT / "fixtures" / "wegert-fullscreen.vert"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    require(BACKEND.is_file(), "backend executable is missing; run make backend")
    require(VERTEX.is_file(), "Wegert fullscreen vertex fixture is missing")

    with tempfile.TemporaryDirectory(prefix="analytic-continuation-") as directory:
        output_dir = Path(directory)
        result = subprocess.run(
            [
                str(BACKEND),
                "--cg",
                "glsles",
                "--source-dir",
                "src",
                "--output-dir",
                str(output_dir),
                "src/Example/AnalyticContinuation.idr",
                "-o",
                "analytic-continuation",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        require(result.returncode == 0, "analytic continuation shader failed:\n" + result.stdout)

        shader_path = output_dir / "analytic-continuation.frag"
        require(shader_path.is_file(), "backend did not write analytic-continuation.frag")
        shader = shader_path.read_text()

        for declaration in [
            "uniform vec2 u_resolution;",
            "uniform int u_zero_count;",
            "uniform int u_pole_count;",
            "uniform vec2 u_zeros[64];",
            "uniform vec2 u_poles[64];",
            "uniform int u_view_kind;",
            "uniform int u_continuation_count;",
            "uniform vec2 u_continuation_centers[24];",
            "uniform float u_continuation_radii[24];",
        ]:
            require(declaration in shader, "analytic continuation interface lost " + declaration)

        for operation in ["atan(", "log(", "floor(", "pow(", "smoothstep(", "cos("]:
            require(operation in shader, "analytic continuation shader lost " + operation)

        require(
            shader.count("u_continuation_centers[int(") >= 24,
            "24 bounded continuation centers were not compiled",
        )
        require(
            shader.count("u_continuation_radii[int(") >= 24,
            "24 bounded continuation radii were not compiled",
        )
        require("0.080" in shader and "0.096" in shader, "charcoal unrevealed palette was lost")
        require("0.98" in shader and "0.95" in shader, "continuation boundary palette was lost")

        validator = shutil.which("glslangValidator")
        if validator is not None:
            fragment = subprocess.run(
                [validator, "-S", "frag", str(shader_path)],
                cwd=ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            require(
                fragment.returncode == 0,
                "GLSL validator rejected analytic continuation fragment:\n" + fragment.stdout,
            )
            linked = subprocess.run(
                [validator, "-l", str(VERTEX), str(shader_path)],
                cwd=ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            require(
                linked.returncode == 0,
                "Wegert vertex and analytic continuation fragment did not link:\n" + linked.stdout,
            )

    print("analytic continuation passed: shared portrait, 24-step overlay, linked GLSL")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"analytic continuation check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
