# Precision and numeric types

Track at least Float16 (`half`), Float32 (`float`), any available wider floating-point path, bfloat, integer widths and atomic widths independently.

For this project, Float32 remains the ordinary correctness baseline. Float16 is worth exploiting for storage or demonstrably safe local calculations; do not replace singularity-sensitive arithmetic with half precision by default. Exceptional tiles are a natural place to *increase* rather than decrease numerical care.
