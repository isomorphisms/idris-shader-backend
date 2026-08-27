# Atomics

Keep atomic type, operation, address space and memory order explicit. Public operation families include load/store/exchange, compare-exchange, fetch add/sub/and/or/xor/min/max. Apple's feature progression later adds texture atomics, floating-point atomics and 64-bit atomics.

Atomics are not the preferred implementation for ordinary independent complex pixels. They become interesting for sparse exceptional-tile queues, counters, work compaction and shared local classification state.
