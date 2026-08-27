# UAM and GLSL compiler boundary

UAM is not a generic OpenGL runtime. It is a shader compiler designed specifically to produce precompiled DKSH modules for deko3d on Tegra X1. Its path is Mesa GLSL parsing → TGSI → nouveau `nv50_ir` → GM20x-oriented machine code.

## Stages

UAM accepts six stage names: vertex, tessellation control, tessellation evaluation, geometry, fragment and compute. There is no ordinary GL shader-linking phase. Resource bindings therefore have to be explicit enough for the separate stage modules and deko3d command bindings to agree.

## Resource rules

Every UBO, SSBO, sampler and image binding is explicitly numbered in GLSL. The numbering maps one-to-one onto deko3d. Per stage the compiler contract provides 16 UBO slots, 16 SSBO slots, 32 combined image+sampler handles and 8 image slots. Compute has a hardware-specific wrinkle: UBO slots 0–5 are native, while slots 6–15 are implemented through the SSBO route.

Default uniforms outside uniform blocks are deliberately rejected because DKSH/deko3d do not expose the ordinary GL location-and-update mechanism. This is exactly the kind of target fact the shared shader IR should represent as an interface-layout decision rather than leaking into mathematical expressions.

## GLSL compatibility

UAM inherits the GLSL parser and GM20x feature support of its pinned Mesa/nouveau base plus its own patches. Do not advertise a fictional “Nintendo GLSL version.” The acceptance oracle is the pinned UAM compiler. Generated source should use only features that have a checked UAM fixture.

The `DEKO3D` preprocessor symbol is defined to 100. `gl_FragCoord` follows the coordinate convention selected when the deko3d device is created; `origin_upper_left` does not override it and `pixel_center_integer` is unsupported.

## Deliberate code-generation differences

UAM removes or changes several Mesa behaviors for this target. Nonconstant integer divide/modulo is lowered through floating division with a warning rather than the Mesa software routine. 64-bit floating division and square root are approximate native operations and warned. Transform feedback and GLSL subroutines are absent. Bounds checks for SSBO, atomic and image accesses are removed.

These are compiler semantics/cost facts, not mere performance footnotes. If Idriç ever exposes one of those operations, the target checker must either prove its assumptions or reject the shader rather than silently inherit surprising UAM behavior.

## Inspection levels

`--tgsi` exposes the intermediate representation, `--raw` exposes native Maxwell bytecode, and `--out` produces the DKSH module consumed by deko3d. For compiler experiments, capture all three whenever practical. They let us distinguish a source-shape change, an IR-lowering change and an actual machine-code change.

Reference: https://github.com/devkitPro/uam