#!/usr/bin/env python3
"""Cheap checks which remain useful when glslangValidator is unavailable."""

from __future__ import annotations

import math
import shutil
import subprocess
import sys
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL  {message}")
    print(f"PASS  {message}")


def balanced(source: str, opening: str, closing: str) -> bool:
    depth = 0
    for character in source:
        if character == opening:
            depth += 1
        elif character == closing:
            depth -= 1
            if depth < 0:
                return False
    return depth == 0


def validate_with_glslang(paths: list[Path]) -> None:
    validator = shutil.which("glslangValidator")
    if validator is None:
        print("SKIP  glslangValidator is not installed")
        return
    for path in paths:
        subprocess.run([validator, "-S", path.suffix[1:], str(path)], check=True)
        print(f"PASS  glslangValidator {path.name}")


def sphere_value(x: float, y: float, z: float) -> float:
    return x * x + y * y + z * z - 1.0


def sphere_gradient(x: float, y: float, z: float) -> tuple[float, float, float]:
    return 2.0 * x, 2.0 * y, 2.0 * z


def main() -> None:
    paths = [Path(argument) for argument in sys.argv[1:]]
    require(len(paths) >= 2, "shader paths supplied")
    sources = [path.read_text(encoding="utf-8") for path in paths]

    for path, source in zip(paths, sources):
        require(source.startswith("#version 300 es\n"), f"{path.name} targets GLSL ES 3.00")
        require(balanced(source, "(", ")"), f"{path.name} has balanced parentheses")
        require(balanced(source, "{", "}"), f"{path.name} has balanced braces")
        require("nan" not in source.lower() and "inf" not in source.lower(),
                f"{path.name} has no non-finite literals")

    require(math.isclose(sphere_value(1.0, 0.0, 0.0), 0.0),
            "independent polynomial oracle")
    require(sphere_gradient(1.0, 2.0, 3.0) == (2.0, 4.0, 6.0),
            "independent gradient oracle")
    validate_with_glslang(paths)


if __name__ == "__main__":
    main()
