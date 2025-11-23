package vk

import v "vendor:vulkan"

get_memory_type_index :: proc(
    memory_requirements: v.MemoryRequirements,
    memory_properties: v.PhysicalDeviceMemoryProperties,
    desired_memory_properties: v.MemoryPropertyFlags,
) -> (
    ok: bool,
    memory_type_index: u32,
) {
    tmp_index := -1
    for idx: u32 = 0; idx < memory_properties.memoryTypeCount; idx += 1 {
        memory_type := memory_properties.memoryTypes[idx]
        physical_device_supports_resource_type := memory_requirements.memoryTypeBits & (1 << cast(uint)idx) != 0
        supports_desired_memory_properties := desired_memory_properties <= memory_type.propertyFlags
        if supports_desired_memory_properties && physical_device_supports_resource_type {
            tmp_index = cast(int)idx
            break
        }
    }
    if tmp_index == -1 {
        // desired properties not supported
        return
    }
    return true, cast(u32)tmp_index
}

Resource :: union {
    v.Image,
    v.Buffer,
}

allocate_resource_memory :: proc(
    resource: Resource,
    device: v.Device,
    physical_device: v.PhysicalDevice,
    desired_memory_type_properties: v.MemoryPropertyFlags,
) -> (
    ok: bool,
    memory: v.DeviceMemory,
) {
    memory_requirements := get_resource_memory_requirements(device, resource)
    memory_properties := get_physical_device_memory_properties(physical_device)
    found, memory_type_index := get_memory_type_index(
        memory_requirements,
        memory_properties,
        desired_memory_type_properties,
    )
    if !found {
        return
    }

    alloc_info := v.MemoryAllocateInfo {
        sType           = .MEMORY_ALLOCATE_INFO,
        allocationSize  = memory_requirements.size,
        memoryTypeIndex = cast(u32)memory_type_index,
    }
    allocate_res := v.AllocateMemory(device, &alloc_info, nil, &memory)
    if not_success(allocate_res) {
        return
    }

    bind_res := bind_resource_memory(device, resource, memory)
    if not_success(bind_res) {
        return
    }

    return true, memory
}

allocate_and_map_resource_memory :: proc(
    resource: Resource,
    device: v.Device,
    physical_device: v.PhysicalDevice,
    desired_memory_type_properties: v.MemoryPropertyFlags,
) -> (
    ok: bool,
    memory: v.DeviceMemory,
    memory_mapped: rawptr,
) {
    ok, memory = allocate_resource_memory(resource, device, physical_device, desired_memory_type_properties)
    if !ok {
	return
    }

    map_res := v.MapMemory(device, memory, 0, cast(v.DeviceSize)v.WHOLE_SIZE, {}, &memory_mapped)
    if not_success(map_res) {
        return
    }

    return true, memory, memory_mapped
}

get_resource_memory_requirements :: proc(device: v.Device, resource: Resource) -> (mem_req: v.MemoryRequirements) {
    switch r in resource {
    case v.Image:
        return get_image_memory_requirements(device, r)
    case v.Buffer:
        return get_buffer_memory_requirements(device, r)
    }
    unreachable()
}

bind_resource_memory :: proc(device: v.Device, resource: Resource, memory: v.DeviceMemory) -> (res: v.Result) {
    switch r in resource {
    case v.Image:
        return v.BindImageMemory(device, r, memory, 0)
    case v.Buffer:
        return v.BindBufferMemory(device, r, memory, 0)
    }
    unreachable()
}

create_image_memory_barrier :: proc(
    old_layout, new_layout: v.ImageLayout,
    queue_family_index: u32,
    image: v.Image,
) -> v.ImageMemoryBarrier {
    return v.ImageMemoryBarrier {
        sType = .IMAGE_MEMORY_BARRIER,
        srcAccessMask = {},
        dstAccessMask = {},
        oldLayout = old_layout,
        newLayout = new_layout,
        srcQueueFamilyIndex = queue_family_index,
        dstQueueFamilyIndex = queue_family_index,
        image = image,
        subresourceRange = v.ImageSubresourceRange {
            aspectMask = {.COLOR},
            baseMipLevel = 0,
            levelCount = 1,
            baseArrayLayer = 0,
            layerCount = 1,
        },
    }
}
