#!/usr/bin/env python3
"""End-to-end checks for the registered Idris2 -> GLSL ES code generator."""

from __future__ import annotations

import difflib
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "build" / "exec" / "idris2-glsles"


def compile_source(
    source: str,
    output_dir: Path,
    output_name: str,
    *,
    dump_ir: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    directive = [] if dump_ir is None else ["--directive", f"dump-ir={dump_ir}"]
    return subprocess.run(
        [
            str(BACKEND),
            "--cg",
            "glsles",
            "--source-dir",
            "src",
            "--output-dir",
            str(output_dir),
            *directive,
            source,
            "-o",
            output_name,
        ],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    require(BACKEND.is_file(), "backend executable is missing; run make backend")
    golden = ROOT / "generated" / "compiler-sphere.frag"
    golden_ir = ROOT / "generated" / "compiler-sphere.ir"
    reveal_golden = ROOT / "generated" / "disc-reveal.frag"
    reveal_golden_ir = ROOT / "generated" / "disc-reveal.ir"

    with tempfile.TemporaryDirectory(prefix="idris-glsles-") as directory:
        temporary = Path(directory)
        ir_dump = temporary / "compiler-sphere.ir"
        good = compile_source(
            "src/Example/CompilerSphere.idr",
            temporary,
            "compiler-sphere",
            dump_ir=ir_dump,
        )
        require(good.returncode == 0, "ordinary Idris shader failed:\n" + good.stdout)
        actual_path = temporary / "compiler-sphere.frag"
        require(actual_path.is_file(), "backend did not write compiler-sphere.frag")
        actual = actual_path.read_text()
        expected = golden.read_text()
        require(ir_dump.is_file(), "dump-ir directive did not write the typed IR")
        dumped = ir_dump.read_text()
        expected_ir = golden_ir.read_text()
        require(
            dumped.startswith("fragment(v_uv : in vec2, u_time : uniform float) -> vec4"),
            "typed IR dump lost interface types",
        )
        require("_idris_t" in dumped and "return " in dumped, "typed IR dump is incomplete")
        require(dumped == expected_ir, "typed IR dump differs from golden")
        require(actual.count("sin(u_time)") == 1, "ANF CSE did not merge repeated sin(u_time)")
        require(" ? " in actual, "Idris conditional was not lowered to GLSL")
        require("dot(" in actual, "dimension-polymorphic dot product was not lowered")
        require(
            "square" not in actual and "safeNormalize" not in actual,
            "first-order helpers were not specialized into the fragment body",
        )
        if actual != expected:
            difference = "".join(
                difflib.unified_diff(
                    expected.splitlines(True),
                    actual.splitlines(True),
                    fromfile=str(golden),
                    tofile=str(actual_path),
                )
            )
            raise AssertionError("compiler shader differs from golden:\n" + difference)

        reveal_ir_dump = temporary / "disc-reveal.ir"
        reveal = compile_source(
            "src/Example/DiscReveal.idr",
            temporary,
            "disc-reveal",
            dump_ir=reveal_ir_dump,
        )
        require(reveal.returncode == 0, "disc reveal shader failed:\n" + reveal.stdout)
        reveal_path = temporary / "disc-reveal.frag"
        require(reveal_path.is_file(), "backend did not write disc-reveal.frag")
        require(reveal_ir_dump.is_file(), "backend did not dump disc-reveal.ir")
        reveal_source = reveal_path.read_text()
        expected_reveal = reveal_golden.read_text()
        reveal_ir = reveal_ir_dump.read_text()
        expected_reveal_ir = reveal_golden_ir.read_text()
        required_interface = [
            "in vec2 v_ndc;",
            "uniform vec2 u_center;",
            "uniform float u_half_height;",
            "uniform float u_aspect;",
            "uniform vec2 u_disc_center;",
            "uniform float u_disc_radius;",
            "uniform vec2 u_resolution;",
        ]
        for declaration in required_interface:
            require(declaration in reveal_source, "disc reveal interface lost " + declaration)
        require("sin(" in reveal_source, "dark-gray reveal texture was not emitted")
        require(" ? 0.0 : " in reveal_source, "negative-radius no-mask sentinel was not emitted")
        require(reveal_source == expected_reveal, "disc reveal shader differs from golden")
        require(reveal_ir == expected_reveal_ir, "disc reveal IR differs from golden")

        failures = [
            (
                "src/Test/Backend/BadResult.idr",
                "bad-result",
                "fragment entry must return SVec 4",
            ),
            (
                "src/Test/Backend/BadRecursion.idr",
                "bad-recursion",
                "recursive shader call is not supported",
            ),
            (
                "src/Test/Backend/BadHeap.idr",
                "bad-heap",
                "heap-shaped constructor values are not supported",
            ),
            (
                "src/Test/Backend/BadDescriptor.idr",
                "bad-descriptor",
                "annotation describes 1 arguments",
            ),
        ]
        for source, output, phrase in failures:
            result = compile_source(source, temporary, output)
            require("Error:" in result.stdout, source + " unexpectedly compiled")
            require(
                not (temporary / f"{output}.frag").exists(),
                source + " wrote a shader despite rejection",
            )
            require(phrase in result.stdout, source + " had the wrong diagnostic:\n" + result.stdout)

        dimensions = compile_source(
            "src/Test/Backend/BadDimensions.idr", temporary, "bad-dimensions"
        )
        require("Error:" in dimensions.stdout, "mismatched vector widths unexpectedly typechecked")
        require(
            "SVec 2" in dimensions.stdout and "SVec 3" in dimensions.stdout,
            "dimension mismatch did not report both widths:\n" + dimensions.stdout,
        )

    print("backend checks passed: source lowering, two goldens, four rejections, dimension proof")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"backend check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
