module Backend.FragmentMock.Targets

%default total

public export
record MockTarget where
  constructor MkMockTarget
  codegenName : String
  targetName : String
  targetFamily : String
  targetStatus : String

public export
powervrGE8322 : MockTarget
powervrGE8322 = MkMockTarget
  "powervr-ge8322-mock"
  "PowerVR GE8322"
  "OpenGL ES / PowerVR"
  "dedicated target branch exists; hardware acceptance remains separate"

public export
maliG57Valhall : MockTarget
maliG57Valhall = MkMockTarget
  "mali-g57-valhall-mock"
  "Arm Mali-G57 MC1 / Valhall"
  "Valhall"
  "mock final emission only"

public export
switchMaxwellSM53 : MockTarget
switchMaxwellSM53 = MkMockTarget
  "switch-maxwell-sm53-mock"
  "Nintendo Switch / Tegra X1"
  "NVIDIA Maxwell SM53"
  "dedicated target branch exists; mock does not encode Maxwell instructions"

public export
steamRDNA2Vulkan : MockTarget
steamRDNA2Vulkan = MkMockTarget
  "steam-rdna2-vulkan-mock"
  "Steam-class AMD RDNA2"
  "Vulkan / RDNA2"
  "dedicated target branch exists; mock does not emit SPIR-V or RDNA2 machine code"

public export
webgpuWGSL : MockTarget
webgpuWGSL = MkMockTarget
  "webgpu-wgsl-mock"
  "WebGPU"
  "WGSL"
  "dedicated target branch exists; mock does not emit WGSL"

public export
appleMetal : MockTarget
appleMetal = MkMockTarget
  "apple-metal-mock"
  "Apple GPU"
  "Metal / Apple tile GPU"
  "research target; mock does not claim imageblock or tile-shader lowering"

public export
nvidiaHopperSM90 : MockTarget
nvidiaHopperSM90 = MkMockTarget
  "nvidia-hopper-sm90-mock"
  "NVIDIA Hopper"
  "SM90"
  "covers the H100/H200 target notes at architecture level"

public export
nvidiaBlackwellSM100 : MockTarget
nvidiaBlackwellSM100 = MkMockTarget
  "nvidia-blackwell-sm100-mock"
  "NVIDIA Blackwell"
  "SM100"
  "covers the B200/GB200 target notes at architecture level"

public export
adrenoTile : MockTarget
adrenoTile = MkMockTarget
  "adreno-tile-mock"
  "Qualcomm Adreno"
  "tile/GMEM Vulkan-family notes"
  "notes-only research target; no dedicated target branch yet"

||| Current fragment-shader architecture/dialect targets for which this
||| repository has either a dedicated target branch or explicit architecture
||| notes.  Product aliases that share an architecture (H100/H200, B200/GB200)
||| intentionally share one mock.
public export
fragmentMockTargets : List MockTarget
fragmentMockTargets =
  [ powervrGE8322
  , maliG57Valhall
  , switchMaxwellSM53
  , steamRDNA2Vulkan
  , webgpuWGSL
  , appleMetal
  , nvidiaHopperSM90
  , nvidiaBlackwellSM100
  , adrenoTile
  ]
