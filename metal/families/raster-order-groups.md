# Raster-order groups

Raster-order groups provide ordered access among overlapping fragment threads. The public MSL attribute is `[[raster_order_group(n)]]` on appropriate imageblock data.

This mechanism is distinct from a generic barrier and distinct from SIMD-group execution. It is useful only when the algorithm genuinely needs deterministic ordered read/modify/write behavior for overlapping fragments.
