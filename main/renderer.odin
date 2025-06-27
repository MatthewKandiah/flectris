package main

import "core:fmt"
import vk "vendor:vulkan"

Renderer :: struct {
  physical_device:    vk.PhysicalDevice,
  queue_family_index: u32,
  queue:              vk.Queue,
  device:             vk.Device,
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
      both_supported := vk.QueueFlags{.GRAPHICS, .TRANSFER} <= queue_family_properties.queueFlags
      if !found && both_supported {
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
      sType                = .DEVICE_CREATE_INFO,
      queueCreateInfoCount = 1,
      pQueueCreateInfos    = &queue_create_info,
    }
    res := vk.CreateDevice(renderer.physical_device, &create_info, nil, &renderer.device)
    if res != .SUCCESS {
      panic("failed to create logical device")
    }
  }

  {   // retrieve queue handle
    vk.GetDeviceQueue(renderer.device, renderer.queue_family_index, 0, &renderer.queue)
  }

  return renderer
}

deinit_renderer :: proc(renderer: ^Renderer) {
  vk.DestroyDevice(renderer.device, nil)
}
