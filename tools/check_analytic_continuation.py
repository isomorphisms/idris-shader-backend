#!/usr/bin/env python3
"""Compile and validate the analytic-continuation bounded-loop contract."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "build" / "exec" / "idris2-glsles"
VERTEX = ROOT / "fixtures" / "wegert-fullscreen.vert"
SOURCE = "src/Example/AnalyticContinuation.idr"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def compile_variant(output_dir: Path, precision: str) -> tuple[str, str, Path]:
    ir_path = output_dir / f"analytic-continuation-{precision}.ir"
    output_name = f"analytic-continuation-{precision}"
    result = subprocess.run(
        [
            str(BACKEND),
            "--cg",
            "glsles",
            "--source-dir",
            "src",
            "--output-dir",
            str(output_dir),
            "--directive",
            f"dump-ir={ir_path}",
            "--directive",
            f"float-precision={precision}",
            SOURCE,
            "-o",
            output_name,
        ],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    require(
        result.returncode == 0,
        f"analytic continuation {precision} shader failed:\n" + result.stdout,
    )
    shader_path = output_dir / f"{output_name}.frag"
    require(shader_path.is_file(), f"backend did not write {shader_path.name}")
    require(ir_path.is_file(), f"backend did not write {ir_path.name}")
    return ir_path.read_text(), shader_path.read_text(), shader_path


def normalize_precision(shader: str) -> str:
    return shader.replace("precision lowp float;", "precision FLOAT_POLICY float;").replace(
        "precision highp float;", "precision FLOAT_POLICY float;"
    )


def loop_blocks(shader: str) -> list[str]:
    blocks: list[str] = []
    cursor = 0
    while True:
        start = shader.find("for (int ", cursor)
        if start < 0:
            return blocks
        open_brace = shader.find("{", start)
        require(open_brace >= 0, "bounded GLSL loop has no body")
        depth = 1
        index = open_brace + 1
        while index < len(shader) and depth:
            if shader[index] == "{":
                depth += 1
            elif shader[index] == "}":
                depth -= 1
            index += 1
        require(depth == 0, "bounded GLSL loop body is unbalanced")
        blocks.append(shader[start:index])
        cursor = index


def validate_glsl(shader_path: Path) -> None:
    validator = shutil.which("glslangValidator")
    if validator is None:
        return
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


def check_shader_shape(shader: str, precision: str) -> None:
    require(
        f"precision {precision} float;" in shader,
        f"analytic continuation did not request {precision}",
    )
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

    loops = loop_blocks(shader)
    require(len(loops) == 2, "analytic continuation must emit exactly two bounded factor loops")
    require(
        shader.count(" < 64 && ") == 2,
        "factor loops lost their compile-time 64-element maximum",
    )
    require(
        sum("u_zeros[int(" in block for block in loops) == 1,
        "zero array must be read by exactly one bounded loop",
    )
    require(
        sum("u_poles[int(" in block for block in loops) == 1,
        "pole array must be read by exactly one bounded loop",
    )
    for label, block in (("first", loops[0]), ("second", loops[1])):
        require("atan(" in block, f"{label} factor loop lost phase evaluation")
        require("log(" in block, f"{label} factor loop lost log-modulus evaluation")
    require(shader.count("atan(") == 2, "factor phase computation was copied outside the two loops")
    require(shader.count("log(") == 2, "factor log-modulus computation was copied outside the two loops")
    require(" ? " not in shader, "analytic continuation regressed to eager GLSL selects")

    for operation in ["floor(", "pow(", "smoothstep(", "cos("]:
        require(operation in shader, "analytic continuation shader lost " + operation)

    require(
        shader.count("u_continuation_centers[int(") >= 24,
        "24 bounded continuation centers were not compiled",
    )
    require(
        shader.count("u_continuation_radii[int(") >= 24,
        "24 bounded continuation radii were not compiled",
    )
    require("0.08" in shader and "0.096" in shader, "charcoal unrevealed palette was lost")
    require("0.98" in shader and "0.95" in shader, "continuation boundary palette was lost")


def main() -> int:
    require(BACKEND.is_file(), "backend executable is missing; run make backend")
    require(VERTEX.is_file(), "Wegert fullscreen vertex fixture is missing")

    with tempfile.TemporaryDirectory(prefix="analytic-continuation-") as directory:
        output_dir = Path(directory)
        low_ir, low_shader, low_path = compile_variant(output_dir, "lowp")
        high_ir, high_shader, high_path = compile_variant(output_dir, "highp")

        require(low_ir == high_ir, "precision policy changed analytic continuation typed IR")
        require(
            low_ir.count("bounded-loop") == 2,
            "typed analytic continuation IR must contain one zero loop and one pole loop",
        )
        require(
            low_ir.count("< 64 active <") == 2,
            "typed factor loops lost compile-time or runtime bounds",
        )

        check_shader_shape(low_shader, "lowp")
        check_shader_shape(high_shader, "highp")
        require(
            normalize_precision(low_shader) == normalize_precision(high_shader),
            "lowp/highp analytic continuation differs by more than precision policy",
        )

        validate_glsl(low_path)
        validate_glsl(high_path)

    print("analytic continuation passed: two bounded factor loops, precision-stable linked GLSL")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"analytic continuation check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
