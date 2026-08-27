# Metal 4-era mechanisms

Apple's newer Metal model adds facilities including argument tables, command allocators, decoupled command queues, command barriers, dedicated compilation contexts, flexible pipelines and tensor / machine-learning operations on supporting systems.

These are public API/compiler capabilities rather than GPU machine instructions. They should be catalogued separately from shader arithmetic and only pulled into the backend when a concrete renderer workload needs them.
