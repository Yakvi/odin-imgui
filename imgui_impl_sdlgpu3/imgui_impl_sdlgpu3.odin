package imgui_impl_sdlgpu3

import imgui "../"
import sdl "vendor:sdl3"

when      ODIN_OS == .Windows { foreign import lib "../imgui_windows_x64.lib" }
else when ODIN_OS == .Linux   { foreign import lib "../imgui_linux_x64.a" }
else when ODIN_OS == .Darwin  {
	when ODIN_ARCH == .amd64 { foreign import lib "../imgui_darwin_x64.a" } else { foreign import lib "../imgui_darwin_arm64.a" }
}

// imgui_impl_sdlgpu3.h
// Last checked `v1.92.4-docking` (e7d2d63)
//
// Initialization data, for ImGui_ImplSDLGPU_Init()
// - Remember to set ColorTargetFormat to the correct format. If you're rendering to the swapchain, call SDL_GetGPUSwapchainTextureFormat to query the right value
InitInfo :: struct {
	Device: ^sdl.GPUDevice,
	ColorTargetFormat: sdl.GPUTextureFormat,
	MSAASamples: sdl.GPUSampleCount,
	SwapchainComposition: sdl.GPUSwapchainComposition, // Only used in multi-viewports mode.
	PresentMode: sdl.GPUPresentMode                    // Only used in multi-viewports mode.
}

texture_id :: #force_inline proc(binding: ^sdl.GPUTextureSamplerBinding) -> imgui.TextureID {
	return transmute(imgui.TextureID)binding
}

@(link_prefix="ImGui_ImplSDLGPU3_")
foreign lib {
	Init :: proc(info: ^InitInfo) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc() ---
	PrepareDrawData :: proc(draw_data: ^imgui.DrawData, command_buffer: ^sdl.GPUCommandBuffer) ---
	RenderDrawData :: proc(draw_data: ^imgui.DrawData, command_buffer: ^sdl.GPUCommandBuffer, render_pass: ^sdl.GPURenderPass, pipeline: ^sdl.GPUGraphicsPipeline = nil) ---
	CreateDeviceObjects :: proc() ---
	DestroyDeviceObjects :: proc() ---
	// (Advanced) Use e.g. if you need to precisely control the timing of texture updates (e.g. for staged rendering), by setting ImDrawData::Textures = NULL to handle this manually.
	UpdateTexture :: proc(tex: ^imgui.TextureData) ---
}

// [BETA] Selected render state data shared with callbacks.
// This is temporarily stored in GetPlatformIO().Renderer_RenderState during the ImGui_ImplSDLGPU3_RenderDrawData() call.
// (Please open an issue if you feel you need access to more data)
RenderState :: struct {
	Device: ^sdl.GPUDevice,
	SamplerDefault: ^sdl.GPUSampler, // Default sampler (bilinear filtering)
	SamplerCurrent: ^sdl.GPUSampler  // Current sampler (may be changed by callback)
}
