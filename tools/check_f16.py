#!/usr/bin/env python3
"""Verify selectable whole-shader F16 lowering through the registered backend."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "build" / "exec" / "idris2-glsles"
SOURCE = "src/Example/CompilerSphere.idr"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def compile_shader(output_dir: Path, name: str, width: str, ir: Path | None = None):
    directives = ["--directive", f"float-width={width}"]
    if ir is not None:
        directives += ["--directive", f"dump-ir={ir}"]
    return subprocess.run(
        [
            str(BACKEND),
            "--cg",
            "glsles",
            "--source-dir",
            "src",
            "--output-dir",
            str(output_dir),
            *directives,
            SOURCE,
            "-o",
            name,
        ],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


def main() -> int:
    require(BACKEND.is_file(), "backend executable is missing; run make backend")

    with tempfile.TemporaryDirectory(prefix="glsles-f16-") as directory:
        output_dir = Path(directory)
        ir_path = output_dir / "sphere-f16.ir"
        result = compile_shader(output_dir, "sphere-f16", "f16", ir_path)
        require(result.returncode == 0, "F16 shader failed:\n" + result.stdout)

        shader_path = output_dir / "sphere-f16.frag"
        require(shader_path.is_file(), "backend did not write sphere-f16.frag")
        require(ir_path.is_file(), "backend did not write the F16 checked IR")

        shader = shader_path.read_text()
        ir = ir_path.read_text()
        require(
            ir.startswith("fragment(v_uv : in F16x2, u_time : uniform F16) -> F16x4"),
            "checked IR did not preserve the selected F16 width",
        )
        require(" : F16" in ir and "F16x" in ir, "F16 dataflow width was erased")
        require("F32" not in ir, "F16 compilation leaked F32 semantic types")
        require("precision mediump float;" in shader, "F16 did not lower to mediump")
        require("precision highp float;" not in shader, "F16 retained the F32 highp default")

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
                "GLSL validator rejected F16 fragment:\n" + validated.stdout,
            )

        rejected = compile_shader(output_dir, "sphere-f64", "f64")
        require("Error:" in rejected.stdout, "unsupported float width unexpectedly compiled")
        require(
            "float-width must be f16 or f32" in rejected.stdout,
            "unsupported width had the wrong diagnostic:\n" + rejected.stdout,
        )
        require(not (output_dir / "sphere-f64.frag").exists(), "rejected width wrote a shader")

    print("F16 backend check passed: F16 IR, mediump GLSL, invalid-width rejection")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"F16 backend check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
