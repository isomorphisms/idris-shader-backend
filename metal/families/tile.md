# Tile shaders

Apple GPUs are tile-based deferred renderers. From Apple4/A11, Metal exposes programmable tile shaders. A tile shader is compute-like work inside a render pass with tile/imageblock-local access.

Public verbs/concepts include tile functions, `dispatchThreadsPerTile`, tile dimensions, threadgroup-local execution, barriers and imageblock access.

This is a strong fit for an ordinary-tile / exceptional-tile complex renderer: do cheap field work everywhere, then spend extra work only where a tile contains or borders a zero, pole, unresolved singularity, high phase variation or failed regularity test.
