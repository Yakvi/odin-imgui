package imgui_example_sdl3_sdlgpu3

// This is an example of using the bindings with SDL3 and SDLGPU3
// Based on the above at tag `v1.92.4-docking` (e7d2d63)

DISABLE_DOCKING :: #config(DISABLE_DOCKING, false)

import im "../.."
import "../../imgui_impl_sdl3"
import "../../imgui_impl_sdlgpu3"

import sdl "vendor:sdl3"

main :: proc() {
	im.CHECKVERSION()
	im.CreateContext()
	defer im.DestroyContext()
	io := im.GetIO()
	io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad}
	when !DISABLE_DOCKING {
		io.ConfigFlags += {.DockingEnable}
		io.ConfigFlags += {.ViewportsEnable}

		style := im.GetStyle()
		style.WindowRounding = 0
		style.Colors[im.Col.WindowBg].w = 1
	}
	im.StyleColorsDark()

	sdlInitialized := sdl.Init({.VIDEO, .GAMEPAD})
	assert(sdlInitialized)
	defer sdl.Quit()

	title :: "Dear ImGui SDL3+SDL_GPU example"
	screenCoords := i64(sdl.WINDOWPOS_CENTERED)

	windowProps := sdl.CreateProperties()
	sdl.SetStringProperty(windowProps, sdl.PROP_WINDOW_CREATE_TITLE_STRING, title)
	sdl.SetNumberProperty(windowProps, sdl.PROP_WINDOW_CREATE_X_NUMBER, screenCoords)
	sdl.SetNumberProperty(windowProps, sdl.PROP_WINDOW_CREATE_Y_NUMBER, screenCoords)
	sdl.SetNumberProperty(windowProps, sdl.PROP_WINDOW_CREATE_WIDTH_NUMBER, 1280)
	sdl.SetNumberProperty(windowProps, sdl.PROP_WINDOW_CREATE_HEIGHT_NUMBER, 720)
	sdl.SetBooleanProperty(windowProps, sdl.PROP_WINDOW_CREATE_RESIZABLE_BOOLEAN, true)

	// API-specific
	sdl.SetBooleanProperty(windowProps, sdl.PROP_WINDOW_CREATE_HIGH_PIXEL_DENSITY_BOOLEAN, true)

	window := sdl.CreateWindowWithProperties(windowProps)
	assert(window != nil)
	defer sdl.DestroyWindow(window)

	gpu_device := sdl.CreateGPUDevice({.SPIRV, .DXIL, .METALLIB}, true, nil)
	assert(gpu_device != nil)
	defer sdl.DestroyGPUDevice(gpu_device)

	assert(sdl.ClaimWindowForGPUDevice(gpu_device, window))
	defer sdl.ReleaseWindowFromGPUDevice(gpu_device, window)

	assert(sdl.SetGPUSwapchainParameters(gpu_device, window, .SDR, .VSYNC))

	imgui_impl_sdl3.InitForSDLGPU(window)
	defer imgui_impl_sdl3.Shutdown()

	init_info := imgui_impl_sdlgpu3.InitInfo {
		Device               = gpu_device,
		ColorTargetFormat    = sdl.GetGPUSwapchainTextureFormat(gpu_device, window),
		MSAASamples          = ._1,
		PresentMode          = .VSYNC,
		SwapchainComposition = .SDR,
	}
	imgui_impl_sdlgpu3.Init(&init_info)
	defer imgui_impl_sdlgpu3.Shutdown()

	running := true
	for running {
		e: sdl.Event
		for sdl.PollEvent(&e) {
			imgui_impl_sdl3.ProcessEvent(&e)

			#partial switch e.type {
			case .QUIT:
				running = false
			}
		}

		imgui_impl_sdlgpu3.NewFrame()
		imgui_impl_sdl3.NewFrame()
		im.NewFrame()

		im.ShowDemoWindow()

		if im.Begin("Window containing a quit button") {
			if im.Button("The quit button in question") {
				running = false
			}
		}
		im.End()

		im.Render()
		draw_data := im.GetDrawData()
		command_buffer := sdl.AcquireGPUCommandBuffer(gpu_device)
		swapchain_texture: ^sdl.GPUTexture
		swapchain_ok := sdl.WaitAndAcquireGPUSwapchainTexture(
			command_buffer,
			window,
			&swapchain_texture,
			nil,
			nil,
		)
		assert(swapchain_ok)

		if swapchain_texture != nil {
			// This is mandatory: call PrepareDrawData() to upload the vertex/index buffer!
			imgui_impl_sdlgpu3.PrepareDrawData(draw_data, command_buffer)

			color_target_infos := sdl.GPUColorTargetInfo {
				texture     = swapchain_texture,
				clear_color = {0, 0, 0, 1},
				load_op     = .CLEAR,
				store_op    = .STORE,
			}
			render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target_infos, 1, nil)
			imgui_impl_sdlgpu3.RenderDrawData(draw_data, command_buffer, render_pass)

			sdl.EndGPURenderPass(render_pass)
		}

		when !DISABLE_DOCKING {
			im.UpdatePlatformWindows()
			im.RenderPlatformWindowsDefault()
		}

		assert(sdl.SubmitGPUCommandBuffer(command_buffer))
	}
}
