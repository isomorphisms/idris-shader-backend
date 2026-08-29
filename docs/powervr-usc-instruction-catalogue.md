# PowerVR USC instruction catalogue — documentation stub

This is a human-readable index for the **public Imagination PowerVR instruction-set reference**.
It is intentionally separate from the Idris/GLSL operation glossary.

Important boundary:

```text
Idris source helpers
    ↓ this repository
GLSL ES
    ↓ phone's PowerVR driver/compiler
PowerVR USC/ISR instructions
```

This repository does **not** currently choose or emit USC instructions directly. A GLSL operation
such as `dot(a,b)` does not have a guaranteed one-to-one PowerVR instruction. The vendor compiler
may fuse, split, reorder, predicate, or otherwise lower it according to the exact GPU generation.

The public reference currently available from Imagination includes a Series 6 USC overview. Do not
assume every mnemonic below exists unchanged on every PowerVR generation or on a particular phone
without identifying that device's actual core.

Official reference, checked 2026-08-26:
https://docs.imgtec.com/reference-manuals/powervr-instruction-set-reference/html/index.html

## Why PowerVR instructions can look like groups rather than one-at-a-time CPU assembly

The public reference describes instruction **groups** and co-issue. Multiple operations can occupy
different phases of the USC pipeline in one group; the reference says the ALU pipeline can issue up
to six operations in a clock when the allowed phases/resources line up. This is one reason not to
expect a simple one-source-expression = one-hardware-instruction correspondence.

Reference:
https://docs.imgtec.com/reference-manuals/powervr-instruction-set-reference/html/topics/structure-of-isr-assembly-code.html

## Floating-point instructions

Current public index:

`FMAD`, `FADD`, `FMUL`, `FRCP`, `FRSQ`, `FSQRT`, `FLOG`, `FEXP`, `GCMP`, `GEXP`,
`F16SOP`, `SOPMOV`, `F16SOP.MAD`, `F16SOP.U8`, `SOPMOV.U8`, `F16SOP.U8MAD`,
`SOPU8MADMOV`, `MBYP`, `FDSX`, `FDSY`, `FDSXF`, `FDSYF`, `CONVERTTOF64`,
`CONVERTFROMF64`, `FSINC`, `FARCTANC`, `FRED`, `GTA`.

The immediately useful plain-language anchors are:

| Mnemonic | Read it as |
| --- | --- |
| `FMAD` | floating-point multiply then add |
| `FADD` | floating-point add |
| `FMUL` | floating-point multiply |
| `FRCP` | floating-point reciprocal |
| `FRSQ` | floating-point reciprocal square root |
| `FSQRT` | floating-point square root |
| `FLOG` | floating-point logarithm |
| `FEXP` | floating-point exponential |
| `F16SOP` | 16-bit floating-point sum-of-products family |
| `FSINC` | sine/cosine complex instruction family; inspect the exact reference page before relying on details |
| `FARCTANC` | arctangent complex instruction family; inspect the exact reference page before relying on details |

TODO: add one ordinary-language sentence, operand sketch, and a tiny GLSL example for every remaining
floating instruction directly from its official page rather than guessing from the mnemonic.

## Data movement instructions

`MOV`, `MOVC`, `PCK`, `UNPCK`.

| Mnemonic | Read it as |
| --- | --- |
| `MOV` | move/copy data |
| `MOVC` | conditional move |
| `PCK` | pack values into a representation |
| `UNPCK` | unpack values from a representation |

## Integer instructions

`UADD8`, `UMUL8`, `UMAD8`, `IADD8`, `IMUL8`, `IMAD8`,
`UADD16`, `UMUL16`, `UMAD16`, `IADD16`, `IMUL16`, `IMAD16`,
`ADD64`, `UADD6432`, `SADD6432`, `UMADD32`, `SMADD32`, `UMADD64`, `SMADD64`.

Name-reading convention in this family: `U` is unsigned, `I`/`S` marks signed forms in the
published names, `ADD` is addition, `MUL` is multiplication, `MAD`/`MADD` is multiply-add, and the
numbers denote operand/result widths described by the individual instruction page.

## Test/comparison instructions

`TSTZ`, `TSTGZ`, `TSTGEZ`, `TSTC`, `TSTE`, `TSTG`, `TSTGE`, `TSTNE`, `TSTL`,
`TSTLE`, `TSTMIN`, `TSTMAX`.

Useful anchors: `TSTL` is test-less-than and `TSTLE` is test-less-than-or-equal. These are closer to
what an expression such as `a < b` may eventually become, but the driver remains free to use another
valid lowering.

## Bitwise instructions

`AND`, `OR`, `XOR`, `NAND`, `NOR`, `XNOR`, `SHFL`, `REV`, `LSL`, `CPS`, `SHR`,
`ASR`, `ROL`, `TZ`, `TNZ`, `BYP`, `MSK`, `CBS`, `FTB`, `FTB_SHI`, `FTB_MSB`.

The obvious Boolean names have their usual meanings. For the shorter PowerVR-specific spellings,
fill in the long description from the individual official page before using them as teaching names.

## Backend instructions

The public backend-instruction table lists:

`UVSW`, `TESSW`, `ATST`, `DEPTHF`, `FITR`, `FITRP`, `IDF`, `LD`, `ST`,
`ST.TEXELMODE`, `SMP` (`SMP1D`, `SMP2D`, `SMP3D`), `ATOM`.

Plain-language anchors from the official table:

| Mnemonic | Meaning |
| --- | --- |
| `ATST` | alpha test |
| `DEPTHF` | depth feedback |
| `FITR` | iterate/interpolate value(s) |
| `IDF` | issue a data fence through the memory subsystem |
| `LD` | load from memory |
| `ST` | store to memory |
| `SMP1D/2D/3D` | sample a 1D/2D/3D texture |
| `ATOM` | atomic memory operation family |

Reference:
https://docs.imgtec.com/reference-manuals/powervr-instruction-set-reference/html/topics/backend-instruction.html

## Flow-control instructions

`BA`, `BAL`, `BR`, `BRL`, `BPRET`, `LAPC`, `SAVL`.

From the official table: `BA` is absolute branch, `BR` is relative branch, the `L` forms save a link
pointer, `BPRET` returns to a saved breakpoint address, `LAPC` links the saved address back to the
program counter, and `SAVL` saves the link address.

Reference:
https://docs.imgtec.com/reference-manuals/powervr-instruction-set-reference/html/topics/flow-control-instructions.html

## Conditional instructions

`CNDST`, `CNDEF`, `CNDSM`, `CNDLT`, `CNDEND`, `CNDSETL`, `CNDLPC`.

TODO: expand these from their official pages. Do not infer semantics solely from the abbreviation.

## Data-access instructions

`WDF`, `ITRSMP` (`ITRSMP1D`, `ITRSMP2D`, `ITRSMP3D`), `SBO`, `DITR`.

TODO: expand these from their official pages and relate them to interpolation/texture/data access in
the generated shaders.

## What to record when we inspect a real phone

For an actual compiled probe, record:

1. `GL_VENDOR`, `GL_RENDERER`, GLES version, and GLSL version.
2. Exact source probe and generated `.frag` file.
3. Exact device/GPU generation if it can be identified reliably.
4. Driver/compiler version.
5. Any available disassembly or compiler report, without pretending a Series 6 public mnemonic must
   match a different generation.
6. Source operation → generated GLSL → observed USC instructions, keeping this as evidence rather
   than a permanent one-to-one compiler rule.
