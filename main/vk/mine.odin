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
