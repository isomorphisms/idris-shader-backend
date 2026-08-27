#!/usr/bin/env python3
"""Compile the smallest visible shader and check its host-facing contract."""

from __future__ import annotations

import shutil
import subprocess
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

    with tempfile.TemporaryDirectory(prefix="powervr-hello-") as directory:
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
                "src/Example/PowerVRHelloX.idr",
                "-o",
                "powervr-hello-x",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        require(result.returncode == 0, "hello-X shader failed:\n" + result.stdout)

        fragment = output_dir / "powervr-hello-x.frag"
        require(fragment.is_file(), "backend did not write powervr-hello-x.frag")
        source = fragment.read_text()
        require("in vec2 v_ndc;" in source, "hello-X shader lost v_ndc input")
        require("uniform " not in source, "hello-X shader unexpectedly acquired uniforms")
        require(source.count("abs(") >= 2, "hello-X shader lost diagonal distances")
        require("min(" in source, "hello-X shader lost diagonal union")
        require(" ? 1.0 : 0.0" in source, "hello-X shader lost its one-bit ink test")

        validator = shutil.which("glslangValidator")
        if validator is not None:
            validation = subprocess.run(
                [validator, "-l", str(VERTEX), str(fragment)],
                cwd=ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            require(
                validation.returncode == 0,
                "hello-X vertex/fragment program did not link:\n" + validation.stdout,
            )

    print("PowerVR hello-X shader check passed")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"PowerVR hello-X check failed: {error}")
        raise SystemExit(1)
