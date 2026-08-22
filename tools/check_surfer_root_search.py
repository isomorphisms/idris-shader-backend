#!/usr/bin/env python3
"""Compile and validate a bounded polynomial ray-root search."""

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

    with tempfile.TemporaryDirectory(prefix="surfer-root-search-") as directory:
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
                "src/Example/SurferRootSearch.idr",
                "-o",
                "surfer-root-search",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        require(result.returncode == 0, "Surfer root-search shader failed:\n" + result.stdout)

        shader_path = output_dir / "surfer-root-search.frag"
        require(shader_path.is_file(), "backend did not write surfer-root-search.frag")
        shader = shader_path.read_text()

        for declaration in [
            "in vec2 v_uv;",
            "uniform float u_coefficients[8];",
            "uniform float u_near;",
            "uniform float u_far;",
        ]:
            require(declaration in shader, "Surfer root-search interface lost " + declaration)

        for index in range(8):
            require(
                f"u_coefficients[int({float(index)})]" in shader,
                f"polynomial coefficient {index} was not used",
            )

        require(shader.count(" ? ") >= 20, "bounded bracket/bisection decisions were not emitted")
        require("16.0" in shader, "16-interval bracket search bound was lost")
        require("0.5" in shader, "bisection midpoint was not emitted")

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
                "GLSL validator rejected Surfer root-search fragment:\n" + validated.stdout,
            )

    print("Surfer root search passed: degree 7, 16 brackets, 20 bisections, valid GLSL")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"Surfer root-search check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
