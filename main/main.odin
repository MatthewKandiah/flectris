package main

import "base:runtime"
import "core:fmt"
import "core:math/linalg/glsl"
import "vendor:glfw"
import "vendor:vulkan"
import "vk"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480
APP_NAME :: "Flectris"
ENABLED_LAYERS :: []cstring{"VK_LAYER_KHRONOS_validation"}
REQUIRED_DEVICE_EXTENSIONS := []cstring {
    vulkan.KHR_SWAPCHAIN_EXTENSION_NAME,
    vulkan.KHR_DYNAMIC_RENDERING_EXTENSION_NAME,
    vulkan.KHR_DYNAMIC_RENDERING_LOCAL_READ_EXTENSION_NAME,
}
GlobalContext :: struct {
    window:         glfw.WindowHandle,
    window_resized: bool,
    vk_surface:     vulkan.SurfaceKHR,
    vk_instance:    vulkan.Instance,
}
gc: GlobalContext

main :: proc() {
    {     // glfw init
        glfw.SetErrorCallback(error_callback)

        ok := glfw.Init()
        if !ok {
            panic("glfw.Init failed")
        }
    }
    defer glfw.Terminate()

    {     // create window
        glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
        glfw.WindowHint(glfw.RESIZABLE, true)
        gc.window = glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, APP_NAME, nil, nil)
        if gc.window == nil {
            panic("glfw.CreateWindow failed")
        }
    }
    defer {
        glfw.DestroyWindow(gc.window)
        gc.window = nil
    }

    glfw.SetWindowSizeCallback(gc.window, window_size_callback)

    {     // initialise Vulkan instance
        vulkan.load_proc_addresses(get_proc_address)
        application_info := vulkan.ApplicationInfo {
            sType              = .APPLICATION_INFO,
            pApplicationName   = APP_NAME,
            applicationVersion = vulkan.MAKE_VERSION(1, 0, 0),
            pEngineName        = "None",
            engineVersion      = vulkan.MAKE_VERSION(1, 0, 0),
            apiVersion         = vulkan.API_VERSION_1_3,
        }
        glfw_required_instance_extensions := glfw.GetRequiredInstanceExtensions()
        if len(glfw_required_instance_extensions) == 0 {
            panic("get required instance extensions failed - can't present to a window surface on this system")
        }
        instance_create_info := vulkan.InstanceCreateInfo {
            sType                   = .INSTANCE_CREATE_INFO,
            pApplicationInfo        = &application_info,
            enabledExtensionCount   = cast(u32)len(glfw_required_instance_extensions),
            ppEnabledExtensionNames = raw_data(glfw_required_instance_extensions),
            enabledLayerCount       = cast(u32)len(ENABLED_LAYERS),
            ppEnabledLayerNames     = raw_data(ENABLED_LAYERS),
        }
        if res := vulkan.CreateInstance(&instance_create_info, nil, &gc.vk_instance); vk.not_success(res) {
            vk.fatal("create instance failed", res)
        }
    }

    {     // create Vulkan WSI surface
        res := glfw.CreateWindowSurface(gc.vk_instance, gc.window, nil, &gc.vk_surface)
        if vk.not_success(res) {
            vk.fatal("create vk khr window surface failed", res)
        }
    }

    renderer := init_renderer()

    // main loop
    for !glfw.WindowShouldClose(gc.window) {
        glfw.PollEvents()

	str := "HELLO WORLD"
	draw_string(transmute([]u8)str, {x = -0.5, y = 0}, {w = 1, h = 0.5}, 1)
	
        // imagine a update game state
        draw_frame(&renderer)
    }
}

error_callback :: proc "c" (error: i32, description: cstring) {
    context = runtime.default_context()
    fmt.eprintln("glfw error", error, description)
}

window_size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
    context = runtime.default_context()
    gc.window_resized = true
}

get_proc_address :: proc(p: rawptr, name: cstring) {
    (cast(^rawptr)p)^ = glfw.GetInstanceProcAddress(gc.vk_instance, name)
}

draw_string :: proc(str: []u8, pos: Pos, dim: Dim, z: f32) {
    drawables_added := 0
    char_width: f32 = dim.w / cast(f32)len(str)
    for c, idx in str {
        if c == ' ' {
            continue
        }

	DRAWABLES[DRAWABLES_COUNT + drawables_added] = Drawable {
            pos = {x = pos.x + (cast(f32)idx * char_width), y = pos.y},
            z = z,
            dim = {w = char_width, h = dim.h},
            texture_data = get_ascii_font_texture_data(c),
            override_colour = false,
            colour = BLACK,
        }
	drawables_added += 1
    }

    DRAWABLES_COUNT += drawables_added
}
