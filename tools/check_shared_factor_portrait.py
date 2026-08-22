#!/usr/bin/env python3
"""Compile and validate the shared Wegert/continuation factor portrait."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "build" / "exec" / "idris2-glsles"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    require(BACKEND.is_file(), "backend executable is missing; run make backend")

    with tempfile.TemporaryDirectory(prefix="shared-factor-portrait-") as directory:
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
                "src/Example/SharedFactorPortrait.idr",
                "-o",
                "shared-factor-portrait",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        require(result.returncode == 0, "shared factor portrait failed:\n" + result.stdout)

        shader_path = output_dir / "shared-factor-portrait.frag"
        require(shader_path.is_file(), "backend did not write shared-factor-portrait.frag")
        shader = shader_path.read_text()

        for declaration in [
            "uniform int u_zero_count;",
            "uniform int u_pole_count;",
            "uniform vec2 u_zeros[64];",
            "uniform vec2 u_poles[64];",
        ]:
            require(declaration in shader, "shared portrait interface lost " + declaration)

        for operation in ["atan(", "log(", "floor(", "pow(", "sin(", "cos("]:
            require(operation in shader, "shared portrait lost " + operation)

        require(
            shader.count("u_zeros[int(") >= 64,
            "64 bounded zero slots were not compiled into the portrait",
        )
        require(
            shader.count("u_poles[int(") >= 64,
            "64 bounded pole slots were not compiled into the portrait",
        )
        require("66.0" in shader and "45.0" in shader, "Wegert HCL constants were lost")

        validator = shutil.which("glslangValidator")
        if validator is not None:
            validated = subprocess.run(
                [validator, "-S", "frag", str(shader_path)],
                cwd=ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            require(
                validated.returncode == 0,
                "GLSL validator rejected shared factor portrait:\n" + validated.stdout,
            )

    print("shared factor portrait passed: 64 zeros, 64 poles, HCL color, valid GLSL")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"shared factor portrait check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
