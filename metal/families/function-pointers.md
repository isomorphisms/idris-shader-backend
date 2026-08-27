# Function pointers / dynamic functions

Later Apple GPU families expose dynamic libraries and function pointers in compute/render contexts. They can support more flexible shader specialization, but the current Idriç shader subset intentionally prefers statically knowable first-order computation.

Treat function pointers as an optional lowering capability rather than relaxing the language's semantic restrictions automatically.
