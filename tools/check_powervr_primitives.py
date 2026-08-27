#!/usr/bin/env python3
"""Compile the six small PowerVR teaching probes and check their GLSL contracts."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "build" / "exec" / "idris2-glsles"
VERTEX = ROOT / "fixtures" / "wegert-fullscreen.vert"

PROBES = [
    ("SetPixel3RGB5239182", "set-pixel-3-rgb-52-39-182"),
    ("SetBlock32x32RGB5239182", "set-block-32x32-rgb-52-39-182"),
    ("DotVector4Covector4", "dot-vector4-covector4"),
    ("DotVector32Covector32", "dot-vector32-covector32"),
    ("SubtractVector8Norm", "subtract-vector8-norm"),
    ("RotateDifference8ToE1", "rotate-difference8-to-e1"),
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def compile_probe(module: str, output_name: str, output_dir: Path) -> str:
    source = f"src/Example/{module}.idr"
    print(f"compile {output_name} ...", flush=True)
    started = time.monotonic()
    try:
        result = subprocess.run(
            [
                str(BACKEND),
                "--cg",
                "glsles",
                "--source-dir",
                "src",
                "--output-dir",
                str(output_dir),
                source,
                "-o",
                output_name,
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=60,
        )
    except subprocess.TimeoutExpired as error:
        raise AssertionError(f"{source} exceeded the 60-second teaching-probe compile limit") from error
    elapsed = time.monotonic() - started
    print(f"compiled {output_name} in {elapsed:.3f}s", flush=True)
    require(result.returncode == 0, source + " failed:\n" + result.stdout)
    fragment = output_dir / f"{output_name}.frag"
    require(fragment.is_file(), f"backend did not write {fragment.name}")
    return fragment.read_text()


def validate_link(fragment: Path) -> None:
    validator = shutil.which("glslangValidator")
    if validator is None:
        return
    result = subprocess.run(
        [validator, "-l", str(VERTEX), str(fragment)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    require(result.returncode == 0, fragment.name + " did not link:\n" + result.stdout)


def main() -> int:
    require(BACKEND.is_file(), "backend executable is missing; run make backend")

    with tempfile.TemporaryDirectory(prefix="powervr-primitives-") as directory:
        output_dir = Path(directory)
        shaders = {}
        for module, output_name in PROBES:
            shaders[output_name] = compile_probe(module, output_name, output_dir)
            validate_link(output_dir / f"{output_name}.frag")

        pixel = shaders["set-pixel-3-rgb-52-39-182"]
        require("in vec2 v_ndc;" in pixel, "pixel-3 probe lost its pixel-position input")
        require("> 0.5" in pixel, "pixel-3 probe lost fourth-pixel selection")
        require(pixel.count("255.0") >= 3, "pixel-3 probe lost byte-to-float RGB conversion")

        block = shaders["set-block-32x32-rgb-52-39-182"]
        require("uniform " not in block, "block fill unexpectedly acquired uniforms")
        require(block.count("255.0") >= 3, "block fill lost byte-to-float RGB conversion")

        dot4 = shaders["dot-vector4-covector4"]
        require("uniform vec4 u_vector;" in dot4, "vec4 dot lost vector uniform")
        require("uniform vec4 u_covector;" in dot4, "vec4 dot lost covector uniform")
        require("dot(" in dot4, "vec4 dot was not emitted as GLSL dot")

        dot32 = shaders["dot-vector32-covector32"]
        for index in range(8):
            require(f"uniform vec4 u_v{index};" in dot32, f"32D dot lost vector chunk {index}")
            require(f"uniform vec4 u_c{index};" in dot32, f"32D dot lost covector chunk {index}")
        require(dot32.count("dot(") >= 8, "32D contraction did not use eight native vec4 dots")
        require("u_vector[" not in dot32 and "u_covector[" not in dot32,
                "32D teaching probe unexpectedly regressed to the slow nested-array path")

        subtract8 = shaders["subtract-vector8-norm"]
        for declaration in [
            "uniform vec4 u_a0;", "uniform vec4 u_a1;",
            "uniform vec4 u_b0;", "uniform vec4 u_b1;",
        ]:
            require(declaration in subtract8, "8D subtraction lost " + declaration)
        require(subtract8.count("dot(") >= 2, "8D subtraction norm lost chunk reductions")
        require("sqrt(" in subtract8, "8D subtraction norm lost Euclidean square root")

        rotate8 = shaders["rotate-difference8-to-e1"]
        require(rotate8.count("sqrt(") >= 3, "8D rotation lost norm/residual square roots")
        require(rotate8.count("dot(") >= 6, "8D rotation lost vectorized Householder products")
        require(" ? " in rotate8, "8D rotation lost the already-aligned identity case")
        require("vec3(" in rotate8, "8D rotation lost the seven-coordinate residual reduction")

    print("PowerVR primitive checks passed: pixel, block, dot4, dot32, subtract8, rotate8")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"PowerVR primitive check failed: {error}")
        raise SystemExit(1)
