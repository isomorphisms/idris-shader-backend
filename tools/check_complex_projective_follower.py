#!/usr/bin/env python3
"""Compile and link the complex/projective GPU follower fixture."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "build" / "exec" / "idris2-glsles"
VERTEX = ROOT / "fixtures" / "wegert-fullscreen.vert"
ARTIFACTS = ROOT / "build" / "complex-projective-follower"
SHARED = ROOT / ".idric-complex" / "_" / "fixtures" / "complex-projective" / "float32.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def command_output(arguments: list[str]) -> str:
    return subprocess.check_output(arguments, cwd=ROOT, text=True).strip()


def main() -> int:
    require(BACKEND.is_file(), "backend executable is missing; run make backend")
    require(VERTEX.is_file(), "Wegert fullscreen vertex fixture is missing")
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    shader_path = ARTIFACTS / "complex-projective-follower.frag"
    ir_path = ARTIFACTS / "complex-projective-follower.ir"

    canonical_sha = os.environ.get("IDRIC_COMPLEX_SEMANTICS_SHA", "unresolved")
    shared_bound = False
    if canonical_sha != "unresolved":
        require(SHARED.is_file(), "canonical complex/projective corpus checkout is missing")
        shared = json.loads(SHARED.read_text())
        require(shared["schema"] == "idric-complex-projective-corpus-v1", "unexpected corpus schema")
        require(shared["precision"]["name"] == "Float32", "shader follower precision drifted from Float32 corpus")
        require(shared["render"]["divisor"]["zeros"] == [[-0.35, 0.2]], "shader zero fixture drifted from corpus")
        require(shared["render"]["divisor"]["poles"] == [[0.4, -0.25]], "shader pole fixture drifted from corpus")
        require(shared["render"]["entire_q"]["constant"] == [0.0, 0.0], "shader q constant drifted from corpus")
        require(shared["render"]["entire_q"]["linear"] == [0.125, 0.0], "shader q linear term drifted from corpus")
        require(shared["render"]["entire_q"]["quadratic"] == [0.03125, 0.0], "shader q quadratic term drifted from corpus")
        shared_bound = True

    result = subprocess.run(
        [
            str(BACKEND),
            "--cg",
            "glsles",
            "--directive",
            f"dump-ir={ir_path}",
            "--source-dir",
            "src",
            "--output-dir",
            str(ARTIFACTS),
            "src/Example/ComplexProjectiveFollower.idr",
            "-o",
            "complex-projective-follower",
        ],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    require(result.returncode == 0, "complex/projective follower compilation failed:\n" + result.stdout)
    require(shader_path.is_file(), "backend did not write complex-projective-follower.frag")
    require(ir_path.is_file(), "backend did not retain the typed follower IR")
    shader = shader_path.read_text()

    for declaration in [
        "uniform vec2 u_projective_scale;",
        "uniform vec2 u_projective_right_0;",
        "uniform vec2 u_projective_right_1;",
    ]:
        require(declaration in shader, "complex/projective follower lost " + declaration)

    for required in ["sqrt(", "0.125", "0.03125", "-0.35", "0.4"]:
        require(required in shader, "complex/projective follower lost " + required)

    # The fixture evolves q -> exp(q) -> R*H using complex arithmetic. Phase,
    # logarithm, and conjugation are not needed to define that evolving state.
    require("atan(" not in shader, "phase observation entered the follower field evolution")
    require("log(" not in shader, "log observation entered the follower field evolution")

    validator = shutil.which("glslangValidator")
    require(validator is not None, "glslangValidator is required for follower acceptance")
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
        "GLSL validator rejected complex/projective follower:\n" + validated.stdout,
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
        "fullscreen vertex and complex/projective fragment did not link:\n" + linked.stdout,
    )

    tested_checkout = command_output(["git", "rev-parse", "HEAD"])
    source_head = os.environ.get("SOURCE_HEAD_SHA", tested_checkout)
    shader_hash = hashlib.sha256(shader_path.read_bytes()).hexdigest()
    ir_hash = hashlib.sha256(ir_path.read_bytes()).hexdigest()
    shared_stage = (
        "stage\tshared_corpus_binding\tPASS\n"
        if shared_bound
        else "stage\tshared_corpus_binding\tSKIP\tcanonical corpus not supplied in this local invocation\n"
    )
    receipt = ARTIFACTS / "receipt.tsv"
    receipt.write_text(
        "COMPLEX_PROJECTIVE_RECEIPT\t1\n"
        "role\tSHADER_FOLLOWER\n"
        "repository\tisomorphisms/idris-shader-backend\n"
        f"source_head_sha\t{source_head}\n"
        f"tested_checkout_sha\t{tested_checkout}\n"
        f"canonical_complex_projective_semantics_sha\t{canonical_sha}\n"
        "precision\tcurrent backend Float32/highp default\n"
        "representation\tcomplex scalar lowered to vec2; representation is not semantics\n"
        + shared_stage
        + "stage\ttyped_ir_generation\tPASS\n"
        "stage\tshader_generation\tPASS\n"
        "stage\tshader_validation\tPASS\n"
        "stage\tprogram_link\tPASS\n"
        "stage\tshader_load\tSKIP\tno driver/device in this lane\n"
        "stage\tgpu_execution\tSKIP\tno driver/device in this lane\n"
        "stage\tframebuffer_capture\tSKIP\tno driver/device in this lane\n"
        "stage\tvendor_device_receipt\tSKIP\tno physical GPU in this lane\n"
        f"typed_ir_sha256\t{ir_hash}\n"
        f"fragment_sha256\t{shader_hash}\n"
    )
    print(receipt.read_text(), end="")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"complex/projective follower check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
