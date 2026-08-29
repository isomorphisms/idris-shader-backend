#!/usr/bin/env python3
from pathlib import Path
import sys


def fail(message: str) -> None:
    raise SystemExit(f"mali mock check failed: {message}")


def main() -> None:
    if len(sys.argv) != 2:
        fail("expected one generated .mali.mock path")

    path = Path(sys.argv[1])
    text = path.read_text()

    required = [
        "; MOCK MALI PSEUDO-ISA",
        "; NOT EXECUTABLE",
        ".stage fragment",
        ".interface in %v_uv",
        ".interface uniform %u_time",
        "vnormalize",
        "vdot",
        "fcmp.gt",
        "select",
        "fsin",
        "fmul",
        "extract",
        "pack4",
        "store.frag_color",
    ]

    for token in required:
        if token not in text:
            fail(f"missing {token!r}")

    if "#version" in text or "void main" in text:
        fail("mock output fell back to GLSL text")

    print(f"Mali mock smoke OK: {path}")


if __name__ == "__main__":
    main()
