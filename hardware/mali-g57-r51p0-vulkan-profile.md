# Mali-G57 / Arm r51p0 Vulkan target evidence

This file records the driver-reported Vulkan profile from the physical Android tablet used for the `target/mali-g57-mc1-valhall` target.

Source command:

```sh
vulkaninfo > ~/mali-g57-vulkaninfo.txt 2>&1
```

Source dump:

- filename: `mali-g57-vulkaninfo.txt`
- line count: 1093
- byte count: 51138
- SHA-256: `b4fec7b3d5345fddb5d2dbd14890484714c2670ebfb5e4740a8deaa9edb86409`

## Physical device

```text
Vulkan Instance Version: 1.3.354
apiVersion        = 1.3.288 (4206880)
driverVersion     = 51.0.0 (213909504)
vendorID          = 0x13b5
deviceID          = 0x90910010
deviceType        = PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU
deviceName        = Mali-G57
pipelineCacheUUID = 2be6d924-cda7-9777-b170-7d3cf8d1fca4
deviceUUID        = 10009190-0100-0000-0000-000000000000
driverUUID        = 8f967700-5b3a-c8a6-03e5-a4f10f238482
driverID          = DRIVER_ID_ARM_PROPRIETARY
driverName        = Mali-G57
driverInfo        = v1.r51p0-00eac0.26a7a06524af59d6533aad5e5bab3098
conformanceVersion = 1.3.8.4
```

## Compute limits

```text
maxComputeSharedMemorySize     = 32768
maxComputeWorkGroupInvocations = 512
maxComputeWorkGroupSize        = 512, 512, 512
maxComputeWorkGroupCount       = 4294967295, 4294967295, 4294967295
maxPushConstantsSize           = 256
minMemoryMapAlignment          = 64
minUniformBufferOffsetAlignment = 16
minStorageBufferOffsetAlignment = 64
nonCoherentAtomSize            = 64
```

## Subgroups

```text
subgroupSize    = 16
minSubgroupSize = 16
maxSubgroupSize = 16
maxComputeWorkgroupSubgroups = 32
```

Subgroups are reported for fragment and compute stages. Supported operations are:

```text
BASIC
VOTE
ARITHMETIC
BALLOT
SHUFFLE
SHUFFLE_RELATIVE
CLUSTERED
QUAD
ROTATE
ROTATE_CLUSTERED
```

The driver also reports:

```text
subgroupSizeControl           = true
computeFullSubgroups          = true
subgroupBroadcastDynamicId    = true
shaderSubgroupExtendedTypes   = true
shaderSubgroupRotate          = true
shaderSubgroupRotateClustered = true
shaderSubgroupUniformControlFlow = true
shaderQuadControl             = true
shaderMaximalReconvergence    = true
```

## Numeric shader support

```text
shaderFloat16 = true
shaderInt8    = true
shaderInt16   = true
shaderInt64   = true
shaderFloat64 = false
```

16-bit storage support:

```text
storageBuffer16BitAccess           = true
uniformAndStorageBuffer16BitAccess = true
storagePushConstant16              = true
storageInputOutput16               = true
```

8-bit storage support:

```text
storageBuffer8BitAccess           = true
uniformAndStorageBuffer8BitAccess = true
storagePushConstant8              = true
```

Float controls:

```text
shaderSignedZeroInfNanPreserveFloat16 = true
shaderSignedZeroInfNanPreserveFloat32 = true
shaderSignedZeroInfNanPreserveFloat64 = false
shaderDenormPreserveFloat16            = true
shaderDenormPreserveFloat32            = true
shaderDenormPreserveFloat64            = false
shaderDenormFlushToZeroFloat16         = true
shaderDenormFlushToZeroFloat32         = true
shaderDenormFlushToZeroFloat64         = false
shaderRoundingModeRTEFloat16           = true
shaderRoundingModeRTEFloat32           = true
shaderRoundingModeRTEFloat64           = false
shaderRoundingModeRTZFloat16           = true
shaderRoundingModeRTZFloat32           = true
shaderRoundingModeRTZFloat64           = false
```

## Integer dot-product acceleration

Reported accelerated:

```text
integerDotProduct8BitUnsignedAccelerated = true
integerDotProduct8BitSignedAccelerated = true
integerDotProduct4x8BitPackedUnsignedAccelerated = true
integerDotProduct4x8BitPackedSignedAccelerated = true
integerDotProductAccumulatingSaturating8BitUnsignedAccelerated = true
integerDotProductAccumulatingSaturating8BitSignedAccelerated = true
integerDotProductAccumulatingSaturating4x8BitPackedUnsignedAccelerated = true
integerDotProductAccumulatingSaturating4x8BitPackedSignedAccelerated = true
```

Mixed-signedness 8-bit dot products and 16/32/64-bit integer dot products are not reported accelerated.

## ARM-specific Vulkan extensions

The physical device advertises:

```text
VK_ARM_rasterization_order_attachment_access : extension revision 1
VK_ARM_shader_core_builtins                  : extension revision 2
VK_ARM_shader_core_properties                : extension revision 1
```

The last two are the next useful interrogation point for shader-core-specific properties beyond the ordinary Vulkan feature/limit surface.

## Queues and memory

The device reports one queue family with two queues:

```text
queueCount = 2
queueFlags = QUEUE_GRAPHICS_BIT | QUEUE_COMPUTE_BIT | QUEUE_TRANSFER_BIT | QUEUE_PROTECTED_BIT
timestampValidBits = 64
```

Memory heaps:

```text
heap 0: 2941546496 bytes (2.74 GiB), DEVICE_LOCAL
heap 1: 104857600 bytes (100 MiB), DEVICE_LOCAL
```

The ordinary heap exposes device-local + host-visible coherent and device-local + host-visible cached memory types, plus lazily allocated transient memory. A separate 100 MiB heap is protected memory.

## Target policy

For the Vulkan/SPIR-V path, compiler decisions should be gated by these driver-reported capabilities rather than inferred from the generic `Mali-G57` product name. Raw Valhall machine-code emission remains a separate target because Vulkan capability discovery does not expose the complete underlying machine-instruction encoding and semantics.
