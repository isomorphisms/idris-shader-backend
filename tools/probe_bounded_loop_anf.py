#!/usr/bin/env python3
"""Expose the ANF shape of the admitted bounded-iteration source form."""

from __future__ import annotations

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


def main() -> int:
    require(BACKEND.is_file(), "backend executable is missing; run make backend")
    with tempfile.TemporaryDirectory(prefix="bounded-loop-anf-") as directory:
        temporary = Path(directory)
        anf_path = temporary / "bounded-loop.anf"
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
                f"dump-anf={anf_path}",
                SOURCE,
                "-o",
                "bounded-loop-probe",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        require(anf_path.is_file(), "backend did not dump bounded-loop ANF:\n" + result.stdout)
        print("BOUNDED_LOOP_ENTRY_ANF")
        print(anf_path.read_text())
        require(
            "recursive shader call is not supported" in result.stdout,
            "probe unexpectedly stopped exposing the pre-loop-lowering state:\n" + result.stdout,
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"bounded loop ANF probe failed: {error}", file=sys.stderr)
        raise SystemExit(1)
