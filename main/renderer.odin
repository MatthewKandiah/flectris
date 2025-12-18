package main

import "base:intrinsics"
import "core:fmt"
import "core:os"
import "img"
import "vendor:glfw"
import "vendor:stb/image"
import "vendor:vulkan"
import "vk"

VERTEX_SHADER_PATH :: "build/vert.spv"
FRAGMENT_SHADER_PATH :: "build/frag.spv"
SMILEY_TEXTURE_PATH :: "main/smiley.png"
FONT_TEXTURE_PATH :: "main/font.png"

VERTEX_BUFFER_SIZE :: 10_000
VERTEX_BUFFER := [VERTEX_BUFFER_SIZE]Vertex{}
INDEX_BUFFER_SIZE :: 10_000
INDEX_BUFFER := [INDEX_BUFFER_SIZE]u32{}

DRAWABLES_SIZE :: 10_000
DRAWABLES_COUNT := 0
DRAWABLES := [DRAWABLES_SIZE]Drawable{}

Renderer :: struct {
    physical_device:             vulkan.PhysicalDevice,
    queue_family_index:          u32,
    queue:                       vulkan.Queue,
    device:                      vulkan.Device,
    swapchain:                   vulkan.SwapchainKHR,
    swapchain_images:            []vulkan.Image,
    swapchain_image_views:       []vulkan.ImageView,
    swapchain_image_format:      vulkan.Format,
    vertex_buffer:               vulkan.Buffer,
    vertex_buffer_memory:        vulkan.DeviceMemory,
    vertex_buffer_memory_mapped: rawptr,
    index_buffer:                vulkan.Buffer,
    index_buffer_memory:         vulkan.DeviceMemory,
    index_buffer_memory_mapped:  rawptr,
    fragment_shader_module:      vulkan.ShaderModule,
    vertex_shader_module:        vulkan.ShaderModule,
    graphics_pipeline:           vulkan.Pipeline,
    command_pool:                vulkan.CommandPool,
    command_buffer:              vulkan.CommandBuffer,
    semaphores_draw_finished:    []vulkan.Semaphore,
    fence_image_acquired:        vulkan.Fence,
    fence_frame_finished:        vulkan.Fence,
    texture_image:               vulkan.Image,
    texture_image_memory:        vulkan.DeviceMemory,
    texture_image_view:          vulkan.ImageView,
    texture_sampler:             vulkan.Sampler,
    descriptor_pool:             vulkan.DescriptorPool,
    descriptor_set:              vulkan.DescriptorSet,
    descriptor_set_layout:       vulkan.DescriptorSetLayout,
    pipeline_layout:             vulkan.PipelineLayout,
    depth_image:                 vulkan.Image,
    depth_image_memory:          vulkan.DeviceMemory,
    depth_image_view:            vulkan.ImageView,
}

drawable_dim_to_screen_dim :: proc(dim: Dim) -> Dim {
    return Dim {
	w = 2 * dim.w / cast(f32)gc.surface_extent.width,
	h = 2 * dim.h / cast(f32)gc.surface_extent.height,
    }
}

drawable_pos_to_screen_pos :: proc(pos: Pos) -> Pos {
    return Pos {
        x = (2 * pos.x) / cast(f32)gc.surface_extent.width - 1,
        y = 1 - (2 * pos.y) / cast(f32)gc.surface_extent.height,
    }
}

draw_drawables :: proc() {
    for drawable, idx in DRAWABLES[:DRAWABLES_COUNT] {
        vertex_base_idx := idx * 4
        index_base_idx := idx * 6
        alpha: f32 = 1 if drawable.override_colour else 0

        pos := drawable_pos_to_screen_pos(drawable.pos)
        dim := drawable_dim_to_screen_dim(drawable.dim)

        VERTEX_BUFFER[vertex_base_idx + 0] = {
            {pos.x, pos.y, drawable.z},
            {drawable.colour.r, drawable.colour.g, drawable.colour.b, alpha},
            {drawable.texture_data.base.x, drawable.texture_data.base.y},
        }
        VERTEX_BUFFER[vertex_base_idx + 1] = {
            {pos.x, pos.y - dim.h, drawable.z},
            {drawable.colour.r, drawable.colour.g, drawable.colour.b, alpha},
            {drawable.texture_data.base.x, drawable.texture_data.base.y - drawable.texture_data.dim.h},
        }
        VERTEX_BUFFER[vertex_base_idx + 2] = {
            {pos.x + dim.w, pos.y, drawable.z},
            {drawable.colour.r, drawable.colour.g, drawable.colour.b, alpha},
            {drawable.texture_data.base.x + drawable.texture_data.dim.w, drawable.texture_data.base.y},
        }
        VERTEX_BUFFER[vertex_base_idx + 3] = {
            {pos.x + dim.w, pos.y - dim.h, drawable.z},
            {drawable.colour.r, drawable.colour.g, drawable.colour.b, alpha},
            {
                drawable.texture_data.base.x + drawable.texture_data.dim.w,
                drawable.texture_data.base.y - drawable.texture_data.dim.h,
            },
        }

        INDEX_BUFFER[index_base_idx + 0] = cast(u32)(vertex_base_idx + 0)
        INDEX_BUFFER[index_base_idx + 1] = cast(u32)(vertex_base_idx + 1)
        INDEX_BUFFER[index_base_idx + 2] = cast(u32)(vertex_base_idx + 2)
        INDEX_BUFFER[index_base_idx + 3] = cast(u32)(vertex_base_idx + 2)
        INDEX_BUFFER[index_base_idx + 4] = cast(u32)(vertex_base_idx + 1)
        INDEX_BUFFER[index_base_idx + 5] = cast(u32)(vertex_base_idx + 3)
    }
    DRAWABLES_COUNT = 0
}

