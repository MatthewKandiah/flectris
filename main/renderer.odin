package main

import "base:intrinsics"
import "core:fmt"
import "core:os"
import "vendor:glfw"
import vk "vendor:vulkan"

VERTEX_SHADER_PATH :: "vert.spv"
FRAGMENT_SHADER_PATH :: "frag.spv"

Renderer :: struct {
    physical_device:             vk.PhysicalDevice,
    queue_family_index:          u32,
    queue:                       vk.Queue,
    device:                      vk.Device,
    swapchain:                   vk.SwapchainKHR,
    swapchain_images:            []vk.Image,
    swapchain_image_views:       []vk.ImageView,
    swapchain_image_format:      vk.Format,
    vertex_buffer:               vk.Buffer,
    vertex_buffer_memory:        vk.DeviceMemory,
    vertex_buffer_memory_mapped: rawptr,
    index_buffer:                vk.Buffer,
    index_buffer_memory:         vk.DeviceMemory,
    index_buffer_memory_mapped:  rawptr,
    fragment_shader_module:      vk.ShaderModule,
    vertex_shader_module:        vk.ShaderModule,
    graphics_pipeline:           vk.Pipeline,
    surface_extent:              vk.Extent2D,
    command_pool:                vk.CommandPool,
    command_buffer:              vk.CommandBuffer,
    semaphores_draw_finished:    []vk.Semaphore,
    fence_image_acquired:        vk.Fence,
    fence_frame_finished:        vk.Fence,
}

