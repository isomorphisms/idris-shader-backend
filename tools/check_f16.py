#!/usr/bin/env python3
"""Verify whole-shader F16/F32 intent on the current GLSL ES backend."""

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


def compile_shader(
    output_dir: Path,
    name: str,
    *,
    width: str | None = None,
    precision: str | None = None,
    ir: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    directives: list[str] = []
    if width is not None:
        directives += ["--directive", f"float-width={width}"]
    if precision is not None:
        directives += ["--directive", f"float-precision={precision}"]
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


def validate_fragment(path: Path) -> None:
    validator = shutil.which("glslangValidator")
    if validator is None:
        return
    validated = subprocess.run(
        [validator, "-S", "frag", str(path)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    require(
        validated.returncode == 0,
        "GLSL validator rejected " + str(path) + ":\n" + validated.stdout,
    )


def main() -> int:
    require(BACKEND.is_file(), "backend executable is missing; run make backend")

    with tempfile.TemporaryDirectory(prefix="glsles-f16-") as directory:
        output_dir = Path(directory)

        f16_ir_path = output_dir / "sphere-f16.ir"
        f16 = compile_shader(output_dir, "sphere-f16", width="f16", ir=f16_ir_path)
        require(f16.returncode == 0, "F16 shader failed:\n" + f16.stdout)
        f16_path = output_dir / "sphere-f16.frag"
        require(f16_path.is_file(), "backend did not write sphere-f16.frag")
        require(f16_ir_path.is_file(), "backend did not write the F16 checked IR")
        f16_source = f16_path.read_text()
        f16_ir = f16_ir_path.read_text()
        require(
            f16_ir.startswith("fragment(v_uv : in F16x2, u_time : uniform F16) -> F16x4"),
            "checked IR did not preserve whole-shader F16 intent",
        )
        require(" : F16" in f16_ir and "F16x" in f16_ir, "F16 width was erased from IR")
        require("F32" not in f16_ir, "F16 compilation leaked F32 semantic labels")
        require("precision mediump float;" in f16_source, "F16 default did not select mediump")
        require("precision highp float;" not in f16_source, "F16 default retained F32 highp")
        validate_fragment(f16_path)

        f32_ir_path = output_dir / "sphere-f32.ir"
        f32 = compile_shader(output_dir, "sphere-f32", width="f32", ir=f32_ir_path)
        require(f32.returncode == 0, "F32 shader failed:\n" + f32.stdout)
        f32_path = output_dir / "sphere-f32.frag"
        require(f32_path.is_file(), "backend did not write sphere-f32.frag")
        require(f32_ir_path.is_file(), "backend did not write the F32 checked IR")
        f32_source = f32_path.read_text()
        f32_ir = f32_ir_path.read_text()
        require(
            f32_ir.startswith("fragment(v_uv : in F32x2, u_time : uniform F32) -> F32x4"),
            "checked IR did not preserve whole-shader F32 intent",
        )
        require("precision highp float;" in f32_source, "F32 default did not remain highp")
        validate_fragment(f32_path)

        f16_high_ir_path = output_dir / "sphere-f16-high.ir"
        f16_high = compile_shader(
            output_dir,
            "sphere-f16-high",
            width="f16",
            precision="highp",
            ir=f16_high_ir_path,
        )
        require(f16_high.returncode == 0, "F16/highp shader failed:\n" + f16_high.stdout)
        f16_high_path = output_dir / "sphere-f16-high.frag"
        require(f16_high_path.is_file(), "backend did not write sphere-f16-high.frag")
        f16_high_source = f16_high_path.read_text()
        f16_high_ir = f16_high_ir_path.read_text()
        require("F16" in f16_high_ir and "F32" not in f16_high_ir, "highp override changed F16 intent")
        require("precision highp float;" in f16_high_source, "explicit highp override was ignored")
        validate_fragment(f16_high_path)

        f32_low_ir_path = output_dir / "sphere-f32-low.ir"
        f32_low = compile_shader(
            output_dir,
            "sphere-f32-low",
            width="f32",
            precision="lowp",
            ir=f32_low_ir_path,
        )
        require(f32_low.returncode == 0, "F32/lowp shader failed:\n" + f32_low.stdout)
        f32_low_path = output_dir / "sphere-f32-low.frag"
        require(f32_low_path.is_file(), "backend did not write sphere-f32-low.frag")
        f32_low_source = f32_low_path.read_text()
        f32_low_ir = f32_low_ir_path.read_text()
        require("F32" in f32_low_ir and "F16" not in f32_low_ir, "lowp override changed F32 intent")
        require("precision lowp float;" in f32_low_source, "explicit lowp override was ignored")
        validate_fragment(f32_low_path)

        rejected = compile_shader(output_dir, "sphere-f64", width="f64")
        require("Error:" in rejected.stdout, "unsupported float width unexpectedly compiled")
        require(
            "float-width must be f16 or f32" in rejected.stdout,
            "unsupported width had the wrong diagnostic:\n" + rejected.stdout,
        )
        require(not (output_dir / "sphere-f64.frag").exists(), "rejected width wrote a shader")

    print(
        "F16/F32 backend check passed: width intent, default lowering, precision overrides, "
        "invalid-width rejection"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"F16/F32 backend check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
