#!/usr/bin/env python3
"""Tiny interpreter for the shared fragment-target mock pseudo-ISA.

This is intentionally not a GPU emulator.  It executes the deterministic
SSA-like text emitted by Backend.FragmentMock so compiler tests can distinguish
"the checked program ran under the mock semantics" from "text was emitted".
"""

from __future__ import annotations

from dataclasses import dataclass
import math
from pathlib import Path
import re
from typing import Any, Mapping, Sequence


Value = float | int | bool | tuple[float, ...] | tuple[bool, ...]


@dataclass(frozen=True)
class Program:
    interfaces: tuple[str, ...]
    bindings: tuple[tuple[str, str, tuple[str, ...]], ...]
    result: str


_BINDING = re.compile(r"^%([^ ]+)\s*:\s*([^=]+?)\s*=\s*([^ ]+)(?:\s+(.*))?$")
_INTERFACE = re.compile(r"^\.interface\s+(?:in|uniform)\s+%([^ ]+)\s*:\s*(.+)$")


def parse_program(path: str | Path) -> Program:
    interfaces: list[str] = []
    bindings: list[tuple[str, str, tuple[str, ...]]] = []
    result: str | None = None

    for raw in Path(path).read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue

        interface = _INTERFACE.match(line)
        if interface:
            interfaces.append(interface.group(1))
            continue

        if line.startswith("store.frag_color "):
            result = line.removeprefix("store.frag_color ").strip()
            continue

        if line.startswith("%"):
            match = _BINDING.match(line)
            if not match:
                raise ValueError(f"cannot parse mock binding: {line}")
            name, _ty, op, arg_text = match.groups()
            args = tuple(part.strip() for part in (arg_text or "").split(",") if part.strip())
            bindings.append((name, op, args))

    if result is None:
        raise ValueError("mock program has no store.frag_color")

    return Program(tuple(interfaces), tuple(bindings), result)


def _vector(value: Value) -> tuple[float, ...]:
    if isinstance(value, tuple):
        return tuple(float(item) for item in value)
    raise TypeError(f"expected vector, received {value!r}")


def _scalar(value: Value) -> float:
    if isinstance(value, bool) or isinstance(value, tuple):
        raise TypeError(f"expected scalar float, received {value!r}")
    return float(value)


def _bool(value: Value) -> bool:
    if isinstance(value, bool):
        return value
    raise TypeError(f"expected bool, received {value!r}")


def _operand(token: str, env: Mapping[str, Value]) -> Value:
    token = token.strip()
    if token.startswith("%"):
        name = token[1:]
        if name not in env:
            raise KeyError(f"unknown mock value %{name}")
        return env[name]
    if token == "true":
        return True
    if token == "false":
        return False
    return float(token)


def _binary_vector(left: Value, right: Value, fn) -> tuple[float, ...]:
    left_vec = _vector(left)
    right_vec = _vector(right)
    if len(left_vec) != len(right_vec):
        raise ValueError("mock vector width mismatch")
    return tuple(fn(a, b) for a, b in zip(left_vec, right_vec))


def _execute_op(op: str, args: Sequence[Value]) -> Value:
    if op == "fneg":
        return -_scalar(args[0])
    if op == "fabs":
        return abs(_scalar(args[0]))
    if op == "fsqrt":
        return math.sqrt(_scalar(args[0]))
    if op == "fsin":
        return math.sin(_scalar(args[0]))
    if op == "fcos":
        return math.cos(_scalar(args[0]))
    if op == "ffloor":
        return float(math.floor(_scalar(args[0])))
    if op == "ffract":
        value = _scalar(args[0])
        return value - math.floor(value)
    if op == "flog":
        return math.log(_scalar(args[0]))

    if op == "fadd":
        return _scalar(args[0]) + _scalar(args[1])
    if op == "fsub":
        return _scalar(args[0]) - _scalar(args[1])
    if op == "fmul":
        return _scalar(args[0]) * _scalar(args[1])
    if op == "fdiv":
        return _scalar(args[0]) / _scalar(args[1])
    if op == "fmin":
        return min(_scalar(args[0]), _scalar(args[1]))
    if op == "fmax":
        return max(_scalar(args[0]), _scalar(args[1]))
    if op == "fatan2":
        return math.atan2(_scalar(args[0]), _scalar(args[1]))
    if op == "fpow":
        return math.pow(_scalar(args[0]), _scalar(args[1]))

    if op == "fclamp":
        value, low, high = map(_scalar, args)
        return min(max(value, low), high)
    if op == "fmix":
        left, right, weight = map(_scalar, args)
        return left * (1.0 - weight) + right * weight
    if op == "fsmoothstep":
        low, high, value = map(_scalar, args)
        if low == high:
            return 0.0 if value < low else 1.0
        t = min(max((value - low) / (high - low), 0.0), 1.0)
        return t * t * (3.0 - 2.0 * t)

    if op == "fcmp.lt":
        return _scalar(args[0]) < _scalar(args[1])
    if op == "fcmp.le":
        return _scalar(args[0]) <= _scalar(args[1])
    if op == "fcmp.eq":
        return _scalar(args[0]) == _scalar(args[1])
    if op == "fcmp.ge":
        return _scalar(args[0]) >= _scalar(args[1])
    if op == "fcmp.gt":
        return _scalar(args[0]) > _scalar(args[1])

    if op == "bnot":
        return not _bool(args[0])
    if op == "band":
        return _bool(args[0]) and _bool(args[1])
    if op == "bor":
        return _bool(args[0]) or _bool(args[1])
    if op == "itof":
        return float(_scalar(args[0]))

    if op == "load.index":
        vector = _vector(args[0])
        return vector[int(_scalar(args[1]))]
    if op in {"pack2", "pack3", "pack4"}:
        return tuple(_scalar(value) for value in args)
    if op == "vadd":
        return _binary_vector(args[0], args[1], lambda a, b: a + b)
    if op == "vsub":
        return _binary_vector(args[0], args[1], lambda a, b: a - b)
    if op == "vscale":
        scalar = _scalar(args[0])
        return tuple(scalar * value for value in _vector(args[1]))
    if op == "vdot":
        left = _vector(args[0])
        right = _vector(args[1])
        if len(left) != len(right):
            raise ValueError("mock dot width mismatch")
        return sum(a * b for a, b in zip(left, right))
    if op == "vlength":
        return math.sqrt(sum(value * value for value in _vector(args[0])))
    if op == "vnormalize":
        vector = _vector(args[0])
        length = math.sqrt(sum(value * value for value in vector))
        return tuple(value / length for value in vector)
    if op == "extract":
        return _vector(args[0])[int(_scalar(args[1]))]
    if op == "select":
        return args[1] if _bool(args[0]) else args[2]

    raise ValueError(f"unknown fragment mock opcode {op!r}")


def execute(program: Program, inputs: Mapping[str, Value]) -> tuple[float, ...]:
    missing = [name for name in program.interfaces if name not in inputs]
    if missing:
        raise ValueError(f"missing mock inputs: {', '.join(missing)}")

    env: dict[str, Value] = dict(inputs)
    for name, op, arg_tokens in program.bindings:
        values = [_operand(token, env) for token in arg_tokens]
        env[name] = _execute_op(op, values)

    result = _operand(program.result, env)
    return _vector(result)
