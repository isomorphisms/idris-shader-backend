# Textures and samplers

Compiler-relevant verbs include sample, sample-compare, gather, read, write, dimension/sample-count queries, LOD queries, swizzle and texture atomics on supporting families.

The complex renderer should not force intermediate mathematical fields through textures when imageblock/threadgroup-local data suffices, but textures remain the portable multipass fallback and the right boundary for persistent images.
