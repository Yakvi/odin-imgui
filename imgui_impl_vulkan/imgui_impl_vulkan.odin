package imgui_impl_vulkan

import imgui "../"
import vk "vendor:vulkan"

when      ODIN_OS == .Windows { foreign import lib "../imgui_windows_x64.lib" }
else when ODIN_OS == .Linux   { foreign import lib "../imgui_linux_x64.a" }
else when ODIN_OS == .Darwin  {
	when ODIN_ARCH == .amd64 { foreign import lib "../imgui_darwin_x64.a" } else { foreign import lib "../imgui_darwin_arm64.a" }
}

// imgui_impl_vulkan.h
// Last checked `v1.92.4-docking`

// Initialization data, for ImGui_ImplVulkan_Init()
// - VkDescriptorPool should be created with VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
//   and must contain a pool size large enough to hold an ImGui VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER descriptor.
// - When using dynamic rendering, set UseDynamicRendering=true and fill PipelineRenderingCreateInfo structure.
// [Please zero-clear before use!]
InitInfo :: struct {
	ApiVersion:     u32,
	Instance:       vk.Instance,
	PhysicalDevice: vk.PhysicalDevice,
	Device:         vk.Device,
	QueueFamily:    u32,
	Queue:          vk.Queue,
	DescriptorPool: vk.DescriptorPool,  // See requirements in note above
	DescriptorPoolSize: u32,            // (Optional) Set to create internal descriptor pool instead of using DescriptorPool
	MinImageCount:  u32,                // >= 2
	ImageCount:     u32,                // >= MinImageCount
	PipelineCache:  vk.PipelineCache,   // (Optional)

	// Pipeline
    PipelineInfoMain: PipelineInfo,         // Infos for Main Viewport (created by app/user)
    PipelineInfoForViewports: PipelineInfo, // Infos for Secondary Viewports (created by backend)

	// (Optional) Dynamic Rendering
    // Need to explicitly enable VK_KHR_dynamic_rendering extension to use this, even for Vulkan 1.3 + setup PipelineInfoMain.PipelineRenderingCreateInfo and PipelineInfoViewports.PipelineRenderingCreateInfo.
	UseDynamicRendering:         bool,

	// (Optional) Allocation, Debugging
	Allocator:         ^vk.AllocationCallbacks,
	CheckVkResultFn:   proc "c" (err: vk.Result),
	MinAllocationSize: vk.DeviceSize, // Minimum allocation size. Set to 1024*1024 to satisfy zealous best practices validation layer and waste a little memory.

    // (Optional) Customize default vertex/fragment shaders.
    // - if .sType == VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO we use specified structs, otherwise we use defaults.
    // - Shader inputs/outputs need to match ours. Code/data pointed to by the structure needs to survive for whole during of backend usage.
	CustomShaderVertCreateInfo: vk.ShaderModuleCreateInfo,
	CustomShaderFragCreateInfo: vk.ShaderModuleCreateInfo,
}

// Specify settings to create pipeline and swapchain
PipelineInfo :: struct {
    // For Main viewport only
    RenderPass: vk.RenderPass, // Ignored if using dynamic rendering

    // For Main and Secondary viewports
    Subpass: u32,
    MSAASamples: vk.SampleCountFlags,                            // 0 defaults to VK_SAMPLE_COUNT_1_BIT
    PipelineRenderingCreateInfo: vk.PipelineRenderingCreateInfo, // Optional, valid if .sType == VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO_KHR

    // For Secondary viewports only (created/managed by backend)
    SwapChainImageUsage: vk.ImageUsageFlags // Extra flags for vkCreateSwapchainKHR() calls for secondary viewports. We automatically add VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT. You can add e.g. VK_IMAGE_USAGE_TRANSFER_SRC_BIT if you need to capture from viewports.
}

@(link_prefix="ImGui_ImplVulkan_")
foreign lib {
	Init :: proc(info: ^InitInfo) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc() ---
	RenderDrawData :: proc(draw_data: ^imgui.DrawData, command_buffer: vk.CommandBuffer, pipeline: vk.Pipeline = {}) ---
	SetMinImageCount :: proc(min_image_count: u32) --- // To override MinImageCount after initialization (e.g. if swap chain is recreated)

	// (Advanced) Use e.g. if you need to recreate pipeline without reinitializing the backend (see #8110, #8111)
	// The main window pipeline will be created by ImGui_ImplVulkan_Init() if possible (== RenderPass xor (UseDynamicRendering && PipelineRenderingCreateInfo->sType == VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO_KHR))
	// Else, the pipeline can be created, or re-created, using ImGui_ImplVulkan_CreateMainPipeline() before rendering.
	CreateMainPipeline :: proc(info: ^PipelineInfo) ---

	// (Advanced) Use e.g. if you need to precisely control the timing of texture updates (e.g. for staged rendering), by setting ImDrawData::Textures = NULL to handle this manually.
	UpdateTexture :: proc(tex: ^imgui.TextureData) ---

	// Register a texture (VkDescriptorSet == ImTextureID)
	// FIXME: This is experimental in the sense that we are unsure how to best design/tackle this problem
	// Please post to https://github.com/ocornut/imgui/pull/914 if you have suggestions.
	AddTexture :: proc(sampler: vk.Sampler, image_view: vk.ImageView, image_layout: vk.ImageLayout) -> vk.DescriptorSet ---
	RemoveTexture :: proc(descriptor_set: vk.DescriptorSet) ---

	// Optional: load Vulkan functions with a custom function loader
	// This is only useful with IMGUI_IMPL_VULKAN_NO_PROTOTYPES / VK_NO_PROTOTYPES
	LoadFunctions :: proc(api_version: u32, loader_func: proc "c" (function_name: cstring, user_data: rawptr) -> vk.ProcVoidFunction, user_data: rawptr = nil) -> bool ---
}

// [BETA] Selected render state data shared with callbacks.
// This is temporarily stored in GetPlatformIO().Renderer_RenderState during the ImGui_ImplVulkan_RenderDrawData() call.
// (Please open an issue if you feel you need access to more data)
RenderState :: struct {
	CommandBuffer: vk.CommandBuffer,
	Pipeline: vk.Pipeline,
	PipelineLayout: vk.PipelineLayout,
}

// There are some more Vulkan functions/structs, but they aren't necessary