init_renderer :: proc() -> (renderer: Renderer) {
    {     // pick a physical device
        res, count, physical_devices := vk.enumerate_physical_devices(gc.vk_instance)
        if vk.not_success(res) {
            vk.fatal("failed to enumerate physical devices", res, count)
        }
        defer delete(physical_devices)

        for device in physical_devices {
            properties := vk.get_physical_device_properties(device)

            if properties.deviceType == .DISCRETE_GPU ||
               (renderer.physical_device == nil && properties.deviceType == .INTEGRATED_GPU) {
                renderer.physical_device = device
            }
        }
        if renderer.physical_device == nil {
            panic("failed to pick a physical device")
        }
    }

    {     // pick a device queue index
        count, queue_families_properties := vk.get_physical_device_queue_family_properties(renderer.physical_device)
        defer delete(queue_families_properties)

        found := false
        for queue_family_properties, index in queue_families_properties {
            graphics_and_transfer_supported :=
                vulkan.QueueFlags{.GRAPHICS, .TRANSFER} <= queue_family_properties.queueFlags
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

    {     // make a logical device
        priorities := []f32{1}
        queue_create_info := vulkan.DeviceQueueCreateInfo {
            sType            = .DEVICE_QUEUE_CREATE_INFO,
            queueFamilyIndex = renderer.queue_family_index,
            queueCount       = 1,
            pQueuePriorities = raw_data(priorities),
        }

        dynamic_rendering_local_read := vulkan.PhysicalDeviceDynamicRenderingLocalReadFeatures {
            sType                     = .PHYSICAL_DEVICE_DYNAMIC_RENDERING_LOCAL_READ_FEATURES,
            pNext                     = nil,
            dynamicRenderingLocalRead = true,
        }

        dynamic_rendering_features := vulkan.PhysicalDeviceDynamicRenderingFeatures {
            sType            = .PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES,
            pNext            = &dynamic_rendering_local_read,
            dynamicRendering = true,
        }

        create_info := vulkan.DeviceCreateInfo {
            sType                   = .DEVICE_CREATE_INFO,
            pNext                   = &dynamic_rendering_features,
            queueCreateInfoCount    = 1,
            pQueueCreateInfos       = &queue_create_info,
            enabledExtensionCount   = cast(u32)len(REQUIRED_DEVICE_EXTENSIONS),
            ppEnabledExtensionNames = raw_data(REQUIRED_DEVICE_EXTENSIONS),
        }
        res := vulkan.CreateDevice(renderer.physical_device, &create_info, nil, &renderer.device)
        if vk.not_success(res) {
            vk.fatal("failed to create logical device", res)
        }
    }

    renderer.queue = vk.get_device_queue(renderer.device, renderer.queue_family_index, 0)

    create_swapchain(&renderer)
    create_swapchain_images(&renderer)
    create_swapchain_image_views(&renderer)

    {     // create command pool
        create_info := vulkan.CommandPoolCreateInfo {
            sType            = .COMMAND_POOL_CREATE_INFO,
            flags            = {.RESET_COMMAND_BUFFER},
            queueFamilyIndex = renderer.queue_family_index,
        }
        res := vulkan.CreateCommandPool(renderer.device, &create_info, nil, &renderer.command_pool)
        if vk.not_success(res) {
            vk.fatal("failed to create command pool", res)
        }
    }

    {     // allocate a command buffer
        allocate_info := vulkan.CommandBufferAllocateInfo {
            sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
            commandPool        = renderer.command_pool,
            level              = .PRIMARY,
            commandBufferCount = 1,
        }
        res := vulkan.AllocateCommandBuffers(renderer.device, &allocate_info, &renderer.command_buffer)
        if vk.not_success(res) {
            vk.fatal("failed to allocate command buffer", res)
        }
    }

    {     // create descriptor pool
        descriptor_pool_size := vulkan.DescriptorPoolSize {
            type            = .COMBINED_IMAGE_SAMPLER,
            descriptorCount = 1,
        }

        create_info := vulkan.DescriptorPoolCreateInfo {
            sType         = .DESCRIPTOR_POOL_CREATE_INFO,
            flags         = {},
            maxSets       = 1,
            poolSizeCount = 1,
            pPoolSizes    = &descriptor_pool_size,
        }
        res := vulkan.CreateDescriptorPool(renderer.device, &create_info, nil, &renderer.descriptor_pool)
        if vk.not_success(res) {
            vk.fatal("failed to create descriptor pool", res)
        }
    }

    {     // create texture image resource
        ok, x, y, channels_in_file, data := img.load(FONT_TEXTURE_PATH, 4)
        if !ok {
            img.fatal("failed to load texture image from file", FONT_TEXTURE_PATH, x, y, channels_in_file)
        }
        defer img.free(data)
        data_size_bytes := cast(vulkan.DeviceSize)(size_of(data[0]) * len(data))

        for b, idx in data {
            if idx % 4 != 3 {
                continue
            }
            if b != 0 && b != 255 {
                // TODO - reenable when we've got our actual textures we're interested in using, guessing the smiley just has some weird bits in it
                //fmt.eprintln("ASSERT: only total opaque or total transparent values are currently supported, received alpha:", b)
                //panic("Unexpected alpha value")
            }
        }

        staging_buffer: vulkan.Buffer
        buffer_create_info := vulkan.BufferCreateInfo {
            sType       = .BUFFER_CREATE_INFO,
            flags       = {},
            size        = data_size_bytes,
            usage       = {.TRANSFER_SRC},
            sharingMode = .EXCLUSIVE,
        }
        buffer_create_res := vulkan.CreateBuffer(renderer.device, &buffer_create_info, nil, &staging_buffer)
        if vk.not_success(buffer_create_res) {
            vk.fatal("failed to create texture image staging buffer", buffer_create_res)
        }

        buffer_allocate_ok, memory, memory_mapped := vk.allocate_and_map_resource_memory(
            staging_buffer,
            renderer.device,
            renderer.physical_device,
            {.HOST_VISIBLE, .HOST_COHERENT},
        )
        if !buffer_allocate_ok {
            vk.fatal("failed to allocate texture image staging buffer memory")
        }

        defer {
            vulkan.DestroyBuffer(renderer.device, staging_buffer, nil)
            vulkan.UnmapMemory(renderer.device, memory)
            vulkan.FreeMemory(renderer.device, memory, nil)
        }

        intrinsics.mem_copy_non_overlapping(memory_mapped, raw_data(data), data_size_bytes)

        create_image_info := vulkan.ImageCreateInfo {
            sType = .IMAGE_CREATE_INFO,
            imageType = .D2,
            format = .R8G8B8A8_SRGB,
            extent = vulkan.Extent3D{width = cast(u32)x, height = cast(u32)y, depth = 1},
            mipLevels = 1,
            arrayLayers = 1,
            tiling = .OPTIMAL,
            sharingMode = .EXCLUSIVE,
            initialLayout = .UNDEFINED,
            samples = {._1},
            usage = {.TRANSFER_DST, .SAMPLED},
        }
        image_create_res := vulkan.CreateImage(renderer.device, &create_image_info, nil, &renderer.texture_image)
        if vk.not_success(image_create_res) {
            vk.fatal("failed to create texture image", image_create_res)
        }

        ok, renderer.texture_image_memory = vk.allocate_resource_memory(
            renderer.texture_image,
            renderer.device,
            renderer.physical_device,
            {.DEVICE_LOCAL},
        )
        if !ok {
            vk.fatal("failed to allocate and map texture image memory")
        }

        if !vk.begin_recording_one_time_submit_commands(renderer.command_buffer) {
            vk.fatal("failed to begin recording texture image commands")
        }

        transfer_destination_barrier := vk.create_image_memory_barrier(
            .UNDEFINED,
            .TRANSFER_DST_OPTIMAL,
            renderer.queue_family_index,
            renderer.texture_image,
            .COLOR,
        )
        vulkan.CmdPipelineBarrier(
            commandBuffer = renderer.command_buffer,
            srcStageMask = {.TOP_OF_PIPE},
            dstStageMask = {.TOP_OF_PIPE},
            dependencyFlags = {},
            imageMemoryBarrierCount = 1,
            pImageMemoryBarriers = &transfer_destination_barrier,
            memoryBarrierCount = 0,
            pMemoryBarriers = nil,
            bufferMemoryBarrierCount = 0,
            pBufferMemoryBarriers = nil,
        )

        buffer_image_copy := vulkan.BufferImageCopy {
            bufferOffset = 0,
            bufferRowLength = 0,
            bufferImageHeight = 0,
            imageSubresource = {
                aspectMask = vulkan.ImageAspectFlags{.COLOR},
                mipLevel = 0,
                baseArrayLayer = 0,
                layerCount = 1,
            },
            imageExtent = vulkan.Extent3D{depth = 1, width = cast(u32)x, height = cast(u32)y},
            imageOffset = vulkan.Offset3D{x = 0, y = 0, z = 0},
        }
        vulkan.CmdCopyBufferToImage(
            renderer.command_buffer,
            staging_buffer,
            renderer.texture_image,
            .TRANSFER_DST_OPTIMAL,
            1,
            &buffer_image_copy,
        )

        shader_read_only_barrier := vk.create_image_memory_barrier(
            .TRANSFER_DST_OPTIMAL,
            .SHADER_READ_ONLY_OPTIMAL,
            renderer.queue_family_index,
            renderer.texture_image,
            .COLOR,
        )
        vulkan.CmdPipelineBarrier(
            commandBuffer = renderer.command_buffer,
            srcStageMask = {.TOP_OF_PIPE},
            dstStageMask = {.TOP_OF_PIPE},
            dependencyFlags = {},
            imageMemoryBarrierCount = 1,
            pImageMemoryBarriers = &shader_read_only_barrier,
            memoryBarrierCount = 0,
            pMemoryBarriers = nil,
            bufferMemoryBarrierCount = 0,
            pBufferMemoryBarriers = nil,
        )

        if vulkan.EndCommandBuffer(renderer.command_buffer) != .SUCCESS {
            vk.fatal("failed to end recording texture image commands")
        }

        submit_info := vulkan.SubmitInfo {
            sType                = .SUBMIT_INFO,
            commandBufferCount   = 1,
            pCommandBuffers      = &renderer.command_buffer,
            signalSemaphoreCount = 0,
            pSignalSemaphores    = nil,
        }
        res := vulkan.QueueSubmit(renderer.queue, 1, &submit_info, renderer.fence_frame_finished)
        if vk.not_success(res) {
            vk.fatal("failed to submit command", res)
        }
        vulkan.DeviceWaitIdle(renderer.device)
    }

    {     // create texture image view
        create_info := vulkan.ImageViewCreateInfo {
            sType = .IMAGE_VIEW_CREATE_INFO,
            viewType = .D2,
            format = .R8G8B8A8_SRGB,
            image = renderer.texture_image,
            flags = {},
            components = {r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY},
            subresourceRange = {
                aspectMask = vulkan.ImageAspectFlags{.COLOR},
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
        }
        res := vulkan.CreateImageView(renderer.device, &create_info, nil, &renderer.texture_image_view)
        if vk.not_success(res) {
            vk.fatal("failed to create texture image view", res)
        }
    }

    create_depth_image_and_view(&renderer)

    {     // create sampler
        create_info := vulkan.SamplerCreateInfo {
            sType                   = .SAMPLER_CREATE_INFO,
            flags                   = {},
            minFilter               = .NEAREST,
            magFilter               = .NEAREST,
            mipmapMode              = .NEAREST,
            addressModeU            = .CLAMP_TO_EDGE,
            addressModeV            = .CLAMP_TO_EDGE,
            addressModeW            = .CLAMP_TO_EDGE,
            mipLodBias              = 0,
            anisotropyEnable        = false,
            compareEnable           = false,
            compareOp               = {},
            minLod                  = 0,
            maxLod                  = 0,
            unnormalizedCoordinates = true,
        }
        res := vulkan.CreateSampler(renderer.device, &create_info, nil, &renderer.texture_sampler)
        if vk.not_success(res) {
            vk.fatal("failed to create texture sampler", res)
        }
    }

    {     // create vertex buffer
        create_info := vulkan.BufferCreateInfo {
            sType       = .BUFFER_CREATE_INFO,
            flags       = {},
            size        = cast(vulkan.DeviceSize)(size_of(Vertex) * VERTEX_BUFFER_SIZE),
            usage       = {.VERTEX_BUFFER},
            sharingMode = .EXCLUSIVE,
        }
        res := vulkan.CreateBuffer(renderer.device, &create_info, nil, &renderer.vertex_buffer)
        if vk.not_success(res) {
            vk.fatal("failed to create vertex buffer", res)
        }
    }

    {     // allocate and map buffer memory
        ok, vertex_buffer_memory, vertex_buffer_memory_mapped := vk.allocate_and_map_resource_memory(
            renderer.vertex_buffer,
            renderer.device,
            renderer.physical_device,
            {.HOST_VISIBLE, .HOST_COHERENT},
        )
        if !ok {
            vk.fatal("failed to allocate and map vertex buffer memory")
        }
        renderer.vertex_buffer_memory = vertex_buffer_memory
        renderer.vertex_buffer_memory_mapped = vertex_buffer_memory_mapped
    }

    {     // create index buffer
        create_info := vulkan.BufferCreateInfo {
            sType       = .BUFFER_CREATE_INFO,
            flags       = {},
            size        = cast(vulkan.DeviceSize)(size_of(u32) * INDEX_BUFFER_SIZE),
            usage       = {.INDEX_BUFFER},
            sharingMode = .EXCLUSIVE,
        }
        res := vulkan.CreateBuffer(renderer.device, &create_info, nil, &renderer.index_buffer)
        if vk.not_success(res) {
            vk.fatal("failed to create index buffer", res)
        }
    }

    {     // allocate index buffer memory and map it
        ok, index_buffer_memory, index_buffer_memory_mapped := vk.allocate_and_map_resource_memory(
            renderer.index_buffer,
            renderer.device,
            renderer.physical_device,
            {.HOST_VISIBLE, .HOST_COHERENT},
        )
        if !ok {
            vk.fatal("failed to allocate and map memory")
        }
        renderer.index_buffer_memory = index_buffer_memory
        renderer.index_buffer_memory_mapped = index_buffer_memory_mapped
    }

    {     // create vertex shader module
        data, err := os.read_entire_file_from_filename_or_err(VERTEX_SHADER_PATH)
        if err != nil {
            fmt.eprintln("Error reading vertex shader file", err)
            panic("Failed to read vertex shader file")
        }
        create_info := vulkan.ShaderModuleCreateInfo {
            sType    = .SHADER_MODULE_CREATE_INFO,
            codeSize = len(data),
            pCode    = cast(^u32)raw_data(data),
        }
        res := vulkan.CreateShaderModule(renderer.device, &create_info, nil, &renderer.vertex_shader_module)
        if vk.not_success(res) {
            vk.fatal("failed to create vertex shader module", res)
        }
    }

    {     // create fragment shader module
        data, err := os.read_entire_file_from_filename_or_err(FRAGMENT_SHADER_PATH)
        if err != nil {
            fmt.eprintln("Error reading fragment shader file", err)
            panic("Failed to read fragment shader file")
        }
        create_info := vulkan.ShaderModuleCreateInfo {
            sType    = .SHADER_MODULE_CREATE_INFO,
            codeSize = len(data),
            pCode    = cast(^u32)raw_data(data),
        }
        res := vulkan.CreateShaderModule(renderer.device, &create_info, nil, &renderer.fragment_shader_module)
        if vk.not_success(res) {
            vk.fatal("failed to create fragment shader module", res)
        }
    }

    {     // create descriptor set layout
        texture_combined_sampler_binding := vulkan.DescriptorSetLayoutBinding {
            binding            = 0,
            descriptorType     = .COMBINED_IMAGE_SAMPLER,
            descriptorCount    = 1,
            stageFlags         = {.FRAGMENT},
            pImmutableSamplers = nil,
        }
        create_info := vulkan.DescriptorSetLayoutCreateInfo {
            sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            flags        = {},
            bindingCount = 1,
            pBindings    = &texture_combined_sampler_binding,
        }
        res := vulkan.CreateDescriptorSetLayout(renderer.device, &create_info, nil, &renderer.descriptor_set_layout)
    }

    {     // allocate descriptor set
        allocate_info := vulkan.DescriptorSetAllocateInfo {
            sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
            descriptorPool     = renderer.descriptor_pool,
            descriptorSetCount = 1,
            pSetLayouts        = &renderer.descriptor_set_layout,
        }
        res := vulkan.AllocateDescriptorSets(renderer.device, &allocate_info, &renderer.descriptor_set)
    }

    {     // update descriptor set
        descriptor_image_info := vulkan.DescriptorImageInfo {
            sampler     = renderer.texture_sampler,
            imageView   = renderer.texture_image_view,
            imageLayout = .SHADER_READ_ONLY_OPTIMAL,
        }
        descriptor_write := vulkan.WriteDescriptorSet {
            sType           = .WRITE_DESCRIPTOR_SET,
            dstSet          = renderer.descriptor_set,
            dstBinding      = 0,
            dstArrayElement = 0,
            descriptorCount = 1,
            descriptorType  = .COMBINED_IMAGE_SAMPLER,
            pImageInfo      = &descriptor_image_info,
        }
        vulkan.UpdateDescriptorSets(renderer.device, 1, &descriptor_write, 0, nil)
    }

    create_graphics_pipeline(&renderer)

    {     // create synchronisation objects
        semaphore_create_info := vulkan.SemaphoreCreateInfo {
            sType = .SEMAPHORE_CREATE_INFO,
        }
        renderer.semaphores_draw_finished = make([]vulkan.Semaphore, len(renderer.swapchain_images))
        for i in 0 ..< len(renderer.swapchain_images) {
            draw_finished_semaphore_res := vulkan.CreateSemaphore(
                renderer.device,
                &semaphore_create_info,
                nil,
                &renderer.semaphores_draw_finished[i],
            )
            if vk.not_success(draw_finished_semaphore_res) {
                vk.fatal("failed to create raw finished semaphore", draw_finished_semaphore_res)
            }
        }

        image_acquired_fence_create_info := vulkan.FenceCreateInfo {
            sType = .FENCE_CREATE_INFO,
            flags = {},
        }
        image_acquired_fence_res := vulkan.CreateFence(
            renderer.device,
            &image_acquired_fence_create_info,
            nil,
            &renderer.fence_image_acquired,
        )
        if vk.not_success(image_acquired_fence_res) {
            vk.fatal("failed to create image acquired fence", image_acquired_fence_res)
        }

        frame_fence_create_info := vulkan.FenceCreateInfo {
            sType = .FENCE_CREATE_INFO,
            flags = {.SIGNALED},
        }
        frame_finished_fence_res := vulkan.CreateFence(
            renderer.device,
            &frame_fence_create_info,
            nil,
            &renderer.fence_frame_finished,
        )
        if vk.not_success(frame_finished_fence_res) {
            vk.fatal("failed to create frame finished fence", frame_finished_fence_res)
        }
    }

    return renderer
}

deinit_renderer :: proc(using renderer: ^Renderer) {
    for i in 0 ..< len(swapchain_images) {
        vulkan.DestroySemaphore(device, semaphores_draw_finished[i], nil)
    }
    delete(semaphores_draw_finished)
    vulkan.DestroyFence(device, fence_image_acquired, nil)
    vulkan.DestroyFence(device, fence_frame_finished, nil)
    vulkan.DestroyCommandPool(device, command_pool, nil)
    vulkan.DestroyShaderModule(device, vertex_shader_module, nil)
    vulkan.DestroyBuffer(device, vertex_buffer, nil)
    vulkan.DestroyBuffer(device, index_buffer, nil)
    renderer.vertex_buffer_memory_mapped = nil
    renderer.index_buffer_memory_mapped = nil
    vulkan.UnmapMemory(device, vertex_buffer_memory)
    vulkan.UnmapMemory(device, index_buffer_memory)
    vulkan.FreeMemory(device, vertex_buffer_memory, nil)
    vulkan.FreeMemory(device, index_buffer_memory, nil)
    for image_view in swapchain_image_views {
        vulkan.DestroyImageView(device, image_view, nil)
    }
    delete(swapchain_image_views)
    delete(swapchain_images)
    vulkan.DestroySwapchainKHR(device, swapchain, nil)
    vulkan.DestroySurfaceKHR(gc.vk_instance, gc.vk_surface, nil)
    vulkan.DestroyDevice(device, nil)
}

render_frame :: proc(renderer: ^Renderer) {
    if gc.window_resized {
        handle_screen_resized(renderer)
        return
    }

    draw_drawables()
    {     // copy vertex data into vertex buffer
        intrinsics.mem_copy_non_overlapping(
            renderer.vertex_buffer_memory_mapped,
            &VERTEX_BUFFER,
            size_of(Vertex) * VERTEX_BUFFER_SIZE,
        )
    }

    {     // zero out vertex data
        for &v in VERTEX_BUFFER {
            v = {}
        }
    }

    {     // copy index data into index buffer
        intrinsics.mem_copy_non_overlapping(
            renderer.index_buffer_memory_mapped,
            &INDEX_BUFFER,
            size_of(u32) * INDEX_BUFFER_SIZE,
        )
    }

    {     // zero out index data
        for &i in INDEX_BUFFER {
            i = 0
        }
    }

    {     // ensure previous frame finished before we start
        wait_res := vulkan.WaitForFences(renderer.device, 1, &renderer.fence_frame_finished, true, max(u64))
        if vk.not_success(wait_res) {
            vk.fatal("failed to wait for frame fence", wait_res)
        }

        reset_res := vulkan.ResetFences(renderer.device, 1, &renderer.fence_frame_finished)
        if vk.not_success(reset_res) {
            vk.fatal("failed to reset frame fence", reset_res)
        }
    }

    swapchain_image_index: u32
    {     // get next swapchain image
        res := vulkan.AcquireNextImageKHR(
            renderer.device,
            renderer.swapchain,
            max(u64),
            0,
            renderer.fence_image_acquired,
            &swapchain_image_index,
        )
        if res == .ERROR_OUT_OF_DATE_KHR || res == .SUBOPTIMAL_KHR {
            // fmt.println("swapchain out of date / suboptimal on acquire next image")
        } else if vk.not_success(res) {
            vk.fatal("failed to get next swapchain image", res)
        }

        wait_res := vulkan.WaitForFences(renderer.device, 1, &renderer.fence_image_acquired, true, max(u64))
        if vk.not_success(wait_res) {
            vk.fatal("failed to wait for image acquired fence", res)
        }

        reset_res := vulkan.ResetFences(renderer.device, 1, &renderer.fence_image_acquired)
        if vk.not_success(reset_res) {
            vk.fatal("failed to reset image acquired fence", reset_res)
        }
    }

    if !vk.begin_recording_one_time_submit_commands(renderer.command_buffer) {
        vk.fatal("failed to  buffer")
    }


    clear_value := vulkan.ClearColorValue {
        float32 = [4]f32{0, 0, 0, 1},
    }

    color_attachment := vulkan.RenderingAttachmentInfo {
        sType = .RENDERING_ATTACHMENT_INFO,
        imageView = renderer.swapchain_image_views[swapchain_image_index],
        imageLayout = .COLOR_ATTACHMENT_OPTIMAL,
        resolveMode = {},
        loadOp = .CLEAR,
        storeOp = .STORE,
        clearValue = vulkan.ClearValue{color = clear_value},
    }

    depth_attachment := vulkan.RenderingAttachmentInfo {
        sType       = .RENDERING_ATTACHMENT_INFO,
        imageView   = renderer.depth_image_view,
        imageLayout = .DEPTH_ATTACHMENT_OPTIMAL,
        resolveMode = {},
        loadOp      = .CLEAR,
        storeOp     = .STORE, // TODO: can this be DONT_CARE?
    }

    {     // memory barrier transition to fragment shader output writable
        memory_barrier_to_write := vk.create_image_memory_barrier(
            .UNDEFINED,
            .COLOR_ATTACHMENT_OPTIMAL,
            renderer.queue_family_index,
            renderer.swapchain_images[swapchain_image_index],
            .COLOR,
        )
        vulkan.CmdPipelineBarrier(
            commandBuffer = renderer.command_buffer,
            srcStageMask = {.COLOR_ATTACHMENT_OUTPUT},
            dstStageMask = {.COLOR_ATTACHMENT_OUTPUT},
            dependencyFlags = {.BY_REGION},
            imageMemoryBarrierCount = 1,
            pImageMemoryBarriers = &memory_barrier_to_write,
            memoryBarrierCount = 0,
            pMemoryBarriers = nil,
            bufferMemoryBarrierCount = 0,
            pBufferMemoryBarriers = nil,
        )
    }

    {     // memory barrier transition to presentable
        memory_barrier_to_present := vk.create_image_memory_barrier(
            .COLOR_ATTACHMENT_OPTIMAL,
            .PRESENT_SRC_KHR,
            renderer.queue_family_index,
            renderer.swapchain_images[swapchain_image_index],
            .COLOR,
        )
        vulkan.CmdPipelineBarrier(
            commandBuffer = renderer.command_buffer,
            srcStageMask = {.BOTTOM_OF_PIPE},
            dstStageMask = {.BOTTOM_OF_PIPE},
            dependencyFlags = {},
            imageMemoryBarrierCount = 1,
            pImageMemoryBarriers = &memory_barrier_to_present,
            memoryBarrierCount = 0,
            pMemoryBarriers = nil,
            bufferMemoryBarrierCount = 0,
            pBufferMemoryBarriers = nil,
        )
    }

    rendering_info := vulkan.RenderingInfo {
        sType = .RENDERING_INFO,
        renderArea = vulkan.Rect2D{offset = vulkan.Offset2D{0, 0}, extent = gc.surface_extent},
        layerCount = 1,
        viewMask = 0,
        colorAttachmentCount = 1,
        pColorAttachments = &color_attachment,
        pDepthAttachment = &depth_attachment,
    }
    vulkan.CmdBeginRendering(commandBuffer = renderer.command_buffer, pRenderingInfo = &rendering_info)

    vulkan.CmdBindPipeline(
        commandBuffer = renderer.command_buffer,
        pipelineBindPoint = .GRAPHICS,
        pipeline = renderer.graphics_pipeline,
    )

    offsets := []vulkan.DeviceSize{0}
    vulkan.CmdBindVertexBuffers(
        commandBuffer = renderer.command_buffer,
        firstBinding = 0,
        bindingCount = 1,
        pBuffers = &renderer.vertex_buffer,
        pOffsets = raw_data(offsets),
    )

    vulkan.CmdBindIndexBuffer(
        commandBuffer = renderer.command_buffer,
        buffer = renderer.index_buffer,
        offset = 0,
        indexType = .UINT32,
    )

    vulkan.CmdBindDescriptorSets(
        commandBuffer = renderer.command_buffer,
        pipelineBindPoint = .GRAPHICS,
        layout = renderer.pipeline_layout,
        firstSet = 0,
        descriptorSetCount = 1,
        pDescriptorSets = &renderer.descriptor_set,
        dynamicOffsetCount = 0,
        pDynamicOffsets = nil,
    )

    vulkan.CmdDrawIndexed(
        commandBuffer = renderer.command_buffer,
        indexCount = INDEX_BUFFER_SIZE,
        instanceCount = 1,
        firstIndex = 0,
        vertexOffset = 0,
        firstInstance = 0,
    )

    vulkan.CmdEndRendering(renderer.command_buffer)

    {     // end recording command buffer
        res := vulkan.EndCommandBuffer(renderer.command_buffer)
        if vk.not_success(res) {
            vk.fatal("failed to end command buffer", res)
        }
    }

    {     // submit commands
        submit_info := vulkan.SubmitInfo {
            sType                = .SUBMIT_INFO,
            commandBufferCount   = 1,
            pCommandBuffers      = &renderer.command_buffer,
            signalSemaphoreCount = 1,
            pSignalSemaphores    = &renderer.semaphores_draw_finished[swapchain_image_index],
        }
        res := vulkan.QueueSubmit(renderer.queue, 1, &submit_info, renderer.fence_frame_finished)
        if vk.not_success(res) {
            vk.fatal("failed to submit command", res)
        }
    }

    {     // present images
        present_info := vulkan.PresentInfoKHR {
            sType              = .PRESENT_INFO_KHR,
            waitSemaphoreCount = 1,
            pWaitSemaphores    = &renderer.semaphores_draw_finished[swapchain_image_index],
            swapchainCount     = 1,
            pSwapchains        = &renderer.swapchain,
            pImageIndices      = &swapchain_image_index,
            pResults           = nil,
        }
        res := vulkan.QueuePresentKHR(renderer.queue, &present_info)
        if res == .ERROR_OUT_OF_DATE_KHR || res == .SUBOPTIMAL_KHR {
            // fmt.println("swapchain out of date / suboptimal on queue present")
        } else if vk.not_success(res) {
            vk.fatal("failed to present image", res)
        }
    }
}

create_swapchain :: proc(renderer: ^Renderer) {
    surface_capabilities := vk.get_physical_device_surface_capabilities_khr(renderer.physical_device, gc.vk_surface)
    supported_present_modes_res, supported_present_modes_count, supported_present_modes :=
        vk.get_physical_device_surface_present_modes_khr(renderer.physical_device, gc.vk_surface)
    if vk.not_success(supported_present_modes_res) {
        vk.fatal(
            "failed to get count of supported present modes",
            supported_present_modes_res,
            supported_present_modes_count,
        )
    }
    defer delete(supported_present_modes)
    mailbox_supported := false
    for supported_mode in supported_present_modes {
        if supported_mode == .MAILBOX {
            mailbox_supported = true
            break
        }
    }
    present_mode: vulkan.PresentModeKHR = .MAILBOX if mailbox_supported else .FIFO

    get_supported_formats_res, supported_format_count, supported_formats := vk.get_physical_device_surface_formats_khr(
        renderer.physical_device,
        gc.vk_surface,
    )
    if vk.not_success(get_supported_formats_res) {
        vk.fatal("failed to get count of supported surface formats", get_supported_formats_res, supported_format_count)
    }
    defer delete(supported_formats)

    desired_format := vulkan.SurfaceFormatKHR {
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

    gc.surface_extent = surface_capabilities.currentExtent

    create_info := vulkan.SwapchainCreateInfoKHR {
        sType            = .SWAPCHAIN_CREATE_INFO_KHR,
        flags            = vulkan.SwapchainCreateFlagsKHR{},
        surface          = gc.vk_surface,
        minImageCount    = surface_capabilities.minImageCount,
        imageFormat      = surface_image_format.format,
        imageColorSpace  = surface_image_format.colorSpace,
        imageExtent      = gc.surface_extent,
        imageArrayLayers = 1,
        imageUsage       = vulkan.ImageUsageFlags{.COLOR_ATTACHMENT},
        imageSharingMode = .EXCLUSIVE,
        preTransform     = surface_capabilities.currentTransform,
        compositeAlpha   = vulkan.CompositeAlphaFlagsKHR{.OPAQUE},
        presentMode      = present_mode,
        clipped          = true,
    }
    res := vulkan.CreateSwapchainKHR(renderer.device, &create_info, nil, &renderer.swapchain)
    if vk.not_success(res) {
        vk.fatal("failed to create swapchain", res)
    }
    renderer.swapchain_image_format = surface_image_format.format
}

create_swapchain_images :: proc(renderer: ^Renderer) {
    res, count, swapchain_images := vk.get_swapchain_images_khr(renderer.device, renderer.swapchain)
    if vk.not_success(res) {
        vk.fatal("failed to get swapchain images", res, count)
    }
    renderer.swapchain_images = swapchain_images
}

create_swapchain_image_views :: proc(renderer: ^Renderer) {
    renderer.swapchain_image_views = make([]vulkan.ImageView, cast(u32)len(renderer.swapchain_images))
    for i in 0 ..< len(renderer.swapchain_images) {
        create_info := vulkan.ImageViewCreateInfo {
            sType = .IMAGE_VIEW_CREATE_INFO,
            flags = {},
            image = renderer.swapchain_images[i],
            viewType = .D2,
            format = renderer.swapchain_image_format,
            components = {r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY},
            subresourceRange = {
                aspectMask = vulkan.ImageAspectFlags{.COLOR},
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
        }
        res := vulkan.CreateImageView(renderer.device, &create_info, nil, &renderer.swapchain_image_views[i])
        if vk.not_success(res) {
            vk.fatal("failed to create swapchain image views", res)
        }
    }}

create_graphics_pipeline :: proc(renderer: ^Renderer) {
    vertex_shader_stage_create_info := vulkan.PipelineShaderStageCreateInfo {
        sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        flags  = {},
        stage  = {.VERTEX},
        module = renderer.vertex_shader_module,
        pName  = "main",
    }

    fragment_shader_stage_create_info := vulkan.PipelineShaderStageCreateInfo {
        sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        flags  = {},
        stage  = {.FRAGMENT},
        module = renderer.fragment_shader_module,
        pName  = "main",
    }

    pipeline_shader_stages := []vulkan.PipelineShaderStageCreateInfo {
        vertex_shader_stage_create_info,
        fragment_shader_stage_create_info,
    }

    vertex_input_state_create_info := vulkan.PipelineVertexInputStateCreateInfo {
        sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        flags                           = {},
        vertexBindingDescriptionCount   = 1,
        pVertexBindingDescriptions      = &vertex_input_binding_description,
        vertexAttributeDescriptionCount = cast(u32)len(vertex_input_attribute_descriptions),
        pVertexAttributeDescriptions    = raw_data(vertex_input_attribute_descriptions),
    }

    input_assembly_state_create_info := vulkan.PipelineInputAssemblyStateCreateInfo {
        sType    = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        flags    = {},
        topology = .TRIANGLE_LIST,
    }

    viewport := vulkan.Viewport {
        x        = 0,
        y        = 0,
        width    = cast(f32)gc.surface_extent.width,
        height   = cast(f32)gc.surface_extent.height,
        minDepth = 0,
        maxDepth = 1,
    }
    scissor := vulkan.Rect2D {
        offset = {x = 0, y = 0},
        extent = gc.surface_extent,
    }
    viewport_state_create_info := vulkan.PipelineViewportStateCreateInfo {
        sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        viewportCount = 1,
        pViewports    = &viewport,
        scissorCount  = 1,
        pScissors     = &scissor,
    }

    rasterization_state_create_info := vulkan.PipelineRasterizationStateCreateInfo {
        sType            = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        depthClampEnable = false,
        polygonMode      = .FILL,
        cullMode         = {.BACK},
        frontFace        = .CLOCKWISE,
        lineWidth        = 1,
    }

    multisample_state_create_info := vulkan.PipelineMultisampleStateCreateInfo {
        sType                = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        sampleShadingEnable  = false,
        rasterizationSamples = vulkan.SampleCountFlags{._1},
    }

    pipeline_layout_create_info := vulkan.PipelineLayoutCreateInfo {
        sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
        flags                  = {},
        setLayoutCount         = 1,
        pSetLayouts            = &renderer.descriptor_set_layout,
        pushConstantRangeCount = 0,
        pPushConstantRanges    = nil,
    }
    pipeline_layout_create_res := vulkan.CreatePipelineLayout(
        renderer.device,
        &pipeline_layout_create_info,
        nil,
        &renderer.pipeline_layout,
    )
    if vk.not_success(pipeline_layout_create_res) {
        vk.fatal("failed to create pipeline layout", pipeline_layout_create_res)
    }
    pipeline_rendering_create_info := vulkan.PipelineRenderingCreateInfo {
        sType                   = .PIPELINE_RENDERING_CREATE_INFO,
        viewMask                = 0,
        colorAttachmentCount    = 1,
        pColorAttachmentFormats = &renderer.swapchain_image_format,
        depthAttachmentFormat   = .D32_SFLOAT,
    }

    // Note: alpha = 0 => fully transparent
    pipeline_color_blend_attachment_state := vulkan.PipelineColorBlendAttachmentState {
        blendEnable         = true,
        colorWriteMask      = {.R, .G, .B, .A},
        colorBlendOp        = .ADD,
        alphaBlendOp        = .MAX,
        srcColorBlendFactor = .SRC_ALPHA,
        dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
        srcAlphaBlendFactor = .ONE,
        dstAlphaBlendFactor = .ONE,
    }

    color_blend_state_create_info := vulkan.PipelineColorBlendStateCreateInfo {
        sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        flags           = {},
        logicOpEnable   = false,
        attachmentCount = 1,
        pAttachments    = &pipeline_color_blend_attachment_state,
    }

    depth_stencil_state_create_info := vulkan.PipelineDepthStencilStateCreateInfo {
        sType                 = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        flags                 = {},
        depthTestEnable       = true,
        depthWriteEnable      = true,
        depthCompareOp        = .GREATER_OR_EQUAL,
        depthBoundsTestEnable = false,
        stencilTestEnable     = false,
    }

    create_info := vulkan.GraphicsPipelineCreateInfo {
        sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
        pNext               = &pipeline_rendering_create_info,
        flags               = {},
        stageCount          = cast(u32)len(pipeline_shader_stages),
        pStages             = raw_data(pipeline_shader_stages),
        pVertexInputState   = &vertex_input_state_create_info,
        pInputAssemblyState = &input_assembly_state_create_info,
        pViewportState      = &viewport_state_create_info,
        pRasterizationState = &rasterization_state_create_info,
        pMultisampleState   = &multisample_state_create_info,
        pColorBlendState    = &color_blend_state_create_info,
        pDepthStencilState  = &depth_stencil_state_create_info,
        layout              = renderer.pipeline_layout,
        renderPass          = {},
        subpass             = 0,
    }
    res := vulkan.CreateGraphicsPipelines(renderer.device, {}, 1, &create_info, nil, &renderer.graphics_pipeline)
}

handle_screen_resized :: proc(renderer: ^Renderer) {
    wait_res := vulkan.DeviceWaitIdle(renderer.device)
    if vk.not_success(wait_res) {
        vk.fatal("failed wait for idle", wait_res)
    }

    for i in 0 ..< len(renderer.swapchain_images) {
        vulkan.DestroyImageView(renderer.device, renderer.swapchain_image_views[i], nil)
    }
    delete(renderer.swapchain_image_views)
    delete(renderer.swapchain_images)
    vulkan.DestroySwapchainKHR(renderer.device, renderer.swapchain, nil)
    vulkan.DestroyPipeline(renderer.device, renderer.graphics_pipeline, nil)
    vulkan.DestroyImageView(renderer.device, renderer.depth_image_view, nil)
    vulkan.DestroyImage(renderer.device, renderer.depth_image, nil)
    vulkan.FreeMemory(renderer.device, renderer.depth_image_memory, nil)

    create_swapchain(renderer)
    create_swapchain_images(renderer)
    create_swapchain_image_views(renderer)
    create_graphics_pipeline(renderer)
    create_depth_image_and_view(renderer)

    gc.window_resized = false
}

create_depth_image_and_view :: proc(renderer: ^Renderer) {
    {     // create depth image resource
        create_image_info := vulkan.ImageCreateInfo {
            sType = .IMAGE_CREATE_INFO,
            imageType = .D2,
            format = .D32_SFLOAT,
            extent = vulkan.Extent3D {
                width = gc.surface_extent.width,
                height = gc.surface_extent.height,
                depth = 1,
            },
            mipLevels = 1,
            arrayLayers = 1,
            tiling = .OPTIMAL,
            sharingMode = .EXCLUSIVE,
            initialLayout = .UNDEFINED,
            samples = {._1},
            usage = {.DEPTH_STENCIL_ATTACHMENT},
        }
        image_create_res := vulkan.CreateImage(renderer.device, &create_image_info, nil, &renderer.depth_image)
        if vk.not_success(image_create_res) {
            vk.fatal("failed to create depth image", image_create_res)
        }

        ok, depth_image_memory := vk.allocate_resource_memory(
            renderer.depth_image,
            renderer.device,
            renderer.physical_device,
            {.DEVICE_LOCAL},
        )
        if !ok {
            vk.fatal("failed to allocate and map texture image memory")
        }
        renderer.depth_image_memory = depth_image_memory

        if !vk.begin_recording_one_time_submit_commands(renderer.command_buffer) {
            vk.fatal("failed to begin recording depth image commands")
        }

        depth_optimal_barrier := vk.create_image_memory_barrier(
            .UNDEFINED,
            .DEPTH_ATTACHMENT_OPTIMAL,
            renderer.queue_family_index,
            renderer.depth_image,
            .DEPTH,
        )
        vulkan.CmdPipelineBarrier(
            commandBuffer = renderer.command_buffer,
            srcStageMask = {.TOP_OF_PIPE},
            dstStageMask = {.LATE_FRAGMENT_TESTS},
            dependencyFlags = {},
            imageMemoryBarrierCount = 1,
            pImageMemoryBarriers = &depth_optimal_barrier,
            memoryBarrierCount = 0,
            pMemoryBarriers = nil,
            bufferMemoryBarrierCount = 0,
            pBufferMemoryBarriers = nil,
        )

        if vulkan.EndCommandBuffer(renderer.command_buffer) != .SUCCESS {
            vk.fatal("failed to end recording texture image commands")
        }

        submit_info := vulkan.SubmitInfo {
            sType                = .SUBMIT_INFO,
            commandBufferCount   = 1,
            pCommandBuffers      = &renderer.command_buffer,
            signalSemaphoreCount = 0,
            pSignalSemaphores    = nil,
        }
        res := vulkan.QueueSubmit(renderer.queue, 1, &submit_info, {})
        if vk.not_success(res) {
            vk.fatal("failed to submit command", res)
        }
        vulkan.DeviceWaitIdle(renderer.device)
    }

    {     // create depth image view
        create_info := vulkan.ImageViewCreateInfo {
            sType = .IMAGE_VIEW_CREATE_INFO,
            viewType = .D2,
            format = .D32_SFLOAT,
            image = renderer.depth_image,
            flags = {},
            components = {},
            subresourceRange = {
                aspectMask = vulkan.ImageAspectFlags{.DEPTH},
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
        }
        res := vulkan.CreateImageView(renderer.device, &create_info, nil, &renderer.depth_image_view)
        if vk.not_success(res) {
            vk.fatal("failed to create depth image view", res)
        }
    }
}
