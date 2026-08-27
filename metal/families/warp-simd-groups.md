# SIMD-groups (warp/wave analogue)

Metal calls the lockstep local lane group a SIMD-group. Do not expose NVIDIA's word `warp` as the semantic source-language primitive.

Useful families include lane permutation/shuffle, ballots/votes, reductions and matrix operations. Verified public operation families include `simd_sum`, `simd_product`, min/max reductions, bitwise `simd_and`/`simd_or`/`simd_xor`, SIMD permutation, SIMD shift/fill on later families, and SIMD-group matrix operations.

For the complex renderer, use these for tile/region classification, sharing nearby samples, winding/variation reductions and deciding whether local refinement is required. Divergence still matters: a SIMD-group whose lanes take different expensive branches can serialize work.