init_renderer :: proc() -> (renderer: Renderer) {
    {     // pick a physical device
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

    {     // pick a device queue index
        count: u32
        vk.GetPhysicalDeviceQueueFamilyProperties(renderer.physical_device, &count, nil)
        queue_families_properties := make([]vk.QueueFamilyProperties, count)
        defer delete(queue_families_properties)
        vk.GetPhysicalDeviceQueueFamilyProperties(
            renderer.physical_device,
            &count,
            raw_data(queue_families_properties),
        )

        found := false
        for queue_family_properties, index in queue_families_properties {
            graphics_and_transfer_supported :=
                vk.QueueFlags{.GRAPHICS, .TRANSFER} <= queue_family_properties.queueFlags
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
        queue_create_info := vk.DeviceQueueCreateInfo {
            sType            = .DEVICE_QUEUE_CREATE_INFO,
            queueFamilyIndex = renderer.queue_family_index,
            queueCount       = 1,
            pQueuePriorities = raw_data(priorities),
        }

        dynamic_rendering_local_read := vk.PhysicalDeviceDynamicRenderingLocalReadFeatures {
            sType                     = .PHYSICAL_DEVICE_DYNAMIC_RENDERING_LOCAL_READ_FEATURES,
            pNext                     = nil,
            dynamicRenderingLocalRead = true,
        }

        dynamic_rendering_features := vk.PhysicalDeviceDynamicRenderingFeatures {
            sType            = .PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES,
            pNext            = &dynamic_rendering_local_read,
            dynamicRendering = true,
        }

        create_info := vk.DeviceCreateInfo {
            sType                   = .DEVICE_CREATE_INFO,
            pNext                   = &dynamic_rendering_features,
            queueCreateInfoCount    = 1,
            pQueueCreateInfos       = &queue_create_info,
            enabledExtensionCount   = cast(u32)len(REQUIRED_DEVICE_EXTENSIONS),
            ppEnabledExtensionNames = raw_data(REQUIRED_DEVICE_EXTENSIONS),
        }
        res := vk.CreateDevice(renderer.physical_device, &create_info, nil, &renderer.device)
        if res != .SUCCESS {
            panic("failed to create logical device")
        }
    }

    {     // retrieve queue handle
        vk.GetDeviceQueue(renderer.device, renderer.queue_family_index, 0, &renderer.queue)
    }

    create_swapchain(&renderer)
    create_swapchain_images(&renderer)
    create_swapchain_image_views(&renderer)

    {     // create command pool
        create_info := vk.CommandPoolCreateInfo {
            sType            = .COMMAND_POOL_CREATE_INFO,
            flags            = {.RESET_COMMAND_BUFFER},
            queueFamilyIndex = renderer.queue_family_index,
        }
        res := vk.CreateCommandPool(renderer.device, &create_info, nil, &renderer.command_pool)
        if res != .SUCCESS {
            panic("failed to create command pool")
        }
    }

    {     // allocate a command buffer
        allocate_info := vk.CommandBufferAllocateInfo {
            sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
            commandPool        = renderer.command_pool,
            level              = .PRIMARY,
            commandBufferCount = 1,
        }
        res := vk.AllocateCommandBuffers(renderer.device, &allocate_info, &renderer.command_buffer)
        if res != .SUCCESS {
            panic("failed to allocate command buffer")
        }
    }

    {     // create vertex buffer
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

    {     // allocate vertex buffer memory and bind it
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

    {     // map vertex buffer memory
        res := vk.MapMemory(
            renderer.device,
            renderer.vertex_buffer_memory,
            0,
            cast(vk.DeviceSize)vk.WHOLE_SIZE,
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
        create_info := vk.BufferCreateInfo {
            sType       = .BUFFER_CREATE_INFO,
            flags       = {},
            size        = cast(vk.DeviceSize)(size_of(u32) * len(indices)),
            usage       = {.INDEX_BUFFER},
            sharingMode = .EXCLUSIVE,
        }
        res := vk.CreateBuffer(renderer.device, &create_info, nil, &renderer.index_buffer)
        if res != .SUCCESS {
            panic("failed to create index buffer")
        }
    }

    {     // allocate index buffer memory and bind it
        memory_requirements: vk.MemoryRequirements
        vk.GetBufferMemoryRequirements(renderer.device, renderer.index_buffer, &memory_requirements)

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
            panic("failed to find a suitable memory type for index buffer allocation")
        }

        allocate_info := vk.MemoryAllocateInfo {
            sType           = .MEMORY_ALLOCATE_INFO,
            allocationSize  = memory_requirements.size,
            memoryTypeIndex = cast(u32)memory_type_index,
        }
        res := vk.AllocateMemory(renderer.device, &allocate_info, nil, &renderer.index_buffer_memory)
        if res != .SUCCESS {
            panic("failed to allocate index buffer memory")
        }

        bind_res := vk.BindBufferMemory(renderer.device, renderer.index_buffer, renderer.index_buffer_memory, 0)
        if bind_res != .SUCCESS {
            panic("failed to bind index buffer memory")
        }
    }

    {     // map index buffer memory
        res := vk.MapMemory(
            renderer.device,
            renderer.index_buffer_memory,
            0,
            cast(vk.DeviceSize)vk.WHOLE_SIZE,
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
        create_info := vk.ShaderModuleCreateInfo {
            sType    = .SHADER_MODULE_CREATE_INFO,
            codeSize = len(data),
            pCode    = cast(^u32)raw_data(data),
        }
        res := vk.CreateShaderModule(renderer.device, &create_info, nil, &renderer.vertex_shader_module)
        if res != .SUCCESS {
            panic("failed to create vertex shader module")
        }
    }

    {     // create fragment shader module
        data, err := os.read_entire_file_from_filename_or_err(FRAGMENT_SHADER_PATH)
        if err != nil {
            fmt.eprintln("Error reading fragment shader file", err)
            panic("Failed to read fragment shader file")
        }
        create_info := vk.ShaderModuleCreateInfo {
            sType    = .SHADER_MODULE_CREATE_INFO,
            codeSize = len(data),
            pCode    = cast(^u32)raw_data(data),
        }
        res := vk.CreateShaderModule(renderer.device, &create_info, nil, &renderer.fragment_shader_module)
        if res != .SUCCESS {
            panic("failed to create fragment shader module")
        }
    }

    create_graphics_pipeline(&renderer)

    {     // create synchronisation objects
        semaphore_create_info := vk.SemaphoreCreateInfo {
            sType = .SEMAPHORE_CREATE_INFO,
        }
        renderer.semaphores_draw_finished = make([]vk.Semaphore, len(renderer.swapchain_images))
        for i in 0 ..< len(renderer.swapchain_images) {
            draw_finished_semaphore_res := vk.CreateSemaphore(
                renderer.device,
                &semaphore_create_info,
                nil,
                &renderer.semaphores_draw_finished[i],
            )
            if draw_finished_semaphore_res != .SUCCESS {
                panic("failed to create draw finished semaphore")
            }
        }

        image_acquired_fence_create_info := vk.FenceCreateInfo {
            sType = .FENCE_CREATE_INFO,
            flags = {},
        }
        image_acquired_fence_res := vk.CreateFence(
            renderer.device,
            &image_acquired_fence_create_info,
            nil,
            &renderer.fence_image_acquired,
        )
        if image_acquired_fence_res != .SUCCESS {
            panic("failed to create image acquired fence")
        }

        frame_fence_create_info := vk.FenceCreateInfo {
            sType = .FENCE_CREATE_INFO,
            flags = {.SIGNALED},
        }
        frame_finished_fence_res := vk.CreateFence(
            renderer.device,
            &frame_fence_create_info,
            nil,
            &renderer.fence_frame_finished,
        )
    }

    return renderer
}

deinit_renderer :: proc(using renderer: ^Renderer) {
    for i in 0 ..< len(swapchain_images) {
        vk.DestroySemaphore(device, semaphores_draw_finished[i], nil)
    }
    delete(semaphores_draw_finished)
    vk.DestroyFence(device, fence_image_acquired, nil)
    vk.DestroyFence(device, fence_frame_finished, nil)
    vk.DestroyCommandPool(device, command_pool, nil)
    vk.DestroyShaderModule(device, vertex_shader_module, nil)
    vk.DestroyBuffer(device, vertex_buffer, nil)
    vk.DestroyBuffer(device, index_buffer, nil)
    renderer.vertex_buffer_memory_mapped = nil
    renderer.index_buffer_memory_mapped = nil
    vk.UnmapMemory(device, vertex_buffer_memory)
    vk.UnmapMemory(device, index_buffer_memory)
    vk.FreeMemory(device, vertex_buffer_memory, nil)
    vk.FreeMemory(device, index_buffer_memory, nil)
    for image_view in swapchain_image_views {
        vk.DestroyImageView(device, image_view, nil)
    }
    delete(swapchain_image_views)
    delete(swapchain_images)
    vk.DestroySwapchainKHR(device, swapchain, nil)
    vk.DestroySurfaceKHR(gc.vk_instance, gc.vk_surface, nil)
    vk.DestroyDevice(device, nil)
}

draw_frame :: proc(renderer: ^Renderer) {
    if gc.window_resized {
        handle_screen_resized(renderer)
        return
    }

    {     // ensure previous frame finished before we start
        wait_res := vk.WaitForFences(renderer.device, 1, &renderer.fence_frame_finished, true, max(u64))
        if wait_res != .SUCCESS {
            panic("failed to wait for frame fence")
        }

        reset_res := vk.ResetFences(renderer.device, 1, &renderer.fence_frame_finished)
        if reset_res != .SUCCESS {
            panic("failed to reset frame fence")
        }
    }

    swapchain_image_index: u32
    {     // get next swapchain image
        res := vk.AcquireNextImageKHR(
            renderer.device,
            renderer.swapchain,
            max(u64),
            0,
            renderer.fence_image_acquired,
            &swapchain_image_index,
        )
        if res == .ERROR_OUT_OF_DATE_KHR || res == .SUBOPTIMAL_KHR {
            // fmt.println("swapchain out of date / suboptimal on acquire next image")
        } else if res != .SUCCESS {
            panic("failed to get next swapchain image")
        }

        wait_res := vk.WaitForFences(renderer.device, 1, &renderer.fence_image_acquired, true, max(u64))
        if wait_res != .SUCCESS {
            panic("failed to wait for image acquired fence")
        }

        reset_res := vk.ResetFences(renderer.device, 1, &renderer.fence_image_acquired)
        if reset_res != .SUCCESS {
            panic("failed to reset image acquired fence")
        }
    }

    {     // begin recording commands
        begin_info := vk.CommandBufferBeginInfo {
            sType = .COMMAND_BUFFER_BEGIN_INFO,
            flags = {.ONE_TIME_SUBMIT},
        }
        res := vk.BeginCommandBuffer(renderer.command_buffer, &begin_info)
        if res != .SUCCESS {
            panic("failed to begin command buffer")
        }
    }

    clear_value := vk.ClearColorValue {
        float32 = [4]f32{1, 0, 1, 1},
    }

    color_attachment := vk.RenderingAttachmentInfo {
        sType = .RENDERING_ATTACHMENT_INFO,
        imageView = renderer.swapchain_image_views[swapchain_image_index],
        imageLayout = .COLOR_ATTACHMENT_OPTIMAL,
        resolveMode = {},
        loadOp = .CLEAR,
        storeOp = .STORE,
        clearValue = vk.ClearValue{color = clear_value},
    }

    {     // memory barrier transition to fragment shader output writable
        memory_barrier_to_write := vk.ImageMemoryBarrier {
            sType = .IMAGE_MEMORY_BARRIER,
            srcAccessMask = {},
            dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
            oldLayout = .UNDEFINED,
            newLayout = .COLOR_ATTACHMENT_OPTIMAL,
            srcQueueFamilyIndex = renderer.queue_family_index,
            dstQueueFamilyIndex = renderer.queue_family_index,
            image = renderer.swapchain_images[swapchain_image_index],
            subresourceRange = vk.ImageSubresourceRange {
                aspectMask = {.COLOR},
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
        }
        vk.CmdPipelineBarrier(
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
        memory_barrier_to_present := vk.ImageMemoryBarrier {
            sType = .IMAGE_MEMORY_BARRIER,
            srcAccessMask = {},
            dstAccessMask = {},
            oldLayout = .COLOR_ATTACHMENT_OPTIMAL,
            newLayout = .PRESENT_SRC_KHR,
            srcQueueFamilyIndex = renderer.queue_family_index,
            dstQueueFamilyIndex = renderer.queue_family_index,
            image = renderer.swapchain_images[swapchain_image_index],
            subresourceRange = vk.ImageSubresourceRange {
                aspectMask = {.COLOR},
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
        }
        vk.CmdPipelineBarrier(
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

    rendering_info := vk.RenderingInfo {
        sType = .RENDERING_INFO,
        renderArea = vk.Rect2D{offset = vk.Offset2D{0, 0}, extent = renderer.surface_extent},
        layerCount = 1,
        viewMask = 0,
        colorAttachmentCount = 1,
        pColorAttachments = &color_attachment,
    }
    vk.CmdBeginRendering(commandBuffer = renderer.command_buffer, pRenderingInfo = &rendering_info)

    vk.CmdBindPipeline(
        commandBuffer = renderer.command_buffer,
        pipelineBindPoint = .GRAPHICS,
        pipeline = renderer.graphics_pipeline,
    )

    offsets := []vk.DeviceSize{0}
    vk.CmdBindVertexBuffers(
        commandBuffer = renderer.command_buffer,
        firstBinding = 0,
        bindingCount = 1,
        pBuffers = &renderer.vertex_buffer,
        pOffsets = raw_data(offsets),
    )

    vk.CmdBindIndexBuffer(
        commandBuffer = renderer.command_buffer,
        buffer = renderer.index_buffer,
        offset = 0,
        indexType = .UINT32,
    )

    vk.CmdDrawIndexed(
        commandBuffer = renderer.command_buffer,
        indexCount = cast(u32)len(indices),
        instanceCount = 1,
        firstIndex = 0,
        vertexOffset = 0,
        firstInstance = 0,
    )

    vk.CmdEndRendering(renderer.command_buffer)

    {     // end recording command buffer
        res := vk.EndCommandBuffer(renderer.command_buffer)
        if res != .SUCCESS {
            panic("failed to end command buffer")
        }
    }

    {     // submit commands
        submit_info := vk.SubmitInfo {
            sType                = .SUBMIT_INFO,
            commandBufferCount   = 1,
            pCommandBuffers      = &renderer.command_buffer,
            signalSemaphoreCount = 1,
            pSignalSemaphores    = &renderer.semaphores_draw_finished[swapchain_image_index],
        }
        res := vk.QueueSubmit(renderer.queue, 1, &submit_info, renderer.fence_frame_finished)
        if res != .SUCCESS {
            panic("failed to submit command")
        }
    }

    {     // present images
        present_info := vk.PresentInfoKHR {
            sType              = .PRESENT_INFO_KHR,
            waitSemaphoreCount = 1,
            pWaitSemaphores    = &renderer.semaphores_draw_finished[swapchain_image_index],
            swapchainCount     = 1,
            pSwapchains        = &renderer.swapchain,
            pImageIndices      = &swapchain_image_index,
            pResults           = nil,
        }
        res := vk.QueuePresentKHR(renderer.queue, &present_info)
        if res == .ERROR_OUT_OF_DATE_KHR || res == .SUBOPTIMAL_KHR {
            // fmt.println("swapchain out of date / suboptimal on queue present")
        } else if res != .SUCCESS {
            panic("failed to present image")
        }
    }
}

create_swapchain :: proc(renderer: ^Renderer) {
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

    renderer.surface_extent = surface_capabilities.currentExtent

    create_info := vk.SwapchainCreateInfoKHR {
        sType            = .SWAPCHAIN_CREATE_INFO_KHR,
        flags            = vk.SwapchainCreateFlagsKHR{},
        surface          = gc.vk_surface,
        minImageCount    = surface_capabilities.minImageCount,
        imageFormat      = surface_image_format.format,
        imageColorSpace  = surface_image_format.colorSpace,
        imageExtent      = renderer.surface_extent,
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
    }; renderer.swapchain_image_format = surface_image_format.format
}

create_swapchain_images :: proc(renderer: ^Renderer) {
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
}

create_swapchain_image_views :: proc(renderer: ^Renderer) {
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
    }}

create_graphics_pipeline :: proc(renderer: ^Renderer) {
    vertex_shader_stage_create_info := vk.PipelineShaderStageCreateInfo {
        sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        flags  = {},
        stage  = {.VERTEX},
        module = renderer.vertex_shader_module,
        pName  = "main",
    }

    fragment_shader_stage_create_info := vk.PipelineShaderStageCreateInfo {
        sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        flags  = {},
        stage  = {.FRAGMENT},
        module = renderer.fragment_shader_module,
        pName  = "main",
    }

    pipeline_shader_stages := []vk.PipelineShaderStageCreateInfo {
        vertex_shader_stage_create_info,
        fragment_shader_stage_create_info,
    }

    vertex_input_state_create_info := vk.PipelineVertexInputStateCreateInfo {
        sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        flags                           = {},
        vertexBindingDescriptionCount   = 1,
        pVertexBindingDescriptions      = &vertex_input_binding_description,
        vertexAttributeDescriptionCount = cast(u32)len(vertex_input_attribute_descriptions),
        pVertexAttributeDescriptions    = raw_data(vertex_input_attribute_descriptions),
    }

    input_assembly_state_create_info := vk.PipelineInputAssemblyStateCreateInfo {
        sType    = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        flags    = {},
        topology = .TRIANGLE_LIST,
    }

    viewport := vk.Viewport {
        x        = 0,
        y        = 0,
        width    = cast(f32)renderer.surface_extent.width,
        height   = cast(f32)renderer.surface_extent.height,
        minDepth = 0,
        maxDepth = 1,
    }
    scissor := vk.Rect2D {
        offset = {x = 0, y = 0},
        extent = renderer.surface_extent,
    }
    viewport_state_create_info := vk.PipelineViewportStateCreateInfo {
        sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        viewportCount = 1,
        pViewports    = &viewport,
        scissorCount  = 1,
        pScissors     = &scissor,
    }

    rasterization_state_create_info := vk.PipelineRasterizationStateCreateInfo {
        sType            = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        depthClampEnable = false,
        polygonMode      = .FILL,
        cullMode         = {.BACK},
        frontFace        = .COUNTER_CLOCKWISE,
        lineWidth        = 1,
    }

    multisample_state_create_info := vk.PipelineMultisampleStateCreateInfo {
        sType                = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        sampleShadingEnable  = false,
        rasterizationSamples = vk.SampleCountFlags{._1},
    }

    pipeline_layout: vk.PipelineLayout
    pipeline_layout_create_info := vk.PipelineLayoutCreateInfo {
        sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
        flags                  = {},
        setLayoutCount         = 0,
        pSetLayouts            = nil,
        pushConstantRangeCount = 0,
        pPushConstantRanges    = nil,
    }
    pipeline_layout_create_res := vk.CreatePipelineLayout(
        renderer.device,
        &pipeline_layout_create_info,
        nil,
        &pipeline_layout,
    )
    if pipeline_layout_create_res != .SUCCESS {
        panic("failed to create pipeline layout")
    }

    pipeline_rendering_create_info := vk.PipelineRenderingCreateInfo {
        sType                   = .PIPELINE_RENDERING_CREATE_INFO,
        viewMask                = 0,
        colorAttachmentCount    = 1,
        pColorAttachmentFormats = &renderer.swapchain_image_format,
    }

    pipeline_color_blend_attachment_state := vk.PipelineColorBlendAttachmentState {
        blendEnable    = false,
        colorWriteMask = {.R, .G, .B, .A},
    }

    color_blend_state_create_info := vk.PipelineColorBlendStateCreateInfo {
        sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        flags           = {},
        logicOpEnable   = false,
        attachmentCount = 1,
        pAttachments    = &pipeline_color_blend_attachment_state,
    }
    create_info := vk.GraphicsPipelineCreateInfo {
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
    res := vk.CreateGraphicsPipelines(renderer.device, {}, 1, &create_info, nil, &renderer.graphics_pipeline)
}

handle_screen_resized :: proc(renderer: ^Renderer) {
    wait_res := vk.DeviceWaitIdle(renderer.device)
    if wait_res != .SUCCESS {
        panic("failed wait for idle")
    }

    for i in 0 ..< len(renderer.swapchain_images) {
        vk.DestroyImageView(renderer.device, renderer.swapchain_image_views[i], nil)
    }
    delete(renderer.swapchain_image_views)
    delete(renderer.swapchain_images)
    vk.DestroySwapchainKHR(renderer.device, renderer.swapchain, nil)
    vk.DestroyPipeline(renderer.device, renderer.graphics_pipeline, nil)

    create_swapchain(renderer)
    create_swapchain_images(renderer)
    create_swapchain_image_views(renderer)
    create_graphics_pipeline(renderer)

    gc.window_resized = false
}
