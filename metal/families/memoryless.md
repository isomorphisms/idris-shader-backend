# Memoryless attachments

Apple-family GPUs support memoryless render targets whose contents live only for the render pass and need not be backed by normal device memory. This complements the tile-based renderer but is not equivalent to programmable imageblocks.

Use memoryless storage for transient attachments when their values need no persistence after the pass.
