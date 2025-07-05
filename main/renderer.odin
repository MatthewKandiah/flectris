package main

import "core:fmt"
import "vendor:glfw"
import vk "vendor:vulkan"

Renderer :: struct {
  physical_device:        vk.PhysicalDevice,
  queue_family_index:     u32,
  queue:                  vk.Queue,
  device:                 vk.Device,
  swapchain:              vk.SwapchainKHR,
  swapchain_images:       []vk.Image,
  swapchain_image_views:  []vk.ImageView,
  swapchain_image_format: vk.Format,
  vertex_buffer:          vk.Buffer,
  vertex_buffer_memory:   vk.DeviceMemory,
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
    renderer.swapchain_image_format = surface_image_format.format
  }

  {   // make swapchain images
    count: u32
    res := vk.GetSwapchainImagesKHR(renderer.device, renderer.swapchain, &count, nil)
    if res != .SUCCESS {
      panic("failed to get swapchain images count")
    }
    renderer.swapchain_images = make([]vk.Image, count)
    res2 := vk.GetSwapchainImagesKHR(renderer.device, renderer.swapchain, &count, raw_data(renderer.swapchain_images))
    if res2 != .SUCCESS {
      panic("failed to get swapchain images")
    }
    // TODO-Matt:  All presentable images are initially
    // in the VK_IMAGE_LAYOUT_UNDEFINED layout, thus before using presentable images, the application must transition them to a valid layout for the intended use.
    // I think we'll want to transition to VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
  }

  {   // make swapchain image views
    renderer.swapchain_image_views = make([]vk.ImageView, cast(u32)len(renderer.swapchain_images))
    for i in 0 ..< len(renderer.swapchain_images) {
      create_info := vk.ImageViewCreateInfo {
        sType = .IMAGE_VIEW_CREATE_INFO,
        flags = {},
        image = renderer.swapchain_images[i],
        viewType = .D2,
        format = renderer.swapchain_image_format,
        components = {r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY},
        subresourceRange = {
          aspectMask = vk.ImageAspectFlags{.COLOR},
          baseMipLevel = 0,
          levelCount = 1,
          baseArrayLayer = 0,
          layerCount = 1,
        },
      }
      res := vk.CreateImageView(renderer.device, &create_info, nil, &renderer.swapchain_image_views[i])
      if res != .SUCCESS {
        panic("failed to create swapchain image views")
      }
    }
  }

  {   // create vertex buffer
    create_info := vk.BufferCreateInfo {
      sType       = .BUFFER_CREATE_INFO,
      flags       = {},
      size        = cast(vk.DeviceSize)(size_of(Vertex) * len(vertices)),
      usage       = {.VERTEX_BUFFER},
      sharingMode = .EXCLUSIVE,
    }
    res := vk.CreateBuffer(renderer.device, &create_info, nil, &renderer.vertex_buffer)
    if res != .SUCCESS {
      panic("failed to create vertex buffer")
    }
  }

  {   // allocate vertex buffer memory and bind it
    memory_requirements: vk.MemoryRequirements
    vk.GetBufferMemoryRequirements(renderer.device, renderer.vertex_buffer, &memory_requirements)

    memory_properties: vk.PhysicalDeviceMemoryProperties
    vk.GetPhysicalDeviceMemoryProperties(renderer.physical_device, &memory_properties)
    desired_memory_type_properties := vk.MemoryPropertyFlags{.HOST_VISIBLE, .HOST_COHERENT}
    memory_type_index := -1
    for memory_type, idx in memory_properties.memoryTypes[0:memory_properties.memoryTypeCount] {
      physical_device_supports_resource_type := memory_requirements.memoryTypeBits & (1 << cast(uint)idx) != 0
      supports_desired_memory_properties := desired_memory_type_properties <= memory_type.propertyFlags
      if supports_desired_memory_properties && physical_device_supports_resource_type {
        memory_type_index = idx
        break
      }
    }
    if memory_type_index == -1 {
      panic("failed to find a suitable memory type for vertex buffer allocation")
    }

    allocate_info := vk.MemoryAllocateInfo {
      sType           = .MEMORY_ALLOCATE_INFO,
      allocationSize  = memory_requirements.size,
      memoryTypeIndex = cast(u32)memory_type_index,
    }
    res := vk.AllocateMemory(renderer.device, &allocate_info, nil, &renderer.vertex_buffer_memory)
    if res != .SUCCESS {
      panic("failed to allocate vertex buffer memory")
    }

    bind_res := vk.BindBufferMemory(renderer.device, renderer.vertex_buffer, renderer.vertex_buffer_memory, 0)
    if bind_res != .SUCCESS {
      panic("failed to bind vertex buffer memory")
    }
  }

  return renderer
}

deinit_renderer :: proc(using renderer: ^Renderer) {
  vk.DestroyBuffer(device, vertex_buffer, nil)
  vk.FreeMemory(device, vertex_buffer_memory, nil)
  for image_view in swapchain_image_views {
    vk.DestroyImageView(device, image_view, nil)
  }
  delete(swapchain_image_views)
  delete(swapchain_images)
  vk.DestroySwapchainKHR(device, swapchain, nil)
  vk.DestroySurfaceKHR(gc.vk_instance, gc.vk_surface, nil)
  vk.DestroyDevice(device, nil)
}
