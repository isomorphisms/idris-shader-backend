# Threadgroup memory

Metal threadgroup memory is workgroup-local on-chip scratch storage, analogous in broad purpose to CUDA shared memory, AMD LDS and Vulkan workgroup shared memory. It is not the same thing as an imageblock, although on Apple tile hardware these resources may compete for local storage.

Use it for cooperative samples, reductions, small local coefficient tables and classification metadata. Keep ownership, synchronization and lifetime explicit in the IR.
