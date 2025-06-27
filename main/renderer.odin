package main

import "core:fmt"
import "vendor:glfw"
import vk "vendor:vulkan"

Renderer :: struct {
  physical_device:    vk.PhysicalDevice,
  queue_family_index: u32,
  queue:              vk.Queue,
  device:             vk.Device,
  swapchain:          vk.SwapchainKHR,
}

init_renderer :: proc() -> (renderer: Renderer) {
  {   // pick a physical device
    count: u32
    res: vk.Result
    res = vk.EnumeratePhysicalDevices(gc.vk_instance, &count, nil)
    if res != .SUCCESS {
      panic("enumerate physical devices failed")
    }
    physical_devices := make([]vk.PhysicalDevice, count)
    defer delete(physical_devices)
    res = vk.EnumeratePhysicalDevices(gc.vk_instance, &count, raw_data(physical_devices))
    if res != .SUCCESS {
      panic("enumerate physical devices second call failed")
    }

    for device in physical_devices {
      properties: vk.PhysicalDeviceProperties
      vk.GetPhysicalDeviceProperties(device, &properties)

      if properties.deviceType == .DISCRETE_GPU ||
         (renderer.physical_device == nil && properties.deviceType == .INTEGRATED_GPU) {
        renderer.physical_device = device
      }
    }
    if renderer.physical_device == nil {
      panic("failed to pick a physical device")
    }
  }

  {   // pick a device queue index
    count: u32
    vk.GetPhysicalDeviceQueueFamilyProperties(renderer.physical_device, &count, nil)
    queue_families_properties := make([]vk.QueueFamilyProperties, count)
    defer delete(queue_families_properties)
    vk.GetPhysicalDeviceQueueFamilyProperties(renderer.physical_device, &count, raw_data(queue_families_properties))

    found := false
    for queue_family_properties, index in queue_families_properties {
      graphics_and_transfer_supported := vk.QueueFlags{.GRAPHICS, .TRANSFER} <= queue_family_properties.queueFlags
      present_supported := glfw.GetPhysicalDevicePresentationSupport(
        gc.vk_instance,
        renderer.physical_device,
        cast(u32)index,
      )
      if !found && graphics_and_transfer_supported && present_supported {
        renderer.queue_family_index = cast(u32)index
        found = true
      }
    }
    if !found {
      panic("failed to pick a device queue index")
    }
  }

  {   // make a logical device
    priorities := []f32{1}
    queue_create_info := vk.DeviceQueueCreateInfo {
      sType            = .DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex = renderer.queue_family_index,
      queueCount       = 1,
      pQueuePriorities = raw_data(priorities),
    }

    create_info := vk.DeviceCreateInfo {
      sType                   = .DEVICE_CREATE_INFO,
      queueCreateInfoCount    = 1,
      pQueueCreateInfos       = &queue_create_info,
      enabledExtensionCount   = cast(u32)len(REQUIRED_EXTENSIONS),
      ppEnabledExtensionNames = raw_data(REQUIRED_EXTENSIONS),
    }
    res := vk.CreateDevice(renderer.physical_device, &create_info, nil, &renderer.device)
    if res != .SUCCESS {
      panic("failed to create logical device")
    }
  }

  {   // retrieve queue handle
    vk.GetDeviceQueue(renderer.device, renderer.queue_family_index, 0, &renderer.queue)
  }

  {   // create swapchain
    surface_capabilities: vk.SurfaceCapabilitiesKHR
    surface_query_res := vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
      renderer.physical_device,
      gc.vk_surface,
      &surface_capabilities,
    )

    supported_present_mode_count: u32
    get_supported_present_modes_res := vk.GetPhysicalDeviceSurfacePresentModesKHR(
      renderer.physical_device,
      gc.vk_surface,
      &supported_present_mode_count,
      nil,
    )
    if get_supported_present_modes_res != .SUCCESS {
      panic("failed to get count of supported present modes")
    }
    supported_present_modes := make([]vk.PresentModeKHR, supported_present_mode_count)
    defer delete(supported_present_modes)
    get_supported_present_modes_res2 := vk.GetPhysicalDeviceSurfacePresentModesKHR(
      renderer.physical_device,
      gc.vk_surface,
      &supported_present_mode_count,
      raw_data(supported_present_modes),
    )
    if get_supported_present_modes_res2 != .SUCCESS {
      panic("failed to get supported present modes")
    }
    mailbox_supported := false
    for supported_mode in supported_present_modes {
      if supported_mode == .MAILBOX {
        mailbox_supported = true
        break
      }
    }
    present_mode: vk.PresentModeKHR = .MAILBOX if mailbox_supported else .FIFO

    supported_format_count: u32
    get_supported_formats_res := vk.GetPhysicalDeviceSurfaceFormatsKHR(
      renderer.physical_device,
      gc.vk_surface,
      &supported_format_count,
      nil,
    )
    if get_supported_formats_res != .SUCCESS {
      panic("failed to get count of supported surface formats")
    }
    supported_formats := make([]vk.SurfaceFormatKHR, supported_format_count)
    defer delete(supported_formats)
    get_supported_formats_res2 := vk.GetPhysicalDeviceSurfaceFormatsKHR(
      renderer.physical_device,
      gc.vk_surface,
      &supported_format_count,
      raw_data(supported_formats),
    )
    if get_supported_formats_res2 != .SUCCESS || len(supported_formats) == 0 {
      panic("failed to get supported surface formats")
    }

    desired_format := vk.SurfaceFormatKHR {
      format     = .B8G8R8A8_SRGB,
      colorSpace = .SRGB_NONLINEAR,
    }
    desired_format_supported := false
    for supported_format in supported_formats {
      if supported_format == desired_format {
        desired_format_supported = true
        break
      }
    }
    surface_image_format := desired_format if desired_format_supported else supported_formats[0]

    create_info := vk.SwapchainCreateInfoKHR {
      sType            = .SWAPCHAIN_CREATE_INFO_KHR,
      flags            = vk.SwapchainCreateFlagsKHR{},
      surface          = gc.vk_surface,
      minImageCount    = surface_capabilities.minImageCount,
      imageFormat      = surface_image_format.format,
      imageColorSpace  = surface_image_format.colorSpace,
      imageExtent      = surface_capabilities.currentExtent,
      imageArrayLayers = 1,
      imageUsage       = vk.ImageUsageFlags{.COLOR_ATTACHMENT},
      imageSharingMode = .EXCLUSIVE,
      preTransform     = surface_capabilities.currentTransform,
      compositeAlpha   = vk.CompositeAlphaFlagsKHR{.OPAQUE},
      presentMode      = present_mode,
      clipped          = true,
    }
    res := vk.CreateSwapchainKHR(renderer.device, &create_info, nil, &renderer.swapchain)
    if res != .SUCCESS {
      panic("failed to create swapchain")
    }
  }

  return renderer
}

deinit_renderer :: proc(renderer: ^Renderer) {
  vk.DestroySwapchainKHR(renderer.device, renderer.swapchain, nil)
  vk.DestroySurfaceKHR(gc.vk_instance, gc.vk_surface, nil)
  vk.DestroyDevice(renderer.device, nil)
}
