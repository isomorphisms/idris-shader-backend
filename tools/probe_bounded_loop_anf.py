#!/usr/bin/env python3
"""Check direct lowering of the admitted bounded-iteration source form."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "build" / "exec" / "idris2-glsles"
SOURCE = "src/Example/BoundedLoopProbe.idr"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def compile_probe(temporary: Path, precision: str) -> tuple[str, str]:
    ir_path = temporary / f"bounded-loop-{precision}.ir"
    result = subprocess.run(
        [
            str(BACKEND),
            "--cg",
            "glsles",
            "--source-dir",
            "src",
            "--output-dir",
            str(temporary),
            "--directive",
            f"dump-ir={ir_path}",
            "--directive",
            f"float-precision={precision}",
            SOURCE,
            "-o",
            f"bounded-loop-{precision}",
        ],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    require(result.returncode == 0, f"{precision} bounded loop did not compile:\n" + result.stdout)
    shader_path = temporary / f"bounded-loop-{precision}.frag"
    listing = ", ".join(sorted(path.name for path in temporary.iterdir()))
    require(
        shader_path.is_file(),
        f"backend did not write {shader_path.name}; output:\n{result.stdout}\ntemporary files: {listing}",
    )
    require(
        ir_path.is_file(),
        f"backend did not write {ir_path.name}; output:\n{result.stdout}\ntemporary files: {listing}",
    )

    validator = shutil.which("glslangValidator")
    if validator is not None:
        validation = subprocess.run(
            [validator, "-S", "frag", str(shader_path)],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        require(
            validation.returncode == 0,
            f"glslang rejected {precision} bounded loop:\n" + validation.stdout,
        )

    return ir_path.read_text(), shader_path.read_text()


def normalize_precision(shader: str) -> str:
    return shader.replace("precision lowp float;", "precision FLOAT_POLICY float;").replace(
        "precision highp float;", "precision FLOAT_POLICY float;"
    )


def main() -> int:
    require(BACKEND.is_file(), "backend executable is missing; run make backend")
    with tempfile.TemporaryDirectory(prefix="bounded-loop-") as directory:
        temporary = Path(directory)
        low_ir, low_shader = compile_probe(temporary, "lowp")
        high_ir, high_shader = compile_probe(temporary, "highp")

        require(low_ir == high_ir, "precision policy changed the typed bounded-loop IR")
        require(low_ir.count("bounded-loop") == 1, "typed IR does not contain exactly one bounded loop")
        require("< 4 active < u_active" in low_ir, "typed IR lost compile-time/runtime loop bounds")

        for precision, shader in (("lowp", low_shader), ("highp", high_shader)):
            require(shader.count("for (int ") == 1, f"{precision} output is not one compact GLSL loop")
            require(" < 4 && " in shader, f"{precision} output lost compile-time loop maximum")
            require(" < u_active" in shader, f"{precision} output lost runtime active bound")
            require(" ? " not in shader, f"{precision} bounded iteration regressed to eager selects")

        require(
            normalize_precision(low_shader) == normalize_precision(high_shader),
            "lowp/highp bounded loops differ by more than float precision policy",
        )

    print("bounded loop direct-lowering check passed")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"bounded loop check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
