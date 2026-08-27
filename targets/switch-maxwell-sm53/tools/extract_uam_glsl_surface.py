#!/usr/bin/env python3
"""Extract the named GLSL surface from the exact Mesa sources embedded in UAM.

Usage:
  python extract_uam_glsl_surface.py \
    path/to/builtin_functions.cpp \
    path/to/builtin_variables.cpp \
    path/to/glsl_frontend.cpp

UAM configures its Mesa compiler as desktop core GLSL 4.60, but availability of
individual extension-backed operations is still controlled by the context and
UAM patches.  This extractor therefore takes the compiler sources themselves as
the acceptance authority for named built-ins.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ADD_FUNCTION_RE = re.compile(r'add_function\(\s*"([A-Za-z_]\w*)"')
# create_builtins uses macros such as F(sin), FD(sqrt), FI64(abs), etc.
MACRO_CALL_RE = re.compile(r'^\s*[A-Z][A-Z0-9_]*\(\s*([A-Za-z_]\w*)\s*\)\s*$', re.M)
GL_BUILTIN_RE = re.compile(r'"(gl_[A-Za-z0-9_]+)"')
GLSL_VERSION_RE = re.compile(r'GLSLVersion\s*=\s*(\d+)')


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit(
            "usage: extract_uam_glsl_surface.py builtin_functions.cpp "
            "builtin_variables.cpp glsl_frontend.cpp"
        )

    functions = Path(sys.argv[1]).read_text(encoding="utf-8")
    variables = Path(sys.argv[2]).read_text(encoding="utf-8")
    frontend = Path(sys.argv[3]).read_text(encoding="utf-8")

    names = set(ADD_FUNCTION_RE.findall(functions))
    names.update(MACRO_CALL_RE.findall(functions))
    # Mesa's __intrinsic_* implementation helpers are not source-level GLSL names.
    names = {n for n in names if not n.startswith("__intrinsic_")}

    versions = GLSL_VERSION_RE.findall(frontend)
    print("UAM CONFIGURED GLSL VERSION")
    print(versions[-1] if versions else "UNKNOWN")

    print("\nUAM/MESA SOURCE-LEVEL GLSL BUILT-IN FUNCTION NAMES")
    for name in sorted(names):
        print(name)

    print("\nUAM/MESA GLSL BUILT-IN VARIABLE NAMES")
    for name in sorted(set(GL_BUILTIN_RE.findall(variables))):
        print(name)


if __name__ == "__main__":
    main()
