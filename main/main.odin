package main

import "base:runtime"
import "core:fmt"
import "vendor:glfw"
import vk "vendor:vulkan"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480
APP_NAME :: "Flectris"
ENABLED_LAYERS :: []cstring{"VK_LAYER_KHRONOS_validation"}

GlobalContext :: struct {
  window:      glfw.WindowHandle,
  vk_instance: vk.Instance,
}
gc: GlobalContext

main :: proc() {
  {   // glfw init
    glfw.SetErrorCallback(error_callback)

    ok := glfw.Init()
    if !ok {
      panic("glfw.Init failed")
    }
  }
  defer glfw.Terminate()

  {   // create window
    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, false)
    gc.window = glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, APP_NAME, nil, nil)
    if gc.window == nil {
      panic("glfw.CreateWindow failed")
    }
  }
  defer {
    glfw.DestroyWindow(gc.window)
    gc.window = nil
  }

  {   // initialise Vulkan instance
    vk.load_proc_addresses(get_proc_address)
    application_info := vk.ApplicationInfo {
      sType              = .APPLICATION_INFO,
      pApplicationName   = APP_NAME,
      applicationVersion = vk.MAKE_VERSION(1, 0, 0),
      pEngineName        = "None",
      engineVersion      = vk.MAKE_VERSION(1, 0, 0),
      apiVersion         = vk.API_VERSION_1_3,
    }
    glfw_required_instance_extensions := glfw.GetRequiredInstanceExtensions()
    instance_create_info := vk.InstanceCreateInfo {
      sType                   = .INSTANCE_CREATE_INFO,
      pApplicationInfo        = &application_info,
      enabledExtensionCount   = cast(u32)len(glfw_required_instance_extensions),
      ppEnabledExtensionNames = raw_data(glfw_required_instance_extensions),
      enabledLayerCount       = cast(u32)len(ENABLED_LAYERS),
      ppEnabledLayerNames     = raw_data(ENABLED_LAYERS),
    }
    if vk.CreateInstance(&instance_create_info, nil, &gc.vk_instance) != .SUCCESS {
      panic("create instance failed")
    }
  }

  init_renderer()

  // main loop
  for !glfw.WindowShouldClose(gc.window) {
    glfw.PollEvents()
  }
}

error_callback :: proc "c" (error: i32, description: cstring) {
  context = runtime.default_context()
  fmt.eprintln("glfw error", error, description)
}

get_proc_address :: proc(p: rawptr, name: cstring) {
  (cast(^rawptr)p)^ = glfw.GetInstanceProcAddress(gc.vk_instance, name)
}
