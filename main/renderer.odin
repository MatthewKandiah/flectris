package main

import "base:intrinsics"
import "core:fmt"
import "core:os"
import "img"
import "vendor:glfw"
import "vendor:stb/image"
import "vendor:vulkan"
import "vk"

VERTEX_SHADER_PATH :: "vert.spv"
FRAGMENT_SHADER_PATH :: "frag.spv"
TEXTURE_PATH :: "main/smiley.png"

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
    surface_extent:              vulkan.Extent2D,
    command_pool:                vulkan.CommandPool,
    command_buffer:              vulkan.CommandBuffer,
    semaphores_draw_finished:    []vulkan.Semaphore,
    fence_image_acquired:        vulkan.Fence,
    fence_frame_finished:        vulkan.Fence,
    texture_image:               vulkan.Image,
    texture_image_memory:        vulkan.DeviceMemory,
    texture_image_memory_mapped: rawptr,
}

init_renderer :: proc() -> (renderer: Renderer) {
    {     // pick a physical device
        res, count, physical_devices := vk.enumerate_physical_devices(gc.vk_instance)
        if vk.not_success(res) {
            vk.fatal("failed to enumerate physical devices", res, count)
        }
        defer delete(physical_devices)

        for device in physical_devices {
            properties: vulkan.PhysicalDeviceProperties
            vulkan.GetPhysicalDeviceProperties(device, &properties)

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

    {     // retrieve queue handle
        vulkan.GetDeviceQueue(renderer.device, renderer.queue_family_index, 0, &renderer.queue)
    }

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

    {     // create texture image resource
        ok, x, y, channels_in_file, data := img.load(TEXTURE_PATH, 4)
        if !ok {
            img.fatal("failed to load texture image from file", TEXTURE_PATH, x, y, channels_in_file)
        }
        defer img.free(data)

        create_image_info := vulkan.ImageCreateInfo {
            sType = .IMAGE_CREATE_INFO,
            imageType = .D2,
            format = .R32G32B32A32_UINT, // TODO consider changing to floats for easier maths?
            extent = vulkan.Extent3D{width = cast(u32)x, height = cast(u32)y, depth = 1},
            mipLevels = 1,
            arrayLayers = 1,
            tiling = .OPTIMAL,
            sharingMode = .EXCLUSIVE,
            initialLayout = .UNDEFINED,
            samples = {._1},
            usage = {.SAMPLED},
        }
        res := vulkan.CreateImage(renderer.device, &create_image_info, nil, &renderer.texture_image)
        if vk.not_success(res) {
            vk.fatal("failed to create texture image", res)
        }

        memory_requirements: vulkan.MemoryRequirements
        vulkan.GetImageMemoryRequirements(renderer.device, renderer.texture_image, &memory_requirements)

        //TODO memory allocation and binding and mapping and copying data is copy-pasted at least 3 times, refactor
        memory_properties := vk.get_physical_device_memory_properties(renderer.physical_device)
        desired_memory_type_properties := vulkan.MemoryPropertyFlags{.HOST_VISIBLE, .HOST_COHERENT}
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

        alloc_info := vulkan.MemoryAllocateInfo {
            sType           = .MEMORY_ALLOCATE_INFO,
            allocationSize  = memory_requirements.size,
            memoryTypeIndex = cast(u32)memory_type_index,
        }
        allocate_res := vulkan.AllocateMemory(renderer.device, &alloc_info, nil, &renderer.texture_image_memory)
        if vk.not_success(allocate_res) {
            vk.fatal("failed to allocate memory")
        }

        bind_res := vulkan.BindImageMemory(renderer.device, renderer.texture_image, renderer.texture_image_memory, 0)
        if vk.not_success(res) {
            vk.fatal("failed to bind image memory")
        }

        map_res := vulkan.MapMemory(
            renderer.device,
            renderer.texture_image_memory,
            0,
            cast(vulkan.DeviceSize)vulkan.WHOLE_SIZE,
            {},
            &renderer.texture_image_memory_mapped,
        )
	if vk.not_success(map_res) {
	    vk.fatal("failed to map image memory", res)
	}

	intrinsics.mem_copy_non_overlapping(
	    renderer.texture_image_memory_mapped,
	    raw_data(data),
	    size_of(data[0]) * len(data) // TODO - verify we're getting the whole image copied, think we might just be getting a quarter of it (or we're allocating more memory than needed for the image)
	)
    }

    {     // create vertex buffer
        create_info := vulkan.BufferCreateInfo {
            sType       = .BUFFER_CREATE_INFO,
            flags       = {},
            size        = cast(vulkan.DeviceSize)(size_of(Vertex) * len(vertices)),
            usage       = {.VERTEX_BUFFER},
            sharingMode = .EXCLUSIVE,
        }
        res := vulkan.CreateBuffer(renderer.device, &create_info, nil, &renderer.vertex_buffer)
        if vk.not_success(res) {
            vk.fatal("failed to create vertex buffer", res)
        }
    }

    {     // allocate vertex buffer memory and bind it
        memory_requirements := vk.get_buffer_memory_requirements(renderer.device, renderer.vertex_buffer)
        memory_properties := vk.get_physical_device_memory_properties(renderer.physical_device)
        desired_memory_type_properties := vulkan.MemoryPropertyFlags{.HOST_VISIBLE, .HOST_COHERENT}
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

        allocate_info := vulkan.MemoryAllocateInfo {
            sType           = .MEMORY_ALLOCATE_INFO,
            allocationSize  = memory_requirements.size,
            memoryTypeIndex = cast(u32)memory_type_index,
        }
        res := vulkan.AllocateMemory(renderer.device, &allocate_info, nil, &renderer.vertex_buffer_memory)
        if vk.not_success(res) {
            vk.fatal("failed to allocate vertex buffer memory", res)
        }

        bind_res := vulkan.BindBufferMemory(renderer.device, renderer.vertex_buffer, renderer.vertex_buffer_memory, 0)
        if vk.not_success(bind_res) {
            vk.fatal("failed to bind vertex buffer memory", bind_res)
        }
    }

    {     // map vertex buffer memory
        res := vulkan.MapMemory(
            renderer.device,
            renderer.vertex_buffer_memory,
            0,
            cast(vulkan.DeviceSize)vulkan.WHOLE_SIZE,
            {},
            &renderer.vertex_buffer_memory_mapped,
        )
    }

    {     // copy vertex data into vertex buffer
        intrinsics.mem_copy_non_overlapping(
            renderer.vertex_buffer_memory_mapped,
            raw_data(vertices),
            size_of(Vertex) * len(vertices),
        )
    }

    {     // create index buffer
        create_info := vulkan.BufferCreateInfo {
            sType       = .BUFFER_CREATE_INFO,
            flags       = {},
            size        = cast(vulkan.DeviceSize)(size_of(u32) * len(indices)),
            usage       = {.INDEX_BUFFER},
            sharingMode = .EXCLUSIVE,
        }
        res := vulkan.CreateBuffer(renderer.device, &create_info, nil, &renderer.index_buffer)
        if vk.not_success(res) {
            vk.fatal("failed to create index buffer", res)
        }
    }

    {     // allocate index buffer memory and bind it
        memory_requirements := vk.get_buffer_memory_requirements(renderer.device, renderer.index_buffer)
        memory_properties := vk.get_physical_device_memory_properties(renderer.physical_device)
        desired_memory_type_properties := vulkan.MemoryPropertyFlags{.HOST_VISIBLE, .HOST_COHERENT}
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
            panic("failed to find a suitable memory type for index buffer allocation")
        }

        allocate_info := vulkan.MemoryAllocateInfo {
            sType           = .MEMORY_ALLOCATE_INFO,
            allocationSize  = memory_requirements.size,
            memoryTypeIndex = cast(u32)memory_type_index,
        }
        res := vulkan.AllocateMemory(renderer.device, &allocate_info, nil, &renderer.index_buffer_memory)
        if vk.not_success(res) {
            vk.fatal("failed to allocate index buffer memory", res)
        }

        bind_res := vulkan.BindBufferMemory(renderer.device, renderer.index_buffer, renderer.index_buffer_memory, 0)
        if vk.not_success(bind_res) {
            vk.fatal("failed to bind index buffer memory", bind_res)
        }
    }

    {     // map index buffer memory
        res := vulkan.MapMemory(
            renderer.device,
            renderer.index_buffer_memory,
            0,
            cast(vulkan.DeviceSize)vulkan.WHOLE_SIZE,
            {},
            &renderer.index_buffer_memory_mapped,
        )
    }

    {     // copy index data into index buffer
        intrinsics.mem_copy_non_overlapping(
            renderer.index_buffer_memory_mapped,
            raw_data(indices),
            size_of(u32) * len(indices),
        )
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
                vk.fatal("failed to create draw finished semaphore", draw_finished_semaphore_res)
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

draw_frame :: proc(renderer: ^Renderer) {
    if gc.window_resized {
        handle_screen_resized(renderer)
        return
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

    {     // begin recording commands
        begin_info := vulkan.CommandBufferBeginInfo {
            sType = .COMMAND_BUFFER_BEGIN_INFO,
            flags = {.ONE_TIME_SUBMIT},
        }
        res := vulkan.BeginCommandBuffer(renderer.command_buffer, &begin_info)
        if vk.not_success(res) {
            vk.fatal("failed to begin command buffer", res)
        }
    }

    clear_value := vulkan.ClearColorValue {
        float32 = [4]f32{1, 0, 1, 1},
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

    {     // memory barrier transition to fragment shader output writable
        memory_barrier_to_write := vulkan.ImageMemoryBarrier {
            sType = .IMAGE_MEMORY_BARRIER,
            srcAccessMask = {},
            dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
            oldLayout = .UNDEFINED,
            newLayout = .COLOR_ATTACHMENT_OPTIMAL,
            srcQueueFamilyIndex = renderer.queue_family_index,
            dstQueueFamilyIndex = renderer.queue_family_index,
            image = renderer.swapchain_images[swapchain_image_index],
            subresourceRange = vulkan.ImageSubresourceRange {
                aspectMask = {.COLOR},
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
        }
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
        memory_barrier_to_present := vulkan.ImageMemoryBarrier {
            sType = .IMAGE_MEMORY_BARRIER,
            srcAccessMask = {},
            dstAccessMask = {},
            oldLayout = .COLOR_ATTACHMENT_OPTIMAL,
            newLayout = .PRESENT_SRC_KHR,
            srcQueueFamilyIndex = renderer.queue_family_index,
            dstQueueFamilyIndex = renderer.queue_family_index,
            image = renderer.swapchain_images[swapchain_image_index],
            subresourceRange = vulkan.ImageSubresourceRange {
                aspectMask = {.COLOR},
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
        }
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
        renderArea = vulkan.Rect2D{offset = vulkan.Offset2D{0, 0}, extent = renderer.surface_extent},
        layerCount = 1,
        viewMask = 0,
        colorAttachmentCount = 1,
        pColorAttachments = &color_attachment,
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

    vulkan.CmdDrawIndexed(
        commandBuffer = renderer.command_buffer,
        indexCount = cast(u32)len(indices),
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

    renderer.surface_extent = surface_capabilities.currentExtent

    create_info := vulkan.SwapchainCreateInfoKHR {
        sType            = .SWAPCHAIN_CREATE_INFO_KHR,
        flags            = vulkan.SwapchainCreateFlagsKHR{},
        surface          = gc.vk_surface,
        minImageCount    = surface_capabilities.minImageCount,
        imageFormat      = surface_image_format.format,
        imageColorSpace  = surface_image_format.colorSpace,
        imageExtent      = renderer.surface_extent,
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
        width    = cast(f32)renderer.surface_extent.width,
        height   = cast(f32)renderer.surface_extent.height,
        minDepth = 0,
        maxDepth = 1,
    }
    scissor := vulkan.Rect2D {
        offset = {x = 0, y = 0},
        extent = renderer.surface_extent,
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
        frontFace        = .COUNTER_CLOCKWISE,
        lineWidth        = 1,
    }

    multisample_state_create_info := vulkan.PipelineMultisampleStateCreateInfo {
        sType                = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        sampleShadingEnable  = false,
        rasterizationSamples = vulkan.SampleCountFlags{._1},
    }

    pipeline_layout: vulkan.PipelineLayout
    pipeline_layout_create_info := vulkan.PipelineLayoutCreateInfo {
        sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
        flags                  = {},
        setLayoutCount         = 0,
        pSetLayouts            = nil,
        pushConstantRangeCount = 0,
        pPushConstantRanges    = nil,
    }
    pipeline_layout_create_res := vulkan.CreatePipelineLayout(
        renderer.device,
        &pipeline_layout_create_info,
        nil,
        &pipeline_layout,
    )
    if vk.not_success(pipeline_layout_create_res) {
        vk.fatal("failed to create pipeline layout", pipeline_layout_create_res)
    }

    pipeline_rendering_create_info := vulkan.PipelineRenderingCreateInfo {
        sType                   = .PIPELINE_RENDERING_CREATE_INFO,
        viewMask                = 0,
        colorAttachmentCount    = 1,
        pColorAttachmentFormats = &renderer.swapchain_image_format,
    }

    pipeline_color_blend_attachment_state := vulkan.PipelineColorBlendAttachmentState {
        blendEnable    = false,
        colorWriteMask = {.R, .G, .B, .A},
    }

    color_blend_state_create_info := vulkan.PipelineColorBlendStateCreateInfo {
        sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        flags           = {},
        logicOpEnable   = false,
        attachmentCount = 1,
        pAttachments    = &pipeline_color_blend_attachment_state,
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
        layout              = pipeline_layout,
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

    create_swapchain(renderer)
    create_swapchain_images(renderer)
    create_swapchain_image_views(renderer)
    create_graphics_pipeline(renderer)

    gc.window_resized = false
}
