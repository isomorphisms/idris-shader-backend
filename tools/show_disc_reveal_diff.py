#!/usr/bin/env python3
"""Diagnostic: print the generated DiscReveal diff before the golden check."""

from __future__ import annotations

import difflib
import tempfile
from pathlib import Path

from check_backend import ROOT, compile_source


with tempfile.TemporaryDirectory(prefix="disc-reveal-diff-") as directory:
    temporary = Path(directory)
    result = compile_source(
        "src/Example/DiscReveal.idr",
        temporary,
        "disc-reveal",
    )
    if result.returncode != 0:
        print(result.stdout)
        raise SystemExit(result.returncode)

    actual_path = temporary / "disc-reveal.frag"
    expected_path = ROOT / "generated" / "disc-reveal.frag"
    actual = actual_path.read_text()
    expected = expected_path.read_text()
    print(
        "".join(
            difflib.unified_diff(
                expected.splitlines(True),
                actual.splitlines(True),
                fromfile=str(expected_path),
                tofile="actual disc-reveal.frag",
            )
        )
    )
