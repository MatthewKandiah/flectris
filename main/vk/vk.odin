package vk

import "core:fmt"
import v "vendor:vulkan"

fatal :: proc(args: ..any) {
    fmt.eprintln(..args)
    panic("vk fatal")
}

is_success :: proc(res: v.Result) -> bool {
    return res == .SUCCESS
}

not_success :: proc(res: v.Result) -> bool {
    return res != .SUCCESS
}

enumerate_physical_devices :: proc(instance: v.Instance) -> (res: v.Result, count: u32, lst: []v.PhysicalDevice) {
    res = v.EnumeratePhysicalDevices(instance, &count, nil)
    if not_success(res) {
	return
    }

    lst = make([]v.PhysicalDevice, count)
    res = v.EnumeratePhysicalDevices(instance, &count, raw_data(lst))
    return
}

get_physical_device_queue_family_properties :: proc(physical_device: v.PhysicalDevice) -> (count: u32, lst: []v.QueueFamilyProperties) {
    v.GetPhysicalDeviceQueueFamilyProperties(physical_device, &count, nil)
    lst = make([]v.QueueFamilyProperties, count)
    v.GetPhysicalDeviceQueueFamilyProperties(physical_device, &count, raw_data(lst))
    return
}

get_buffer_memory_requirements :: proc(device: v.Device, buffer: v.Buffer) -> (mem_req: v.MemoryRequirements) {
    v.GetBufferMemoryRequirements(device, buffer, &mem_req)
    return
}

get_physical_device_memory_properties :: proc(physical_device: v.PhysicalDevice) -> (mem_prop: v.PhysicalDeviceMemoryProperties) {
    v.GetPhysicalDeviceMemoryProperties(physical_device, &mem_prop)
    return
}

get_physical_device_surface_capabilities_khr :: proc(physical_device: v.PhysicalDevice, surface: v.SurfaceKHR) -> (caps: v.SurfaceCapabilitiesKHR) {
    v.GetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &caps)
    return
}

get_physical_device_surface_present_modes_khr :: proc(physical_device: v.PhysicalDevice, surface: v.SurfaceKHR) -> (res: v.Result, count: u32, lst: []v.PresentModeKHR) {
    res = v.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &count, nil)
    if not_success(res) {
	return
    }
    lst = make([]v.PresentModeKHR, count)

    res = v.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &count, raw_data(lst))
    return
}

get_physical_device_surface_formats_khr :: proc(physical_device: v.PhysicalDevice, surface: v.SurfaceKHR) -> (res: v.Result, count: u32, lst: []v.SurfaceFormatKHR) {
    res = v.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &count, nil)
    if not_success(res) {
	return
    }

    lst = make([]v.SurfaceFormatKHR, count)
    res = v.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &count, raw_data(lst))
    return
}

get_swapchain_images_khr :: proc(device: v.Device, swapchain: v.SwapchainKHR) -> (res: v.Result, count: u32, lst: []v.Image) {
    res = v.GetSwapchainImagesKHR(device, swapchain, &count, nil)
    if not_success(res) {
	return
    }

    lst = make([]v.Image, count)
    res = v.GetSwapchainImagesKHR(device, swapchain, &count, raw_data(lst))
    return
}
