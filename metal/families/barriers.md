# Barriers and memory ordering

Metal exposes threadgroup/SIMD synchronization and memory barriers. Later families also expose stronger atomic memory-order capabilities.

A barrier is a correctness operation, not a performance hint. All participating threads must satisfy the execution/scope rules; divergent barrier placement is dangerous. The compiler should represent barrier scope and affected memory explicitly.
