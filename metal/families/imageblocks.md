# Imageblocks

Imageblocks are programmable structured per-pixel data resident in tile memory for the lifetime of the tile/render pass. Public MSL/API concepts include `imageblock<...>`, `[[imageblock_data]]`, `[[threadgroup_imageblock]]`, imageblock data access and explicit imageblock dimensions.

They can hold intermediate mathematical state such as complex value, phase, log modulus, derivative estimate, singularity flags and refinement score without round-tripping each field through ordinary device-memory textures.

Imageblock capacity shares finite on-chip tile storage with other tile/threadgroup uses; query and size rather than assuming an unlimited scratchpad.
